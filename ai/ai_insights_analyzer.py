"""Modular AI-style insights analyzer for sensor data.

This module provides rule-based analysis that can be easily replaced
with ML models in the future.
"""
from typing import List, Dict, Optional
from datetime import datetime, timedelta
from models.database import SensorReading


class AIInsightsAnalyzer:
    """
    Modular AI-style analyzer for sensor data.
    
    This class uses rule-based logic that can be replaced with ML models
    by implementing the same interface.
    """
    
    # Analysis rules (can be replaced with ML model predictions)
    TEMPERATURE_WARNING_THRESHOLD = 35.0  # Celsius
    SOIL_MOISTURE_IRRIGATION_THRESHOLD = 30.0  # Percentage
    BATTERY_MAINTENANCE_THRESHOLD = 20  # Percentage
    STALE_DATA_THRESHOLD_SECONDS = 60  # Seconds
    
    @staticmethod
    def analyze_latest_data(
        latest_reading: Optional[SensorReading],
        current_time: datetime
    ) -> Dict:
        """
        Analyze the latest sensor data and return AI-style insights.
        
        Args:
            latest_reading: The most recent sensor reading (or None)
            current_time: Current timestamp for age calculation
            
        Returns:
            Dictionary with status, summary, recommendations, and confidence
        """
        # Check for no data or stale data
        if latest_reading is None:
            return AIInsightsAnalyzer._generate_offline_insight(
                reason="No sensor data available"
            )
        
        # Check if data is stale (>60 seconds old)
        age_seconds = int((current_time - latest_reading.timestamp).total_seconds())
        if age_seconds > AIInsightsAnalyzer.STALE_DATA_THRESHOLD_SECONDS:
            return AIInsightsAnalyzer._generate_offline_insight(
                reason=f"Sensor data is stale ({age_seconds}s old, threshold: {AIInsightsAnalyzer.STALE_DATA_THRESHOLD_SECONDS}s)"
            )
        
        # Analyze conditions
        issues = []
        recommendations = []
        status = "normal"
        confidence = 1.0
        
        # Rule 1: Temperature > 35 → ventilation warning
        if latest_reading.temperature > AIInsightsAnalyzer.TEMPERATURE_WARNING_THRESHOLD:
            issues.append(
                f"High temperature detected: {latest_reading.temperature:.1f}°C "
                f"(threshold: {AIInsightsAnalyzer.TEMPERATURE_WARNING_THRESHOLD}°C)"
            )
            recommendations.append("Increase ventilation immediately")
            recommendations.append("Activate cooling systems if available")
            status = "warning"
        
        # Rule 2: Soil moisture < 30 → irrigation recommendation
        if latest_reading.soil_moisture < AIInsightsAnalyzer.SOIL_MOISTURE_IRRIGATION_THRESHOLD:
            issues.append(
                f"Low soil moisture detected: {latest_reading.soil_moisture:.1f}% "
                f"(threshold: {AIInsightsAnalyzer.SOIL_MOISTURE_IRRIGATION_THRESHOLD}%)"
            )
            recommendations.append("Initiate irrigation system")
            recommendations.append("Check soil moisture sensors for accuracy")
            if status == "normal":
                status = "warning"
            else:
                status = "critical"  # Multiple issues = critical
        
        # Rule 3: Battery < 20 → maintenance warning
        if latest_reading.battery_level is not None:
            if latest_reading.battery_level < AIInsightsAnalyzer.BATTERY_MAINTENANCE_THRESHOLD:
                issues.append(
                    f"Low battery level: {latest_reading.battery_level}% "
                    f"(threshold: {AIInsightsAnalyzer.BATTERY_MAINTENANCE_THRESHOLD}%)"
                )
                recommendations.append("Schedule sensor maintenance and battery replacement")
                if status == "normal":
                    status = "warning"
        
        # Generate summary
        if not issues:
            summary = (
                f"All systems operating normally. Temperature: {latest_reading.temperature:.1f}°C, "
                f"Soil moisture: {latest_reading.soil_moisture:.1f}%, "
                f"Humidity: {latest_reading.humidity:.1f}%"
            )
            recommendations = ["Continue monitoring. Conditions are optimal."]
        else:
            summary = f"Detected {len(issues)} issue(s): {'; '.join(issues)}"
        
        # Adjust confidence based on data quality
        if latest_reading.rssi is not None and latest_reading.rssi < -80:
            confidence = 0.7  # Lower confidence with weak signal
        elif age_seconds > 30:
            confidence = 0.8  # Slightly lower confidence with older data
        
        return {
            "status": status,
            "summary": summary,
            "recommendations": recommendations,
            "confidence": round(confidence, 2)
        }
    
    @staticmethod
    def _generate_offline_insight(reason: str) -> Dict:
        """Generate insight for offline/stale sensor data."""
        return {
            "status": "critical",
            "summary": f"Sensor appears to be offline: {reason}",
            "recommendations": [
                "Check sensor connectivity",
                "Verify sensor power supply",
                "Inspect sensor hardware for damage",
                "Review network connectivity if using wireless sensors"
            ],
            "confidence": 0.9
        }

