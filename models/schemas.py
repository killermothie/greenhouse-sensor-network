"""Pydantic models for request/response validation."""
from pydantic import BaseModel, Field, model_validator
from datetime import datetime
from typing import Optional, List


class SensorDataInput(BaseModel):
    """Input model for POST /api/sensors/data endpoint.
    
    Accepts both formats:
    - ESP32 format: nodeId, soilMoisture, batteryLevel, rssi, timestamp, gatewayId
    - Standard format: sensor_id, soil_moisture, light_level, gateway_id
    
    The system automatically registers gateways and nodes if they don't exist.
    """
    # Accept both nodeId (from ESP32) and sensor_id (standard)
    nodeId: Optional[str] = Field(None, description="ESP32 node identifier")
    sensor_id: Optional[str] = Field(None, description="Sensor identifier")
    
    # Gateway identifier (optional, defaults to 'gateway-01' for backward compatibility)
    gatewayId: Optional[str] = Field(None, description="Gateway identifier (ESP32 format)")
    gateway_id: Optional[str] = Field(None, description="Gateway identifier (standard format)")
    
    temperature: float = Field(..., ge=-50, le=100, description="Temperature in Celsius")
    humidity: float = Field(..., ge=0, le=100, description="Humidity percentage")
    
    # Accept both soilMoisture (from ESP32) and soil_moisture (standard)
    soilMoisture: Optional[float] = Field(None, ge=0, le=100, description="Soil moisture (ESP32 format)")
    soil_moisture: Optional[float] = Field(None, ge=0, le=100, description="Soil moisture percentage")
    
    # Optional fields from ESP32
    batteryLevel: Optional[int] = Field(None, description="Battery level percentage")
    rssi: Optional[int] = Field(None, description="RSSI signal strength")
    timestamp: Optional[int] = Field(None, description="Unix timestamp from ESP32")
    
    # Optional standard field
    light_level: Optional[float] = Field(None, ge=0, description="Light level (lux)")

    def get_sensor_id(self) -> str:
        """Get sensor ID from either nodeId or sensor_id."""
        return self.nodeId or self.sensor_id or "unknown"
    
    def get_gateway_id(self) -> str:
        """Get gateway ID from either gatewayId or gateway_id, default to 'gateway-01'."""
        return self.gatewayId or self.gateway_id or "gateway-01"
    
    def get_soil_moisture(self) -> float:
        """Get soil moisture from either soilMoisture or soil_moisture."""
        if self.soilMoisture is not None:
            return self.soilMoisture
        if self.soil_moisture is not None:
            return self.soil_moisture
        raise ValueError("soil_moisture or soilMoisture must be provided")
    
    @model_validator(mode='after')
    def validate_required_fields(self):
        """Ensure at least one sensor ID and soil moisture value is provided."""
        if not self.nodeId and not self.sensor_id:
            raise ValueError("Either 'nodeId' or 'sensor_id' must be provided")
        if self.soilMoisture is None and self.soil_moisture is None:
            raise ValueError("Either 'soilMoisture' or 'soil_moisture' must be provided")
        return self

    class Config:
        json_schema_extra = {
            "example": {
                "sensor_id": "ESP32_001",
                "temperature": 25.5,
                "humidity": 65.0,
                "soil_moisture": 45.0,
                "light_level": 850.0
            }
        }


class SensorReadingResponse(BaseModel):
    """Response model for sensor reading data."""
    id: int
    node_id: str = Field(..., description="Sensor node identifier")
    gateway_id: str = Field(..., description="Gateway identifier")
    temperature: float
    humidity: float
    soil_moisture: float
    light_level: Optional[float]
    battery_level: Optional[int] = None
    rssi: Optional[int] = None
    timestamp: datetime

    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "node_id": "node-01",
                "gateway_id": "gateway-01",
                "temperature": 25.5,
                "humidity": 65.0,
                "soil_moisture": 45.0,
                "light_level": 850.0,
                "battery_level": 85,
                "rssi": -65,
                "timestamp": "2024-01-15T10:30:00"
            }
        }


class LatestReadingsResponse(BaseModel):
    """Response model for GET /api/sensors/latest endpoint."""
    readings: List[SensorReadingResponse]
    count: int

    class Config:
        json_schema_extra = {
            "example": {
                "readings": [
                    {
                        "id": 1,
                        "sensor_id": "ESP32_001",
                        "temperature": 25.5,
                        "humidity": 65.0,
                        "soil_moisture": 45.0,
                        "light_level": 850.0,
                        "timestamp": "2024-01-15T10:30:00"
                    }
                ],
                "count": 1
            }
        }


class InsightItem(BaseModel):
    """Individual insight item."""
    type: str = Field(..., description="Type of insight: 'warning', 'info', 'success'")
    message: str = Field(..., description="Human-readable insight message")
    severity: str = Field(..., description="Severity level: 'low', 'medium', 'high'")
    recommendation: str = Field(..., description="Recommended action")

    class Config:
        json_schema_extra = {
            "example": {
                "type": "warning",
                "message": "Temperature is above optimal range (30.5°C)",
                "severity": "medium",
                "recommendation": "Consider increasing ventilation or reducing heating"
            }
        }


class LatestReadingResponse(BaseModel):
    """Response model for GET /api/sensors/latest - single most recent reading."""
    node_id: str = Field(..., description="Node/sensor identifier")
    temperature: float
    humidity: float
    soil_moisture: float
    battery_level: Optional[int] = None
    rssi: Optional[int] = None
    timestamp: datetime
    age_seconds: int = Field(..., description="Age of reading in seconds from current time")

    class Config:
        from_attributes = False
        json_schema_extra = {
            "example": {
                "node_id": "gateway-01",
                "temperature": 25.5,
                "humidity": 65.0,
                "soil_moisture": 45.0,
                "battery_level": 85,
                "rssi": -65,
                "timestamp": "2024-01-15T10:30:00",
                "age_seconds": 120
            }
        }


class SystemStatusResponse(BaseModel):
    """Response model for GET /api/sensors/status endpoint."""
    backend: str = Field(..., description="Backend status")
    last_data_received_seconds: Optional[int] = Field(None, description="Seconds since last data received")
    total_messages: int = Field(..., description="Total number of sensor messages received")
    nodes_active: int = Field(..., description="Number of unique active nodes")
    system_uptime_seconds: int = Field(..., description="System uptime in seconds")

    class Config:
        json_schema_extra = {
            "example": {
                "backend": "online",
                "last_data_received_seconds": 5,
                "total_messages": 150,
                "nodes_active": 3,
                "system_uptime_seconds": 3600
            }
        }


class AIInsightsResponse(BaseModel):
    """Response model for GET /api/ai/insights endpoint."""
    status: str = Field(..., description="Overall status: normal, warning, or critical")
    summary: str = Field(..., description="Human-readable summary of analysis")
    recommendations: List[str] = Field(..., description="List of actionable recommendations")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Confidence score (0.0-1.0)")

    class Config:
        json_schema_extra = {
            "example": {
                "status": "warning",
                "summary": "Detected 2 issue(s): High temperature detected: 36.5°C (threshold: 35.0°C); Low soil moisture detected: 25.0% (threshold: 30.0%)",
                "recommendations": [
                    "Increase ventilation immediately",
                    "Activate cooling systems if available",
                    "Initiate irrigation system",
                    "Check soil moisture sensors for accuracy"
                ],
                "confidence": 1.0
            }
        }


class InsightsResponse(BaseModel):
    """Response model for GET /api/insights endpoint."""
    insights: List[InsightItem]
    timestamp: datetime
    sensor_count: int

    class Config:
        json_schema_extra = {
            "example": {
                "insights": [
                    {
                        "type": "warning",
                        "message": "Temperature is above optimal range (30.5°C)",
                        "severity": "medium",
                        "recommendation": "Consider increasing ventilation or reducing heating"
                    },
                    {
                        "type": "warning",
                        "message": "Soil moisture is low (25.0%)",
                        "severity": "high",
                        "recommendation": "Water the plants immediately"
                    }
                ],
                "timestamp": "2024-01-15T10:30:00",
                "sensor_count": 3
            }
        }


class HistoryResponse(BaseModel):
    """Response model for GET /api/sensors/history endpoint."""
    readings: List[SensorReadingResponse]
    count: int
    hours: int = Field(..., description="Number of hours of history requested")

    class Config:
        json_schema_extra = {
            "example": {
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
        }


class NodeMetrics(BaseModel):
    """Metrics model for node insights."""
    avg_temp_24h: Optional[float] = Field(None, description="Average temperature over last 24 hours (°C)")
    avg_temp_7d: Optional[float] = Field(None, description="Average temperature over last 7 days (°C)")
    temp_rate_per_hour: Optional[float] = Field(None, description="Temperature rate of change (°C per hour)")
    soil_moisture_drop_per_day: Optional[float] = Field(None, description="Soil moisture drop rate (% per day)")
    avg_humidity_24h: Optional[float] = Field(None, description="Average humidity over last 24 hours (%)")
    avg_soil_moisture_24h: Optional[float] = Field(None, description="Average soil moisture over last 24 hours (%)")


class NodeInsightsResponse(BaseModel):
    """Response model for GET /api/ai/insights/{node_id} endpoint."""
    node_id: str = Field(..., description="Sensor node identifier")
    summary: str = Field(..., description="Human-readable summary of analysis")
    risk_level: str = Field(..., description="Overall risk level: low, medium, or high")
    recommendations: List[str] = Field(..., description="List of actionable recommendations")
    metrics: NodeMetrics = Field(..., description="Calculated historical metrics")

    class Config:
        json_schema_extra = {
            "example": {
                "node_id": "gateway-01",
                "summary": "Node gateway-01: Overheating detected (avg temp: 36.2°C); Rapid temperature increase (1.2°C/hour)",
                "risk_level": "medium",
                "recommendations": [
                    "Start ventilation 30 minutes earlier than usual",
                    "Increase ventilation frequency by 50%",
                    "Start ventilation 30 minutes earlier",
                    "Monitor temperature every 15 minutes"
                ],
                "metrics": {
                    "avg_temp_24h": 31.2,
                    "avg_temp_7d": 29.8,
                    "temp_rate_per_hour": 1.1,
                    "soil_moisture_drop_per_day": 7.5,
                    "avg_humidity_24h": 68.5,
                    "avg_soil_moisture_24h": 42.3
                }
            }
        }


class InsightDetail(BaseModel):
    """Individual insight with structured information."""
    type: str = Field(..., description="Type of insight: drought_risk, overwatering_risk, temperature_stress, sensor_failure")
    risk_level: str = Field(..., description="Risk level: LOW, MEDIUM, or HIGH")
    explanation: str = Field(..., description="Detailed explanation of the detected condition")
    recommended_action: str = Field(..., description="Specific recommended action to address the issue")

    class Config:
        json_schema_extra = {
            "example": {
                "type": "drought_risk",
                "risk_level": "MEDIUM",
                "explanation": "Low soil moisture detected: 25.0% (threshold: 30.0%)",
                "recommended_action": "Increase irrigation frequency by 30-50%. Monitor soil moisture closely. Check if irrigation system is functioning properly."
            }
        }


class TrendInsightsResponse(BaseModel):
    """Response model for GET /api/ai/insights endpoint with trend analysis."""
    insights: List[InsightDetail] = Field(..., description="List of detected insights with risk levels and recommendations")
    overall_risk_level: str = Field(..., description="Overall risk level: LOW, MEDIUM, or HIGH (highest from all insights)")
    summary: str = Field(..., description="Human-readable summary of all insights")
    analysis_period_minutes: int = Field(..., description="Number of minutes of data analyzed")
    readings_analyzed: int = Field(..., description="Number of sensor readings analyzed")
    node_id: Optional[str] = Field(None, description="Node ID if filtered to specific node")

    class Config:
        json_schema_extra = {
            "example": {
                "insights": [
                    {
                        "type": "drought_risk",
                        "risk_level": "MEDIUM",
                        "explanation": "Low soil moisture detected: 25.0% (threshold: 30.0%)",
                        "recommended_action": "Increase irrigation frequency by 30-50%. Monitor soil moisture closely. Check if irrigation system is functioning properly."
                    },
                    {
                        "type": "temperature_stress",
                        "risk_level": "MEDIUM",
                        "explanation": "High temperature detected: 36.5°C (threshold: 35.0°C)",
                        "recommended_action": "Increase ventilation. Activate cooling systems if available. Start ventilation earlier and increase frequency."
                    }
                ],
                "overall_risk_level": "MEDIUM",
                "summary": "Detected 2 insight(s): 0 high-risk, 2 medium-risk - drought_risk: Low soil moisture detected: 25.0% (threshold: 30.0%); temperature_stress: High temperature detected: 36.5°C (threshold: 35.0°C)",
                "analysis_period_minutes": 60,
                "readings_analyzed": 12,
                "node_id": "node-01"
            }
        }
