"""Service layer for sensor data operations."""
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import List, Optional
from datetime import datetime, timedelta
from models.database import SensorReading
from models.schemas import SensorDataInput, SensorReadingResponse
from services.gateway_service import GatewayService


class SensorService:
    """Service for managing sensor data operations."""

    @staticmethod
    def create_reading(db: Session, sensor_data: SensorDataInput) -> SensorReading:
        """Create a new sensor reading in the database.
        
        This method:
        1. Registers/updates the gateway (if not exists)
        2. Registers/updates the sensor node (if not exists)
        3. Creates the sensor reading with proper foreign key relationships
        
        Works with both real and simulated data.
        """
        # Get gateway and node IDs
        gateway_id = sensor_data.get_gateway_id()
        node_id = sensor_data.get_sensor_id()
        
        # Register/update gateway and node (creates if doesn't exist)
        # This allows the system to work with data from unknown gateways/nodes
        GatewayService.register_or_update_gateway(db, gateway_id)
        
        # Determine if node is simulated (for now, assume simulated if gateway is 'gateway-01'
        # and node_id matches common simulation patterns)
        is_simulated = gateway_id == "gateway-01" and ("sim" in node_id.lower() or "test" in node_id.lower())
        GatewayService.register_or_update_node(db, node_id, gateway_id, is_simulated=is_simulated)
        
        # Use timestamp from ESP32 if provided, otherwise use current time
        reading_timestamp = datetime.utcnow()
        if sensor_data.timestamp:
            try:
                reading_timestamp = datetime.fromtimestamp(sensor_data.timestamp)
            except (ValueError, OSError):
                reading_timestamp = datetime.utcnow()
        
        db_reading = SensorReading(
            node_id=node_id,
            gateway_id=gateway_id,
            temperature=sensor_data.temperature,
            humidity=sensor_data.humidity,
            soil_moisture=sensor_data.get_soil_moisture(),
            light_level=sensor_data.light_level,
            battery_level=sensor_data.batteryLevel,
            rssi=sensor_data.rssi,
            timestamp=reading_timestamp
        )
        db.add(db_reading)
        db.commit()
        db.refresh(db_reading)
        return db_reading

    @staticmethod
    def get_latest_readings(
        db: Session,
        limit: int = 10,
        node_id: Optional[str] = None,
        gateway_id: Optional[str] = None
    ) -> List[SensorReading]:
        """Get the latest sensor readings.
        
        Args:
            db: Database session
            limit: Maximum number of readings to return
            node_id: Optional filter by node ID
            gateway_id: Optional filter by gateway ID
            
        Returns:
            List of SensorReading objects
        """
        query = db.query(SensorReading)

        if node_id:
            query = query.filter(SensorReading.node_id == node_id)
        if gateway_id:
            query = query.filter(SensorReading.gateway_id == gateway_id)

        return query.order_by(desc(SensorReading.timestamp)).limit(limit).all()

    @staticmethod
    def get_all_node_ids(db: Session) -> List[str]:
        """Get all unique node IDs."""
        node_ids = db.query(SensorReading.node_id).distinct().all()
        return [node_id[0] for node_id in node_ids]

    @staticmethod
    def get_latest_per_node(db: Session) -> List[SensorReading]:
        """Get the latest reading for each sensor node."""
        node_ids = SensorService.get_all_node_ids(db)
        latest_readings = []

        for node_id in node_ids:
            latest = (
                db.query(SensorReading)
                .filter(SensorReading.node_id == node_id)
                .order_by(desc(SensorReading.timestamp))
                .first()
            )
            if latest:
                latest_readings.append(latest)

        return latest_readings

    @staticmethod
    def get_history(
        db: Session,
        hours: int = 24,
        node_id: Optional[str] = None,
        gateway_id: Optional[str] = None
    ) -> List[SensorReading]:
        """Get sensor readings from the last N hours.
        
        Args:
            db: Database session
            hours: Number of hours of history to retrieve
            node_id: Optional filter by node ID
            gateway_id: Optional filter by gateway ID
            
        Returns:
            List of SensorReading objects ordered by timestamp
        """
        cutoff_time = datetime.utcnow() - timedelta(hours=hours)
        query = db.query(SensorReading).filter(
            SensorReading.timestamp >= cutoff_time
        )

        if node_id:
            query = query.filter(SensorReading.node_id == node_id)
        if gateway_id:
            query = query.filter(SensorReading.gateway_id == gateway_id)

        return query.order_by(SensorReading.timestamp).all()
    
    @staticmethod
    def check_duplicate(
        db: Session,
        node_id: str,
        gateway_id: str,
        timestamp: datetime,
        window_seconds: int = 5
    ) -> Optional[SensorReading]:
        """Check if a reading with similar timestamp already exists.
        
        Args:
            db: Database session
            node_id: Node ID to check
            gateway_id: Gateway ID to check
            timestamp: Timestamp to check
            window_seconds: Time window in seconds to consider as duplicate
            
        Returns:
            Existing SensorReading if duplicate found, None otherwise
        """
        window_start = timestamp - timedelta(seconds=window_seconds)
        window_end = timestamp + timedelta(seconds=window_seconds)
        
        existing = (
            db.query(SensorReading)
            .filter(SensorReading.node_id == node_id)
            .filter(SensorReading.gateway_id == gateway_id)
            .filter(SensorReading.timestamp >= window_start)
            .filter(SensorReading.timestamp <= window_end)
            .first()
        )
        
        return existing

