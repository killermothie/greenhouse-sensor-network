"""Database models and setup for SQLite.

This module defines the database schema for the greenhouse monitoring system:
- Gateways: ESP32 gateway devices that collect and forward sensor data
- SensorNodes: Individual sensor nodes (can be real or simulated)
- SensorReadings: Time-series sensor data from nodes

The system is designed to work with both real and simulated data interchangeably.
"""
from sqlalchemy import create_engine, Column, Integer, Float, DateTime, String, ForeignKey, Boolean, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from datetime import datetime
import os

# Database URL - can be overridden by environment variable
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./greenhouse.db")

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False} if "sqlite" in DATABASE_URL else {}
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class Gateway(Base):
    """Gateway model for ESP32 gateway devices.
    
    Gateways are the collection points that receive data from sensor nodes
    and forward it to the backend. They can operate in STA (connected to Wi-Fi)
    or AP (access point) mode.
    """
    __tablename__ = "gateways"

    id = Column(Integer, primary_key=True, index=True)
    gateway_id = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=True)  # Optional human-readable name
    is_online = Column(Boolean, default=False, nullable=False)
    last_seen = Column(DateTime, default=datetime.utcnow, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    # Relationships
    sensor_nodes = relationship("SensorNode", back_populates="gateway", cascade="all, delete-orphan")
    readings = relationship("SensorReading", back_populates="gateway")

    def __repr__(self):
        return f"<Gateway(id={self.id}, gateway_id={self.gateway_id}, online={self.is_online})>"


class SensorNode(Base):
    """Sensor node model for individual sensor devices.
    
    Sensor nodes can be:
    - Real physical devices (ESP-NOW, LoRa, etc.)
    - Simulated nodes (for development/testing)
    
    Each node belongs to a gateway and sends sensor readings.
    """
    __tablename__ = "sensor_nodes"

    id = Column(Integer, primary_key=True, index=True)
    node_id = Column(String, unique=True, index=True, nullable=False)
    gateway_id = Column(String, ForeignKey("gateways.gateway_id"), nullable=False, index=True)
    name = Column(String, nullable=True)  # Optional human-readable name
    is_simulated = Column(Boolean, default=False, nullable=False)  # True for simulated nodes
    last_seen = Column(DateTime, default=datetime.utcnow, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    # Relationships
    gateway = relationship("Gateway", back_populates="sensor_nodes")
    readings = relationship("SensorReading", back_populates="sensor_node")

    def __repr__(self):
        return f"<SensorNode(id={self.id}, node_id={self.node_id}, gateway_id={self.gateway_id})>"


class SensorReading(Base):
    """Sensor reading model for storing time-series sensor data.
    
    Each reading is associated with:
    - A gateway (that collected/forwarded the data)
    - A sensor node (that generated the data)
    
    This allows tracking data flow: Node -> Gateway -> Backend
    """
    __tablename__ = "sensor_readings"

    id = Column(Integer, primary_key=True, index=True)
    
    # Foreign keys - use node_id and gateway_id strings for flexibility
    # (allows data from nodes/gateways not yet registered)
    node_id = Column(String, ForeignKey("sensor_nodes.node_id"), nullable=False, index=True)
    gateway_id = Column(String, ForeignKey("gateways.gateway_id"), nullable=False, index=True)
    
    # Sensor data
    temperature = Column(Float, nullable=False)
    humidity = Column(Float, nullable=False)
    soil_moisture = Column(Float, nullable=False)
    light_level = Column(Float, nullable=True)
    battery_level = Column(Integer, nullable=True)
    rssi = Column(Integer, nullable=True)  # Signal strength
    
    # Timestamp
    timestamp = Column(DateTime, default=datetime.utcnow, index=True, nullable=False)
    
    # Relationships
    gateway = relationship("Gateway", back_populates="readings")
    sensor_node = relationship("SensorNode", back_populates="readings")

    def __repr__(self):
        return f"<SensorReading(id={self.id}, node_id={self.node_id}, temp={self.temperature})>"


def init_db():
    """Initialize the database by creating all tables and migrating if needed.
    
    This function:
    1. Creates all tables if they don't exist
    2. Migrates existing sensor_readings table to add gateway_id and node_id
    3. Handles backward compatibility with existing data
    """
    Base.metadata.create_all(bind=engine)
    
    # Migration logic for existing databases
    with engine.connect() as conn:
        # Check if sensor_readings table exists (old schema)
        result = conn.execute(
            text("SELECT name FROM sqlite_master WHERE type='table' AND name='sensor_readings'")
        )
        if result.fetchone():
            # Table exists, check for new columns
            try:
                # Check if gateway_id column exists
                conn.execute(text("SELECT gateway_id FROM sensor_readings LIMIT 1"))
                conn.commit()
            except Exception:
                # Add gateway_id column (migrate existing data)
                try:
                    conn.execute(text("ALTER TABLE sensor_readings ADD COLUMN gateway_id VARCHAR"))
                    conn.commit()
                    # Set default gateway_id for existing records
                    # Use 'gateway-01' as default (most common from firmware)
                    conn.execute(
                        text("UPDATE sensor_readings SET gateway_id = 'gateway-01' WHERE gateway_id IS NULL")
                    )
                    conn.commit()
                except Exception:
                    pass  # Column might already exist
            
            try:
                # Check if node_id column exists (might be named sensor_id in old schema)
                conn.execute(text("SELECT node_id FROM sensor_readings LIMIT 1"))
                conn.commit()
            except Exception:
                # Check if sensor_id exists (old column name)
                try:
                    conn.execute(text("SELECT sensor_id FROM sensor_readings LIMIT 1"))
                    conn.commit()
                    # Rename sensor_id to node_id
                    conn.execute(text("ALTER TABLE sensor_readings RENAME COLUMN sensor_id TO node_id"))
                    conn.commit()
                except Exception:
                    # sensor_id doesn't exist, add node_id
                    try:
                        conn.execute(text("ALTER TABLE sensor_readings ADD COLUMN node_id VARCHAR"))
                        conn.commit()
                    except Exception:
                        pass
            
            # Ensure other columns exist
            for col_name, col_type in [
                ("battery_level", "INTEGER"),
                ("rssi", "INTEGER"),
            ]:
                try:
                    conn.execute(text(f"SELECT {col_name} FROM sensor_readings LIMIT 1"))
                    conn.commit()
                except Exception:
                    try:
                        conn.execute(text(f"ALTER TABLE sensor_readings ADD COLUMN {col_name} {col_type}"))
                        conn.commit()
                    except Exception:
                        pass


def get_db():
    """Dependency for getting database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
