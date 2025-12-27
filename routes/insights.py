"""API routes for AI insights endpoint."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
from models.database import get_db
from models.schemas import InsightsResponse
from services.sensor_service import SensorService
from ai.analyzer import SensorAnalyzer

router = APIRouter(prefix="/api/insights", tags=["insights"])


@router.get("", response_model=InsightsResponse)
async def get_insights(db: Session = Depends(get_db)):
    """
    Get AI-generated insights based on latest sensor readings.
    
    Analyzes the most recent readings from all sensors and provides:
    - Temperature anomaly detection
    - Soil moisture level warnings
    - Humidity recommendations
    - Human-readable actionable insights
    
    **Example Response:**
    ```json
    {
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
    ```
    """
    try:
        # Get latest reading from each sensor
        latest_readings = SensorService.get_latest_per_sensor(db)
        
        if not latest_readings:
            raise HTTPException(
                status_code=404,
                detail="No sensor readings found. Please submit sensor data first."
            )
        
        # Generate insights
        insights = SensorAnalyzer.generate_insights(latest_readings)
        
        return InsightsResponse(
            insights=insights,
            timestamp=datetime.utcnow(),
            sensor_count=len(latest_readings)
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error generating insights: {str(e)}")

