"""API routes for sensor data endpoints."""
import logging
import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from typing import Optional
from datetime import datetime, timedelta
from slowapi import Limiter
from slowapi.util import get_remote_address
from models.database import get_db
from models.schemas import (
    SensorDataInput,
    SensorReadingResponse,
    LatestReadingsResponse,
    LatestReadingResponse,
    SystemStatusResponse,
    HistoryResponse
)
from services.sensor_service import SensorService
from services.system_stats import get_system_stats, increment_message_count, fetch_gateway_active_nodes

logger = logging.getLogger(__name__)
# Router with both v1 and legacy support
router = APIRouter(prefix="/api/sensors", tags=["sensors"])
# Note: V1 API uses /api/v1/sensors (can be added separately if needed)
limiter = Limiter(key_func=get_remote_address)

# Simple in-memory cache to store ESP32 IP addresses by gateway_id
# This is updated when ESP32 sends sensor data
_esp32_ip_cache: dict[str, str] = {}


@router.post("/data", response_model=SensorReadingResponse, status_code=201)
@limiter.limit("100/minute")  # Rate limit: 100 requests per minute per IP
async def receive_sensor_data(
    request: Request,
    sensor_data: SensorDataInput,
    db: Session = Depends(get_db)
):
    """
    Receive sensor data from ESP32 gateway.
    
    This endpoint accepts sensor readings from ESP32 devices and stores them in the database.
    Handles duplicate and late data gracefully.
    
    **Example Request:**
    ```json
    {
        "sensor_id": "ESP32_001",
        "temperature": 25.5,
        "humidity": 65.0,
        "soil_moisture": 45.0,
        "light_level": 850.0
    }
    ```
    
    **Example Response:**
    ```json
    {
        "id": 1,
        "sensor_id": "ESP32_001",
        "temperature": 25.5,
        "humidity": 65.0,
        "soil_moisture": 45.0,
        "light_level": 850.0,
        "timestamp": "2024-01-15T10:30:00"
    }
    ```
    """
    gateway_id = sensor_data.get_gateway_id()
    node_id = sensor_data.get_sensor_id()
    
    # Store the ESP32's IP address from the request for later use
    client_ip = request.client.host if request.client else None
    if client_ip:
        _esp32_ip_cache[gateway_id] = client_ip
        logger.debug(f"Cached ESP32 IP for gateway {gateway_id}: {client_ip}")
    
    try:
        # Strict validation of sensor payload
        if sensor_data.temperature < -50 or sensor_data.temperature > 100:
            logger.warning(
                f"Invalid temperature: {sensor_data.temperature}",
                extra={"gateway_id": gateway_id, "node_id": node_id}
            )
            raise HTTPException(
                status_code=400,
                detail=f"Temperature out of valid range (-50 to 100°C): {sensor_data.temperature}"
            )
        
        if sensor_data.humidity < 0 or sensor_data.humidity > 100:
            logger.warning(
                f"Invalid humidity: {sensor_data.humidity}",
                extra={"gateway_id": gateway_id, "node_id": node_id}
            )
            raise HTTPException(
                status_code=400,
                detail=f"Humidity out of valid range (0-100%): {sensor_data.humidity}"
            )
        
        # Check for duplicate/late data
        reading_timestamp = datetime.utcnow()
        if sensor_data.timestamp:
            try:
                reading_timestamp = datetime.fromtimestamp(sensor_data.timestamp)
                # Check if data is too old (more than 24 hours)
                age = datetime.utcnow() - reading_timestamp
                if age > timedelta(hours=24):
                    logger.warning(
                        f"Late data received: {age.total_seconds() / 3600:.1f} hours old",
                        extra={"gateway_id": gateway_id, "node_id": node_id}
                    )
                    # Still accept it but log warning
                elif age < timedelta(seconds=-60):
                    logger.warning(
                        f"Future timestamp detected: {abs(age.total_seconds())} seconds in future",
                        extra={"gateway_id": gateway_id, "node_id": node_id}
                    )
                    # Use current time instead
                    reading_timestamp = datetime.utcnow()
            except (ValueError, OSError) as e:
                logger.warning(
                    f"Invalid timestamp: {sensor_data.timestamp}, using current time",
                    extra={"gateway_id": gateway_id, "node_id": node_id}
                )
                reading_timestamp = datetime.utcnow()
        
        # Check for duplicate (same node_id, similar timestamp within 5 seconds)
        recent_reading = SensorService.check_duplicate(
            db, node_id, gateway_id, reading_timestamp, window_seconds=5
        )
        if recent_reading:
            logger.info(
                f"Duplicate data detected (within 5s window), returning existing reading",
                extra={"gateway_id": gateway_id, "node_id": node_id}
            )
            return SensorReadingResponse.model_validate(recent_reading)
        
        # Create new reading
        reading = SensorService.create_reading(db, sensor_data)
        increment_message_count()
        
        logger.info(
            f"Sensor data received: node_id={node_id}, temp={sensor_data.temperature:.1f}°C, "
            f"humidity={sensor_data.humidity:.1f}%, timestamp={reading_timestamp.isoformat()}",
            extra={"gateway_id": gateway_id, "node_id": node_id}
        )
        
        return reading
    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            f"Error storing sensor data: {str(e)}",
            extra={"gateway_id": gateway_id, "node_id": node_id},
            exc_info=True
        )
        raise HTTPException(status_code=500, detail=f"Error storing sensor data: {str(e)}")


@router.head("/data")
async def check_connectivity():
    """
    Health check endpoint for ESP32 connectivity testing.
    Returns 200 OK if the endpoint is reachable.
    HEAD requests don't return a body, just status code.
    """
    from fastapi import Response
    return Response(status_code=200)


@router.get("/latest", response_model=LatestReadingResponse)
async def get_latest_reading(db: Session = Depends(get_db)):
    """
    Get the most recent sensor reading only.
    
    Returns the single most recent sensor reading with all fields including
    node_id, temperature, humidity, soil_moisture, battery_level, rssi,
    timestamp, and age_seconds.
    
    **Example Response:**
    ```json
    {
        "node_id": "gateway-01",
        "temperature": 25.5,
        "humidity": 65.0,
        "soil_moisture": 45.0,
        "battery_level": 85,
        "rssi": -65,
        "timestamp": "2024-01-15T10:30:00",
        "age_seconds": 120
    }
    ```
    
    **Errors:**
    - 404: No sensor data exists yet
    """
    try:
        # Get the most recent reading
        latest = SensorService.get_latest_readings(db, limit=1)
        
        if not latest or len(latest) == 0:
            raise HTTPException(
                status_code=404,
                detail="No sensor data exists yet. Please submit sensor data first."
            )
        
        reading = latest[0]
        current_time = datetime.utcnow()
        age_seconds = int((current_time - reading.timestamp).total_seconds())
        
        return LatestReadingResponse(
            node_id=reading.node_id,
            temperature=reading.temperature,
            humidity=reading.humidity,
            soil_moisture=reading.soil_moisture,
            battery_level=reading.battery_level,
            rssi=reading.rssi,
            timestamp=reading.timestamp,
            age_seconds=age_seconds
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching latest reading: {str(e)}")


@router.get("/status", response_model=SystemStatusResponse)
async def get_system_status(db: Session = Depends(get_db)):
    """
    Get system health and status information.
    
    Returns backend status, last data received time, total messages,
    active nodes count (synced with gateway if available), and system uptime.
    
    **Example Response:**
    ```json
    {
        "backend": "online",
        "last_data_received_seconds": 5,
        "total_messages": 150,
        "nodes_active": 3,
        "system_uptime_seconds": 3600
    }
    ```
    """
    try:
        stats = get_system_stats(db)
        
        # Try to fetch active nodes from gateway (sync with gateway)
        gateway_ip = None
        gateway_id = None
        
        # Try to get gateway IP from cache
        if _esp32_ip_cache:
            gateway_id = list(_esp32_ip_cache.keys())[0]
            gateway_ip = _esp32_ip_cache[gateway_id]
        
        # Fetch active nodes from gateway if available
        gateway_active_nodes = await fetch_gateway_active_nodes(gateway_ip)
        if gateway_active_nodes is not None:
            stats["nodes_active"] = gateway_active_nodes
            logger.info(f"Using gateway active nodes count: {gateway_active_nodes}")
        
        return SystemStatusResponse(**stats)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching system status: {str(e)}")


@router.get("/history", response_model=HistoryResponse)
async def get_sensor_history(
    hours: int = Query(24, ge=1, le=168, description="Number of hours of history (1-168)"),
    node_id: Optional[str] = Query(None, description="Filter by node ID"),
    gateway_id: Optional[str] = Query(None, description="Filter by gateway ID"),
    db: Session = Depends(get_db)
):
    """
    Get historical sensor readings for the last N hours.
    
    Returns sensor readings from the specified time period, useful for
    generating charts and trend analysis.
    
    **Query Parameters:**
    - `hours`: Number of hours of history (default: 24, max: 168)
    - `node_id`: Optional filter by specific node ID
    - `gateway_id`: Optional filter by specific gateway ID
    
    **Example Response:**
    ```json
    {
        "readings": [
            {
                "id": 1,
                "sensor_id": "gateway-01",
                "temperature": 25.5,
                "humidity": 65.0,
                "soil_moisture": 45.0,
                "battery_level": 85,
                "rssi": -65,
                "timestamp": "2024-01-15T10:30:00"
            }
        ],
        "count": 100,
        "hours": 24
    }
    ```
    """
    try:
        readings = SensorService.get_history(db, hours=hours, node_id=node_id, gateway_id=gateway_id)
        return HistoryResponse(
            readings=[SensorReadingResponse.model_validate(r) for r in readings],
            count=len(readings),
            hours=hours
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error fetching history: {str(e)}")


@router.get("/network")
async def get_gateway_network_status(
    gateway_ip: Optional[str] = Query(None, description="Optional ESP32 gateway IP address to query"),
    gateway_id: Optional[str] = Query(None, description="Optional gateway ID to lookup cached IP")
):
    """
    Proxy endpoint to fetch ESP32 gateway network status.
    
    This endpoint allows the mobile app to query the ESP32's network status
    through the backend, avoiding emulator network limitations.
    
    The backend will try to discover the ESP32 by attempting:
    - Cached IP from recent sensor data (if gateway_id is provided)
    - Provided IP (if gateway_ip is provided)
    - Common AP mode IP: 192.168.4.1
    
    **Query Parameters:**
    - `gateway_ip`: Optional ESP32 IP address. If not provided, will try cached/common IPs.
    - `gateway_id`: Optional gateway ID to lookup cached IP from recent sensor data.
    
    **Example Response (STA mode):**
    ```json
    {
        "mode": "STA",
        "ip": "192.168.8.253",
        "ssid": "OKC",
        "gateway": "192.168.8.1"
    }
    ```
    
    **Example Response (AP mode):**
    ```json
    {
        "mode": "AP",
        "ip": "192.168.4.1",
        "ssid": "Greenhouse-Gateway",
        "clients": 1
    }
    ```
    """
    # IPs to try: cached IP, provided IP, common AP IP
    ips_to_try = []
    
    # Try cached IP first (most reliable)
    if gateway_id and gateway_id in _esp32_ip_cache:
        cached_ip = _esp32_ip_cache[gateway_id]
        ips_to_try.append(cached_ip)
        logger.info(f"Using cached IP for gateway {gateway_id}: {cached_ip}")
    
    # Try provided IP
    if gateway_ip:
        if gateway_ip not in ips_to_try:  # Avoid duplicates
            ips_to_try.append(gateway_ip)
    
    # Try common AP IP
    if '192.168.4.1' not in ips_to_try:
        ips_to_try.append('192.168.4.1')
    
    async with httpx.AsyncClient(timeout=httpx.Timeout(2.0)) as client:
        for ip in ips_to_try:
            try:
                url = f"http://{ip}/api/system/network"
                logger.info(f"Attempting to fetch network status from {url}")
                response = await client.get(url)
                
                if response.status_code == 200:
                    logger.info(f"Successfully fetched network status from {ip}")
                    return response.json()
            except (httpx.TimeoutException, httpx.ConnectError, httpx.RequestError) as e:
                logger.debug(f"Failed to connect to {ip}: {str(e)}")
                continue
            except Exception as e:
                logger.warning(f"Unexpected error querying {ip}: {str(e)}")
                continue
    
    # If we get here, couldn't reach ESP32 - return a response indicating unreachable
    # Instead of raising 503, return a valid JSON response that the app can handle
    logger.warning("ESP32 gateway not reachable from any attempted IP addresses")
    return {
        "mode": "OFFLINE",
        "ip": "0.0.0.0",
        "ssid": "Not connected",
        "gateway": None,
        "clients": None
    }

