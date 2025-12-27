"""AI insight engine for analyzing sensor trends and detecting risks.

This service provides rule-based analysis of sensor data trends over time to detect:
- Drought risk
- Overwatering risk
- Temperature stress
- Sensor failure patterns

The architecture is ML-ready - rule-based logic can be replaced with ML models
while maintaining the same interface.
"""
from sqlalchemy.orm import Session
from sqlalchemy import and_
from typing import List, Dict, Optional, Tuple
from datetime import datetime, timedelta
from enum import Enum
from models.database import SensorReading
import statistics


class RiskLevel(str, Enum):
    """Risk level enumeration."""
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class InsightType(str, Enum):
    """Types of insights that can be detected."""
    DROUGHT_RISK = "drought_risk"
    OVERWATERING_RISK = "overwatering_risk"
    TEMPERATURE_STRESS = "temperature_stress"
    SENSOR_FAILURE = "sensor_failure"


class TrendInsightService:
    """Service for analyzing sensor trends and generating AI insights."""
    
    # Thresholds for analysis
    SOIL_MOISTURE_DROUGHT_LOW = 30.0  # % - below this is drought risk
    SOIL_MOISTURE_DROUGHT_CRITICAL = 20.0  # % - critical drought level
    SOIL_MOISTURE_OVERWATERING_HIGH = 80.0  # % - above this is overwatering risk
    SOIL_MOISTURE_OVERWATERING_CRITICAL = 90.0  # % - critical overwatering
    
    TEMP_MIN_OPTIMAL = 18.0  # °C - minimum optimal temperature
    TEMP_MAX_OPTIMAL = 32.0  # °C - maximum optimal temperature
    TEMP_STRESS_HIGH = 35.0  # °C - high temperature stress
    TEMP_STRESS_CRITICAL = 38.0  # °C - critical temperature
    TEMP_STRESS_LOW = 10.0  # °C - low temperature stress
    TEMP_RATE_RISKY = 2.0  # °C per hour - rapid temperature change
    
    SENSOR_FAILURE_MISSING_DATA_MINUTES = 15  # No data for this long suggests failure
    SENSOR_FAILURE_STALE_THRESHOLD = 60  # seconds - data older than this is stale
    SENSOR_FAILURE_CONSTANT_VALUES_THRESHOLD = 0.1  # Variation threshold for constant detection
    
    @staticmethod
    def get_recent_readings(
        db: Session,
        node_id: Optional[str] = None,
        minutes: int = 60
    ) -> List[SensorReading]:
        """Get sensor readings from the last N minutes.
        
        Args:
            db: Database session
            node_id: Optional filter by node ID
            minutes: Number of minutes of history to retrieve (default: 60)
            
        Returns:
            List of SensorReading objects ordered by timestamp (oldest first)
        """
        cutoff_time = datetime.utcnow() - timedelta(minutes=minutes)
        query = db.query(SensorReading).filter(
            SensorReading.timestamp >= cutoff_time
        )
        
        if node_id:
            query = query.filter(SensorReading.node_id == node_id)
        
        return query.order_by(SensorReading.timestamp).all()
    
    @staticmethod
    def detect_drought_risk(readings: List[SensorReading]) -> Optional[Dict]:
        """Detect drought risk from soil moisture trends.
        
        Drought risk indicators:
        - Current soil moisture below threshold
        - Declining trend in soil moisture
        - Rapid drop rate
        
        Args:
            readings: List of sensor readings (ordered by timestamp)
            
        Returns:
            Dictionary with insight data if drought risk detected, None otherwise
        """
        if not readings or len(readings) < 2:
            return None
        
        # Get soil moisture values
        soil_values = [r.soil_moisture for r in readings if r.soil_moisture is not None]
        if not soil_values:
            return None
        
        latest_moisture = soil_values[-1]
        first_moisture = soil_values[0]
        
        # Calculate drop rate (% per hour)
        time_span_hours = (readings[-1].timestamp - readings[0].timestamp).total_seconds() / 3600
        if time_span_hours <= 0:
            return None
        
        drop_rate = (first_moisture - latest_moisture) / time_span_hours if time_span_hours > 0 else 0
        
        # Check for drought conditions
        risk_level = RiskLevel.LOW
        explanation_parts = []
        
        # Critical drought: very low moisture
        if latest_moisture <= TrendInsightService.SOIL_MOISTURE_DROUGHT_CRITICAL:
            risk_level = RiskLevel.HIGH
            explanation_parts.append(
                f"Critical soil moisture level: {latest_moisture:.1f}% (critical threshold: {TrendInsightService.SOIL_MOISTURE_DROUGHT_CRITICAL}%)"
            )
        # High drought risk: low moisture or rapid decline
        elif latest_moisture <= TrendInsightService.SOIL_MOISTURE_DROUGHT_LOW:
            if drop_rate > 3.0:  # Rapid decline
                risk_level = RiskLevel.HIGH
                explanation_parts.append(
                    f"Low soil moisture ({latest_moisture:.1f}%) with rapid decline ({drop_rate:.1f}%/hour)"
                )
            else:
                risk_level = RiskLevel.MEDIUM
                explanation_parts.append(
                    f"Low soil moisture detected: {latest_moisture:.1f}% (threshold: {TrendInsightService.SOIL_MOISTURE_DROUGHT_LOW}%)"
                )
        # Moderate risk: declining trend even if above threshold
        elif drop_rate > 5.0 and latest_moisture < 40.0:
            risk_level = RiskLevel.MEDIUM
            explanation_parts.append(
                f"Soil moisture declining rapidly ({drop_rate:.1f}%/hour), currently at {latest_moisture:.1f}%"
            )
        else:
            return None  # No drought risk
        
        explanation = "; ".join(explanation_parts)
        
        # Generate recommendations based on risk level
        if risk_level == RiskLevel.HIGH:
            recommended_action = (
                "Immediate irrigation required. Check irrigation system for blockages. "
                "Consider increasing watering frequency by 50-100%."
            )
        elif risk_level == RiskLevel.MEDIUM:
            recommended_action = (
                "Increase irrigation frequency by 30-50%. Monitor soil moisture closely. "
                "Check if irrigation system is functioning properly."
            )
        else:
            recommended_action = (
                "Increase irrigation frequency by 20%. Monitor soil moisture trends."
            )
        
        return {
            "type": InsightType.DROUGHT_RISK,
            "risk_level": risk_level.value,
            "explanation": explanation,
            "recommended_action": recommended_action,
            "current_value": latest_moisture,
            "drop_rate_per_hour": round(drop_rate, 2)
        }
    
    @staticmethod
    def detect_overwatering_risk(readings: List[SensorReading]) -> Optional[Dict]:
        """Detect overwatering risk from soil moisture trends.
        
        Overwatering risk indicators:
        - Soil moisture consistently very high
        - Soil moisture not decreasing (poor drainage)
        
        Args:
            readings: List of sensor readings (ordered by timestamp)
            
        Returns:
            Dictionary with insight data if overwatering risk detected, None otherwise
        """
        if not readings or len(readings) < 3:
            return None
        
        # Get soil moisture values
        soil_values = [r.soil_moisture for r in readings if r.soil_moisture is not None]
        if not soil_values:
            return None
        
        latest_moisture = soil_values[-1]
        avg_moisture = statistics.mean(soil_values)
        
        # Calculate change rate
        time_span_hours = (readings[-1].timestamp - readings[0].timestamp).total_seconds() / 3600
        if time_span_hours <= 0:
            return None
        
        change_rate = (soil_values[-1] - soil_values[0]) / time_span_hours
        
        # Check for overwatering conditions
        risk_level = RiskLevel.LOW
        
        # Critical overwatering: very high moisture
        if latest_moisture >= TrendInsightService.SOIL_MOISTURE_OVERWATERING_CRITICAL:
            risk_level = RiskLevel.HIGH
            explanation = (
                f"Critical overwatering detected: soil moisture at {latest_moisture:.1f}% "
                f"(critical threshold: {TrendInsightService.SOIL_MOISTURE_OVERWATERING_CRITICAL}%). "
                f"Poor drainage may cause root rot."
            )
            recommended_action = (
                "Immediately stop irrigation. Check drainage system. "
                "Consider improving soil drainage or reducing watering frequency by 70-80%. "
                "Monitor for root rot symptoms."
            )
        # High overwatering risk: high moisture with poor drainage
        elif latest_moisture >= TrendInsightService.SOIL_MOISTURE_OVERWATERING_HIGH:
            if change_rate > -0.5:  # Moisture not decreasing (poor drainage)
                risk_level = RiskLevel.HIGH
                explanation = (
                    f"High soil moisture ({latest_moisture:.1f}%) with poor drainage "
                    f"(moisture not decreasing: {change_rate:.2f}%/hour)"
                )
                recommended_action = (
                    "Reduce irrigation frequency by 50-70%. Check drainage system. "
                    "Improve soil aeration and drainage capacity."
                )
            else:
                risk_level = RiskLevel.MEDIUM
                explanation = (
                    f"High soil moisture detected: {latest_moisture:.1f}% "
                    f"(threshold: {TrendInsightService.SOIL_MOISTURE_OVERWATERING_HIGH}%)"
                )
                recommended_action = (
                    "Reduce irrigation frequency by 30-50%. Monitor soil moisture levels. "
                    "Ensure proper drainage."
                )
        # Moderate risk: consistently high average
        elif avg_moisture >= 75.0 and change_rate > -1.0:
            risk_level = RiskLevel.MEDIUM
            explanation = (
                f"Consistently high soil moisture (average: {avg_moisture:.1f}%) with slow drainage "
                f"(change rate: {change_rate:.2f}%/hour)"
            )
            recommended_action = (
                "Reduce irrigation frequency by 20-30%. Monitor drainage efficiency. "
                "Consider improving soil structure for better drainage."
            )
        else:
            return None  # No overwatering risk
        
        return {
            "type": InsightType.OVERWATERING_RISK,
            "risk_level": risk_level.value,
            "explanation": explanation,
            "recommended_action": recommended_action,
            "current_value": latest_moisture,
            "average_value": round(avg_moisture, 2),
            "change_rate_per_hour": round(change_rate, 2)
        }
    
    @staticmethod
    def detect_temperature_stress(readings: List[SensorReading]) -> Optional[Dict]:
        """Detect temperature stress from temperature trends.
        
        Temperature stress indicators:
        - Temperature outside optimal range
        - Rapid temperature changes
        - Sustained high/low temperatures
        
        Args:
            readings: List of sensor readings (ordered by timestamp)
            
        Returns:
            Dictionary with insight data if temperature stress detected, None otherwise
        """
        if not readings or len(readings) < 2:
            return None
        
        # Get temperature values
        temp_values = [r.temperature for r in readings if r.temperature is not None]
        if not temp_values:
            return None
        
        latest_temp = temp_values[-1]
        max_temp = max(temp_values)
        min_temp = min(temp_values)
        avg_temp = statistics.mean(temp_values)
        
        # Calculate temperature change rate
        time_span_hours = (readings[-1].timestamp - readings[0].timestamp).total_seconds() / 3600
        if time_span_hours <= 0:
            return None
        
        temp_rate = (temp_values[-1] - temp_values[0]) / time_span_hours
        
        risk_level = RiskLevel.LOW
        explanation_parts = []
        
        # Critical high temperature
        if latest_temp >= TrendInsightService.TEMP_STRESS_CRITICAL:
            risk_level = RiskLevel.HIGH
            explanation_parts.append(
                f"Critical high temperature: {latest_temp:.1f}°C (critical threshold: {TrendInsightService.TEMP_STRESS_CRITICAL}°C)"
            )
            recommended_action = (
                "Immediate cooling required. Activate emergency ventilation and cooling systems. "
                "Consider shading. Monitor plants for heat stress symptoms."
            )
        # High temperature stress
        elif latest_temp >= TrendInsightService.TEMP_STRESS_HIGH:
            if temp_rate > TrendInsightService.TEMP_RATE_RISKY:
                risk_level = RiskLevel.HIGH
                explanation_parts.append(
                    f"High temperature ({latest_temp:.1f}°C) with rapid increase ({temp_rate:.1f}°C/hour)"
                )
                recommended_action = (
                    "Activate cooling systems immediately. Increase ventilation to maximum. "
                    "Check for heating system malfunction. Monitor temperature every 15 minutes."
                )
            else:
                risk_level = RiskLevel.MEDIUM
                explanation_parts.append(
                    f"High temperature detected: {latest_temp:.1f}°C (threshold: {TrendInsightService.TEMP_STRESS_HIGH}°C)"
                )
                recommended_action = (
                    "Increase ventilation. Activate cooling systems if available. "
                    "Start ventilation earlier and increase frequency."
                )
        # Above optimal but not critical
        elif latest_temp > TrendInsightService.TEMP_MAX_OPTIMAL:
            if avg_temp > TrendInsightService.TEMP_MAX_OPTIMAL + 2:
                risk_level = RiskLevel.MEDIUM
                explanation_parts.append(
                    f"Sustained above-optimal temperature (avg: {avg_temp:.1f}°C, current: {latest_temp:.1f}°C)"
                )
                recommended_action = (
                    "Increase ventilation frequency. Consider starting cooling earlier. "
                    "Monitor for plant stress signs."
                )
            else:
                risk_level = RiskLevel.LOW
                explanation_parts.append(
                    f"Temperature slightly above optimal range (current: {latest_temp:.1f}°C, optimal max: {TrendInsightService.TEMP_MAX_OPTIMAL}°C)"
                )
                recommended_action = "Increase ventilation. Monitor temperature trends."
        # Low temperature stress
        elif latest_temp <= TrendInsightService.TEMP_STRESS_LOW:
            risk_level = RiskLevel.HIGH
            explanation_parts.append(
                f"Critical low temperature: {latest_temp:.1f}°C (threshold: {TrendInsightService.TEMP_STRESS_LOW}°C)"
            )
            recommended_action = (
                "Immediate heating required. Check heating system. Protect plants from frost. "
                "Monitor for cold damage symptoms."
            )
        # Below optimal
        elif latest_temp < TrendInsightService.TEMP_MIN_OPTIMAL:
            if avg_temp < TrendInsightService.TEMP_MIN_OPTIMAL - 2:
                risk_level = RiskLevel.MEDIUM
                explanation_parts.append(
                    f"Sustained below-optimal temperature (avg: {avg_temp:.1f}°C, current: {latest_temp:.1f}°C)"
                )
                recommended_action = (
                    "Increase heating. Check heating system efficiency. "
                    "Monitor plants for slow growth or stress."
                )
            else:
                risk_level = RiskLevel.LOW
                explanation_parts.append(
                    f"Temperature slightly below optimal range (current: {latest_temp:.1f}°C, optimal min: {TrendInsightService.TEMP_MIN_OPTIMAL}°C)"
                )
                recommended_action = "Slight heating increase recommended. Monitor temperature."
        # Rapid temperature change
        elif abs(temp_rate) > TrendInsightService.TEMP_RATE_RISKY:
            risk_level = RiskLevel.MEDIUM
            direction = "increasing" if temp_rate > 0 else "decreasing"
            explanation_parts.append(
                f"Rapid temperature change: {abs(temp_rate):.1f}°C/hour ({direction})"
            )
            recommended_action = (
                f"Temperature {direction} rapidly. Check for system malfunction. "
                "Stabilize temperature gradually. Monitor closely."
            )
        else:
            return None  # No temperature stress
        
        explanation = "; ".join(explanation_parts)
        
        # Use recommended_action from specific condition, or generate generic one
        if 'recommended_action' not in locals():
            recommended_action = "Monitor temperature trends and adjust environmental controls accordingly."
        
        return {
            "type": InsightType.TEMPERATURE_STRESS,
            "risk_level": risk_level.value,
            "explanation": explanation,
            "recommended_action": recommended_action,
            "current_value": latest_temp,
            "average_value": round(avg_temp, 2),
            "min_value": min_temp,
            "max_value": max_temp,
            "change_rate_per_hour": round(temp_rate, 2)
        }
    
    @staticmethod
    def detect_sensor_failure(readings: List[SensorReading], node_id: Optional[str] = None) -> Optional[Dict]:
        """Detect sensor failure patterns.
        
        Sensor failure indicators:
        - Missing data (no readings for extended period)
        - Constant values (sensor stuck)
        - Stale data (last reading is old)
        - Unrealistic values
        
        Args:
            readings: List of sensor readings (ordered by timestamp)
            node_id: Optional node ID for context
            
        Returns:
            Dictionary with insight data if sensor failure detected, None otherwise
        """
        if not readings:
            # No data at all - potential sensor failure
            return {
                "type": InsightType.SENSOR_FAILURE,
                "risk_level": RiskLevel.HIGH.value,
                "explanation": f"No sensor data available for the requested time period" + (f" (node: {node_id})" if node_id else ""),
                "recommended_action": (
                    "Check sensor connectivity and power supply. "
                    "Verify sensor hardware. Check network connectivity if using wireless sensors."
                ),
                "failure_pattern": "no_data"
            }
        
        latest_reading = readings[-1]
        current_time = datetime.utcnow()
        data_age_seconds = (current_time - latest_reading.timestamp).total_seconds()
        
        # Check for stale data
        if data_age_seconds > TrendInsightService.SENSOR_FAILURE_STALE_THRESHOLD:
            age_minutes = data_age_seconds / 60
            risk_level = RiskLevel.HIGH if age_minutes > TrendInsightService.SENSOR_FAILURE_MISSING_DATA_MINUTES else RiskLevel.MEDIUM
            return {
                "type": InsightType.SENSOR_FAILURE,
                "risk_level": risk_level.value,
                "explanation": (
                    f"Stale sensor data detected: last reading is {age_minutes:.1f} minutes old "
                    f"(threshold: {TrendInsightService.SENSOR_FAILURE_STALE_THRESHOLD}s)" + 
                    (f" (node: {node_id})" if node_id else "")
                ),
                "recommended_action": (
                    "Check sensor connectivity and communication. Verify sensor is powered. "
                    "Check gateway connectivity if using wireless sensors. Inspect sensor hardware."
                ),
                "failure_pattern": "stale_data",
                "data_age_seconds": int(data_age_seconds)
            }
        
        # Check for constant values (sensor stuck)
        if len(readings) >= 5:  # Need enough data points
            temp_values = [r.temperature for r in readings if r.temperature is not None]
            soil_values = [r.soil_moisture for r in readings if r.soil_moisture is not None]
            
            # Check temperature variation
            if len(temp_values) >= 5:
                temp_std = statistics.stdev(temp_values) if len(temp_values) > 1 else 0
                if temp_std < TrendInsightService.SENSOR_FAILURE_CONSTANT_VALUES_THRESHOLD:
                    return {
                        "type": InsightType.SENSOR_FAILURE,
                        "risk_level": RiskLevel.MEDIUM.value,
                        "explanation": (
                            f"Temperature sensor appears stuck: constant value {temp_values[-1]:.1f}°C "
                            f"(variation: {temp_std:.3f}°C)" + (f" (node: {node_id})" if node_id else "")
                        ),
                        "recommended_action": (
                            "Temperature sensor may be malfunctioning. Check sensor hardware. "
                            "Verify sensor is not disconnected or damaged. Replace sensor if needed."
                        ),
                        "failure_pattern": "constant_temperature",
                        "constant_value": temp_values[-1]
                    }
            
            # Check soil moisture variation
            if len(soil_values) >= 5:
                soil_std = statistics.stdev(soil_values) if len(soil_values) > 1 else 0
                if soil_std < TrendInsightService.SENSOR_FAILURE_CONSTANT_VALUES_THRESHOLD:
                    return {
                        "type": InsightType.SENSOR_FAILURE,
                        "risk_level": RiskLevel.MEDIUM.value,
                        "explanation": (
                            f"Soil moisture sensor appears stuck: constant value {soil_values[-1]:.1f}% "
                            f"(variation: {soil_std:.3f}%)" + (f" (node: {node_id})" if node_id else "")
                        ),
                        "recommended_action": (
                            "Soil moisture sensor may be malfunctioning. Check sensor placement and connections. "
                            "Verify sensor is not damaged or disconnected. Clean sensor if needed."
                        ),
                        "failure_pattern": "constant_soil_moisture",
                        "constant_value": soil_values[-1]
                    }
        
        # Check for unrealistic values
        if latest_reading.temperature is not None:
            if latest_reading.temperature < -50 or latest_reading.temperature > 100:
                return {
                    "type": InsightType.SENSOR_FAILURE,
                    "risk_level": RiskLevel.HIGH.value,
                    "explanation": (
                        f"Unrealistic temperature value: {latest_reading.temperature:.1f}°C " +
                        (f" (node: {node_id})" if node_id else "")
                    ),
                    "recommended_action": (
                        "Temperature sensor reading is outside valid range. Check sensor calibration. "
                        "Replace sensor if hardware issue is confirmed."
                    ),
                    "failure_pattern": "unrealistic_temperature",
                    "invalid_value": latest_reading.temperature
                }
        
        if latest_reading.soil_moisture is not None:
            if latest_reading.soil_moisture < 0 or latest_reading.soil_moisture > 100:
                return {
                    "type": InsightType.SENSOR_FAILURE,
                    "risk_level": RiskLevel.HIGH.value,
                    "explanation": (
                        f"Unrealistic soil moisture value: {latest_reading.soil_moisture:.1f}% " +
                        (f" (node: {node_id})" if node_id else "")
                    ),
                    "recommended_action": (
                        "Soil moisture sensor reading is outside valid range (0-100%). "
                        "Check sensor calibration and connections. Replace sensor if needed."
                    ),
                    "failure_pattern": "unrealistic_soil_moisture",
                    "invalid_value": latest_reading.soil_moisture
                }
        
        return None  # No sensor failure detected
    
    @staticmethod
    def analyze_trends(
        db: Session,
        node_id: Optional[str] = None,
        minutes: int = 60
    ) -> Dict:
        """Analyze sensor trends and generate comprehensive insights.
        
        Args:
            db: Database session
            node_id: Optional filter by node ID
            minutes: Number of minutes to analyze (default: 60)
            
        Returns:
            Dictionary containing:
            - insights: List of insight dictionaries
            - overall_risk_level: Highest risk level from all insights
            - summary: Human-readable summary
            - analysis_period_minutes: Period analyzed
        """
        readings = TrendInsightService.get_recent_readings(db, node_id, minutes)
        
        insights = []
        
        # Detect various risks (only if we have readings, except sensor failure)
        if readings:
            # Detect drought risk
            drought_insight = TrendInsightService.detect_drought_risk(readings)
            if drought_insight:
                insights.append(drought_insight)
            
            # Detect overwatering risk
            overwatering_insight = TrendInsightService.detect_overwatering_risk(readings)
            if overwatering_insight:
                insights.append(overwatering_insight)
            
            # Detect temperature stress
            temp_insight = TrendInsightService.detect_temperature_stress(readings)
            if temp_insight:
                insights.append(temp_insight)
        
        # Always check for sensor failure (even if no readings)
        sensor_failure_insight = TrendInsightService.detect_sensor_failure(readings, node_id)
        if sensor_failure_insight:
            insights.append(sensor_failure_insight)
        
        # Determine overall risk level
        overall_risk_level = RiskLevel.LOW.value
        if any(i["risk_level"] == RiskLevel.HIGH.value for i in insights):
            overall_risk_level = RiskLevel.HIGH.value
        elif any(i["risk_level"] == RiskLevel.MEDIUM.value for i in insights):
            overall_risk_level = RiskLevel.MEDIUM.value
        
        # Generate summary
        if not insights:
            summary = "All systems operating normally. No significant risks detected in the analyzed period."
        else:
            high_risk_count = sum(1 for i in insights if i["risk_level"] == RiskLevel.HIGH.value)
            medium_risk_count = sum(1 for i in insights if i["risk_level"] == RiskLevel.MEDIUM.value)
            summary_parts = [
                f"Detected {len(insights)} insight(s): {high_risk_count} high-risk, {medium_risk_count} medium-risk"
            ]
            for insight in insights:
                summary_parts.append(f"- {insight['type']}: {insight['explanation']}")
            summary = " ".join(summary_parts)
        
        return {
            "insights": insights,
            "overall_risk_level": overall_risk_level,
            "summary": summary,
            "analysis_period_minutes": minutes,
            "readings_analyzed": len(readings),
            "node_id": node_id
        }

