"""Service layer for gateway operations.

This service handles:
- Gateway registration and status tracking
- Online/offline status updates
- Last seen timestamp management
"""
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import List, Optional
from datetime import datetime, timedelta
from models.database import Gateway, SensorNode


class GatewayService:
    """Service for managing gateway operations."""

    @staticmethod
    def register_or_update_gateway(
        db: Session,
        gateway_id: str,
        name: Optional[str] = None,
        local_ip: Optional[str] = None,
        client_ip: Optional[str] = None
    ) -> Gateway:
        """Register a new gateway or update existing gateway's last_seen timestamp.
        
        Args:
            db: Database session
            gateway_id: Unique gateway identifier
            name: Optional human-readable name
            local_ip: ESP32's self-reported local IP address
            client_ip: IP address seen by backend (for diagnostics)
            
        Returns:
            Gateway object (new or existing)
        """
        gateway = db.query(Gateway).filter(Gateway.gateway_id == gateway_id).first()
        
        if gateway:
            # Update existing gateway
            gateway.last_seen = datetime.utcnow()
            gateway.is_online = True
            if name:
                gateway.name = name
            if local_ip and local_ip != "0.0.0.0":
                gateway.local_ip = local_ip
            if client_ip:
                gateway.client_ip = client_ip
        else:
            # Create new gateway
            gateway = Gateway(
                gateway_id=gateway_id,
                name=name or f"Gateway {gateway_id}",
                is_online=True,
                last_seen=datetime.utcnow(),
                local_ip=local_ip if local_ip and local_ip != "0.0.0.0" else None,
                client_ip=client_ip
            )
            db.add(gateway)
        
        db.commit()
        db.refresh(gateway)
        return gateway
    
    @staticmethod
    def get_gateway(db: Session, gateway_id: str) -> Optional[Gateway]:
        """Get gateway object by ID.
        
        Args:
            db: Database session
            gateway_id: Gateway identifier
            
        Returns:
            Gateway object or None if not found
        """
        return db.query(Gateway).filter(Gateway.gateway_id == gateway_id).first()

    @staticmethod
    def register_or_update_node(
        db: Session,
        node_id: str,
        gateway_id: str,
        name: Optional[str] = None,
        is_simulated: bool = False
    ) -> SensorNode:
        """Register a new sensor node or update existing node's last_seen timestamp.
        
        Args:
            db: Database session
            node_id: Unique node identifier
            gateway_id: Gateway that this node belongs to
            name: Optional human-readable name
            is_simulated: True if this is a simulated node (for development)
            
        Returns:
            SensorNode object (new or existing)
        """
        # Ensure gateway exists
        GatewayService.register_or_update_gateway(db, gateway_id)
        
        node = db.query(SensorNode).filter(SensorNode.node_id == node_id).first()
        
        if node:
            # Update existing node
            node.last_seen = datetime.utcnow()
            node.gateway_id = gateway_id
            if name:
                node.name = name
        else:
            # Create new node
            node = SensorNode(
                node_id=node_id,
                gateway_id=gateway_id,
                name=name or f"Node {node_id}",
                is_simulated=is_simulated,
                last_seen=datetime.utcnow()
            )
            db.add(node)
        
        db.commit()
        db.refresh(node)
        return node

    @staticmethod
    def get_gateway_status(db: Session, gateway_id: str) -> Optional[dict]:
        """Get status information for a specific gateway.
        
        Args:
            db: Database session
            gateway_id: Gateway identifier
            
        Returns:
            Dictionary with gateway status or None if not found
        """
        gateway = db.query(Gateway).filter(Gateway.gateway_id == gateway_id).first()
        
        if not gateway:
            return None
        
        # Check if gateway is considered online (seen in last 5 minutes)
        time_since_last_seen = (datetime.utcnow() - gateway.last_seen).total_seconds()
        is_online = time_since_last_seen < 300  # 5 minutes threshold
        
        # Update online status if changed
        if gateway.is_online != is_online:
            gateway.is_online = is_online
            db.commit()
        
        return {
            "gateway_id": gateway.gateway_id,
            "name": gateway.name,
            "is_online": is_online,
            "last_seen": gateway.last_seen.isoformat(),
            "last_seen_seconds_ago": int(time_since_last_seen),
            "created_at": gateway.created_at.isoformat(),
            "local_ip": gateway.local_ip,  # ESP32's self-reported IP (source of truth)
            "client_ip": gateway.client_ip  # IP seen by backend (for diagnostics)
        }

    @staticmethod
    def get_all_gateways(db: Session) -> List[Gateway]:
        """Get all registered gateways.
        
        Args:
            db: Database session
            
        Returns:
            List of Gateway objects
        """
        return db.query(Gateway).order_by(desc(Gateway.last_seen)).all()

    @staticmethod
    def mark_gateway_offline(db: Session, gateway_id: str):
        """Mark a gateway as offline.
        
        Args:
            db: Database session
            gateway_id: Gateway identifier
        """
        gateway = db.query(Gateway).filter(Gateway.gateway_id == gateway_id).first()
        if gateway:
            gateway.is_online = False
            db.commit()

    @staticmethod
    def cleanup_offline_gateways(db: Session, minutes_threshold: int = 10):
        """Mark gateways as offline if they haven't been seen recently.
        
        Args:
            db: Database session
            minutes_threshold: Minutes since last_seen to consider offline
        """
        threshold_time = datetime.utcnow() - timedelta(minutes=minutes_threshold)
        gateways = db.query(Gateway).filter(
            Gateway.is_online == True,
            Gateway.last_seen < threshold_time
        ).all()
        
        for gateway in gateways:
            gateway.is_online = False
        
        db.commit()

