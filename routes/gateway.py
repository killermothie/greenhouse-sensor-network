"""API routes for gateway endpoints."""
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session
from typing import Optional, List
from datetime import datetime
from models.database import get_db
from services.gateway_service import GatewayService
from pydantic import BaseModel
import logging

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/gateway", tags=["gateway"])

# In-memory cache for gateway status (active node count, network mode, etc.)
# Key: gateway_id, Value: dict with status info
_gateway_status_cache: dict[str, dict] = {}


@router.get("/status")
async def get_gateway_status(
    gateway_id: str = Query(..., description="Gateway identifier"),
    db: Session = Depends(get_db)
):
    """
    Get status information for a specific gateway.
    
    Returns:
    - gateway_id: Gateway identifier
    - name: Human-readable name (if set)
    - is_online: Boolean indicating if gateway is online
    - last_seen: ISO timestamp of last contact
    - last_seen_seconds_ago: Seconds since last contact
    - created_at: ISO timestamp of gateway registration
    - active_node_count: Number of active nodes (if gateway is connected and reporting)
    - network_mode: Network mode (ONLINE/OFFLINE/AP) if available
    
    **Example Response:**
    ```json
    {
        "gateway_id": "gateway-01",
        "name": "Gateway gateway-01",
        "is_online": true,
        "last_seen": "2024-01-15T10:30:00",
        "last_seen_seconds_ago": 45,
        "created_at": "2024-01-15T08:00:00",
        "active_node_count": 3,
        "network_mode": "ONLINE"
    }
    ```
    
    **Online Status Logic:**
    - Gateway is considered online if last_seen is within the last 5 minutes
    - Automatically updated when gateway sends sensor data
    - Active node count is updated when gateway sends status updates
    """
    try:
        status = GatewayService.get_gateway_status(db, gateway_id)
        
        if status is None:
            raise HTTPException(
                status_code=404,
                detail=f"Gateway '{gateway_id}' not found. Gateway will be registered on first sensor data receipt."
            )
        
        # Add cached status info if available
        if gateway_id in _gateway_status_cache:
            cached = _gateway_status_cache[gateway_id]
            status["active_node_count"] = cached.get("active_node_count", 0)
            status["network_mode"] = cached.get("network_mode", "UNKNOWN")
        
        return status
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error fetching gateway status: {str(e)}"
        )


@router.post("/status")
async def update_gateway_status(
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Receive gateway status update from ESP32 gateway.
    
    This endpoint is called by the gateway when it's connected to the backend
    to report its status including active node count, network mode, etc.
    
    **Request Body:**
    ```json
    {
        "gatewayId": "gateway-01",
        "activeNodeCount": 3,
        "networkMode": "ONLINE",
        "backendReachable": true,
        "timestamp": 1234567890
    }
    ```
    """
    try:
        data = await request.json()
        gateway_id = data.get("gatewayId") or data.get("gateway_id")
        
        if not gateway_id:
            raise HTTPException(status_code=400, detail="gatewayId is required")
        
        # Get ESP32's self-reported local IP
        local_ip = data.get("localIp") or data.get("local_ip")
        client_ip = request.client.host if request.client else None
        
        # Update gateway with IP addresses
        GatewayService.register_or_update_gateway(
            db, 
            gateway_id,
            local_ip=local_ip,
            client_ip=client_ip
        )
        
        # Update cache with local IP if provided
        if local_ip and local_ip != "0.0.0.0":
            _esp32_ip_cache[gateway_id] = local_ip
            logger.info(f"Gateway {gateway_id} local IP updated: {local_ip}")
        
        # Cache the gateway status
        _gateway_status_cache[gateway_id] = {
            "active_node_count": data.get("activeNodeCount", 0),
            "network_mode": data.get("networkMode", "UNKNOWN"),
            "backend_reachable": data.get("backendReachable", False),
            "last_updated": datetime.utcnow().isoformat()
        }
        
        logger.info(
            f"Gateway status updated: {gateway_id}, "
            f"active_nodes={data.get('activeNodeCount', 0)}, "
            f"mode={data.get('networkMode', 'UNKNOWN')}, "
            f"local_ip={local_ip or 'not provided'}"
        )
        
        return {
            "status": "success",
            "gateway_id": gateway_id,
            "message": "Gateway status updated"
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating gateway status: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Error updating gateway status: {str(e)}"
        )


@router.get("/list")
async def list_gateways(db: Session = Depends(get_db)):
    """
    List all registered gateways.
    
    Returns a list of all gateways with their status information.
    Useful for monitoring multiple gateways in a network.
    """
    try:
        gateways = GatewayService.get_all_gateways(db)
        
        result = []
        for gateway in gateways:
            status = GatewayService.get_gateway_status(db, gateway.gateway_id)
            if status:
                # Add cached status info if available
                if gateway.gateway_id in _gateway_status_cache:
                    cached = _gateway_status_cache[gateway.gateway_id]
                    status["active_node_count"] = cached.get("active_node_count", 0)
                    status["network_mode"] = cached.get("network_mode", "UNKNOWN")
                result.append(status)
        
        return {
            "gateways": result,
            "count": len(result)
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error listing gateways: {str(e)}"
        )

