"""API routes for AI insights endpoint."""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from datetime import datetime
from typing import List, Optional
from models.database import get_db
from models.schemas import AIInsightsResponse, NodeInsightsResponse, TrendInsightsResponse, InsightDetail
from services.sensor_service import SensorService
from services.ai_insights import AIInsightsService
from services.trend_insights_service import TrendInsightService
from ai.ai_insights_analyzer import AIInsightsAnalyzer

router = APIRouter(prefix="/api/ai", tags=["ai"])


@router.get("/insights", response_model=TrendInsightsResponse)
async def get_ai_insights(
    node_id: Optional[str] = Query(None, description="Filter insights for specific node ID"),
    minutes: int = Query(60, ge=5, le=1440, description="Number of minutes of data to analyze (5-1440, default: 60)"),
    db: Session = Depends(get_db)
):
    """
    Get AI-generated insights based on sensor trend analysis.
    
    Analyzes recent sensor trends (last N minutes) and detects:
    - **Drought risk**: Low soil moisture and declining trends
    - **Overwatering risk**: High soil moisture with poor drainage
    - **Temperature stress**: High/low temperatures or rapid changes
    - **Sensor failure patterns**: Missing data, constant values, stale data, unrealistic values
    
    Each insight includes:
    - `risk_level`: LOW, MEDIUM, or HIGH
    - `explanation`: Detailed explanation of the detected condition
    - `recommended_action`: Specific actionable recommendation
    
    **Example Response:**
    ```json
    {
        "insights": [
            {
                "type": "drought_risk",
                "risk_level": "MEDIUM",
                "explanation": "Low soil moisture detected: 25.0% (threshold: 30.0%)",
                "recommended_action": "Increase irrigation frequency by 30-50%. Monitor soil moisture closely."
            },
            {
                "type": "temperature_stress",
                "risk_level": "MEDIUM",
                "explanation": "High temperature detected: 36.5°C (threshold: 35.0°C)",
                "recommended_action": "Increase ventilation. Activate cooling systems if available."
            }
        ],
        "overall_risk_level": "MEDIUM",
        "summary": "Detected 2 insight(s): 0 high-risk, 2 medium-risk...",
        "analysis_period_minutes": 60,
        "readings_analyzed": 12,
        "node_id": "node-01"
    }
    ```
    
    **Risk Level Logic:**
    - `HIGH`: Critical conditions requiring immediate action
    - `MEDIUM`: Conditions needing attention soon
    - `LOW`: Minor deviations from optimal
    
    **Note:** This is a rule-based system designed to be ML-ready. The analysis logic can be 
    replaced with machine learning models while maintaining the same API interface.
    """
    try:
        # Use comprehensive trend analysis service
        analysis_result = TrendInsightService.analyze_trends(
            db=db,
            node_id=node_id,
            minutes=minutes
        )
        
        # Convert insight dictionaries to InsightDetail models
        insight_details = [
            InsightDetail(**insight) for insight in analysis_result["insights"]
        ]
        
        return TrendInsightsResponse(
            insights=insight_details,
            overall_risk_level=analysis_result["overall_risk_level"],
            summary=analysis_result["summary"],
            analysis_period_minutes=analysis_result["analysis_period_minutes"],
            readings_analyzed=analysis_result["readings_analyzed"],
            node_id=analysis_result["node_id"]
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error generating AI insights: {str(e)}"
        )


@router.get("/insights/{node_id}", response_model=NodeInsightsResponse)
async def get_node_insights(
    node_id: str,
    db: Session = Depends(get_db)
):
    """
    Get AI insights for a specific sensor node based on historical data analysis.
    
    Analyzes historical sensor data (24 hours and 7 days) to provide:
    - Summary of detected conditions
    - Risk level assessment (low, medium, high)
    - Actionable recommendations
    - Calculated metrics (averages, rates of change)
    
    **Analysis Features:**
    - Average temperature over last 24 hours and 7 days
    - Temperature rate of change (°C per hour)
    - Soil moisture daily drop rate
    - Overheating trend detection
    - Rapid soil moisture depletion detection
    - High humidity + moderate temperature → fungal risk detection
    
    **Risk Level Logic:**
    - `high`: One or more high-severity conditions, or 2+ medium-severity conditions
    - `medium`: One medium-severity condition, or 3+ low-severity conditions
    - `low`: No significant issues detected
    
    **Example Response:**
    ```json
    {
        "node_id": "gateway-01",
        "summary": "Node gateway-01: Overheating detected (avg temp: 36.2°C); Rapid temperature increase (1.2°C/hour)",
        "risk_level": "medium",
        "recommendations": [
            "Start ventilation 30 minutes earlier than usual",
            "Increase ventilation frequency by 50%",
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
    ```
    
    **Error Handling:**
    - Returns appropriate message if node has no data
    - Returns message if insufficient data for analysis (< 24 hours)
    - All metrics are optional and will be null if insufficient data
    """
    try:
        # Perform analysis
        analysis_result = AIInsightsService.analyze_node(db, node_id)
        
        # Convert to response model
        return NodeInsightsResponse(**analysis_result)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error generating node insights: {str(e)}"
        )

