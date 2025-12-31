"""System statistics tracking for status endpoint."""
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func
from models.database import SensorReading
import httpx
import logging

logger = logging.getLogger(__name__)

# System startup time for uptime calculation
_system_start_time = datetime.utcnow()
_total_messages = 0

# Note: Gateway IP cache is managed in routes/sensors.py
# We'll pass gateway_ip as parameter instead


def increment_message_count():
    """Increment the total message counter."""
    global _total_messages
    _total_messages += 1


async def fetch_gateway_active_nodes(gateway_ip: str = None) -> int | None:
    """Fetch active node count from gateway if available."""
    # IPs to try: provided IP, common AP IP
    ips_to_try = []
    
    if gateway_ip:
        ips_to_try.append(gateway_ip)
    
    # Try common AP IP as fallback
    if '192.168.4.1' not in ips_to_try:
        ips_to_try.append('192.168.4.1')
    
    # Use shorter timeout to avoid blocking the API response
    async with httpx.AsyncClient(timeout=httpx.Timeout(0.5)) as client:
        for ip in ips_to_try:
            try:
                url = f"http://{ip}/nodes"
                response = await client.get(url)
                
                if response.status_code == 200:
                    data = response.json()
                    if "active_nodes" in data:
                        logger.info(f"Fetched active nodes from gateway {ip}: {data['active_nodes']}")
                        return data["active_nodes"]
            except (httpx.TimeoutException, httpx.ConnectError, httpx.RequestError):
                continue
            except Exception as e:
                logger.debug(f"Error fetching from gateway {ip}: {str(e)}")
                continue
    
    return None


def get_system_stats(db: Session, gateway_ip: str = None) -> dict:
    """Get system statistics for status endpoint."""
    global _total_messages
    
    # Calculate uptime
    uptime_seconds = int((datetime.utcnow() - _system_start_time).total_seconds())
    
    # Get last data received time
    last_reading = (
        db.query(SensorReading)
        .order_by(SensorReading.timestamp.desc())
        .first()
    )
    
    last_data_received_seconds = None
    if last_reading:
        last_data_received_seconds = int(
            (datetime.utcnow() - last_reading.timestamp).total_seconds()
        )
    
    # Get total messages from database (more accurate than counter)
    total_messages = db.query(func.count(SensorReading.id)).scalar() or 0
    
    # Try to get active nodes from gateway first, fallback to database
    # Note: This is a sync function, so we'll calculate from DB for now
    # The gateway active nodes will be fetched in the async endpoint
    one_hour_ago = datetime.utcnow() - timedelta(hours=1)
    active_nodes = (
        db.query(func.count(func.distinct(SensorReading.node_id)))
        .filter(SensorReading.timestamp >= one_hour_ago)
        .scalar() or 0
    )
    
    return {
        "backend": "online",
        "last_data_received_seconds": last_data_received_seconds,
        "total_messages": total_messages,
        "nodes_active": active_nodes,
        "system_uptime_seconds": uptime_seconds
    }

