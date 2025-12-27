"""AI insights service for analyzing historical sensor data.

This module provides deterministic, rule-based analysis of historical sensor data
to generate proactive insights and recommendations. No machine learning is used.
"""
from sqlalchemy.orm import Session
from sqlalchemy import func, and_
from typing import Dict, List, Optional, Tuple
from datetime import datetime, timedelta
from models.database import SensorReading


class AIInsightsService:
    """Service for generating AI insights from historical sensor data."""
    
    # Thresholds for analysis
    TEMP_OVERHEAT_THRESHOLD = 35.0  # °C
    TEMP_RATE_HIGH = 1.0  # °C per hour
    SOIL_MOISTURE_LOW = 30.0  # %
    SOIL_MOISTURE_DROP_HIGH = 5.0  # % per day
    HUMIDITY_HIGH = 75.0  # %
    HUMIDITY_FUNGAL_RISK = 70.0  # % with temp 20-30°C
    
    @staticmethod
    def get_historical_metrics(
        db: Session,
        node_id: str,
        hours_24: int = 24,
        days_7: int = 7
    ) -> Dict[str, Optional[float]]:
        """Calculate historical metrics for a specific node.
        
        Args:
            db: Database session
            node_id: Sensor node identifier
            hours_24: Hours for 24-hour analysis (default: 24)
            days_7: Days for 7-day analysis (default: 7)
            
        Returns:
            Dictionary with calculated metrics or None if insufficient data
        """
        now = datetime.utcnow()
        cutoff_24h = now - timedelta(hours=hours_24)
        cutoff_7d = now - timedelta(days=days_7)
        
        # Get readings for 24 hours
        readings_24h = db.query(SensorReading).filter(
            and_(
                SensorReading.node_id == node_id,
                SensorReading.timestamp >= cutoff_24h
            )
        ).order_by(SensorReading.timestamp).all()
        
        # Get readings for 7 days
        readings_7d = db.query(SensorReading).filter(
            and_(
                SensorReading.node_id == node_id,
                SensorReading.timestamp >= cutoff_7d
            )
        ).order_by(SensorReading.timestamp).all()
        
        metrics = {
            "avg_temp_24h": None,
            "avg_temp_7d": None,
            "temp_rate_per_hour": None,
            "soil_moisture_drop_per_day": None,
            "avg_humidity_24h": None,
            "avg_soil_moisture_24h": None,
        }
        
        # Calculate 24-hour average temperature
        if readings_24h:
            temps_24h = [r.temperature for r in readings_24h if r.temperature is not None]
            if temps_24h:
                metrics["avg_temp_24h"] = sum(temps_24h) / len(temps_24h)
            
            # Calculate temperature rate of change (°C per hour)
            if len(readings_24h) >= 2:
                first_temp = readings_24h[0].temperature
                last_temp = readings_24h[-1].temperature
                time_diff_hours = (readings_24h[-1].timestamp - readings_24h[0].timestamp).total_seconds() / 3600
                if time_diff_hours > 0:
                    metrics["temp_rate_per_hour"] = (last_temp - first_temp) / time_diff_hours
            
            # Calculate average humidity
            humidities = [r.humidity for r in readings_24h if r.humidity is not None]
            if humidities:
                metrics["avg_humidity_24h"] = sum(humidities) / len(humidities)
            
            # Calculate average soil moisture
            soil_moistures = [r.soil_moisture for r in readings_24h if r.soil_moisture is not None]
            if soil_moistures:
                metrics["avg_soil_moisture_24h"] = sum(soil_moistures) / len(soil_moistures)
        
        # Calculate 7-day average temperature
        if readings_7d:
            temps_7d = [r.temperature for r in readings_7d if r.temperature is not None]
            if temps_7d:
                metrics["avg_temp_7d"] = sum(temps_7d) / len(temps_7d)
        
        # Calculate soil moisture drop rate per day
        if readings_24h and len(readings_24h) >= 2:
            # Get first and last soil moisture readings
            first_moisture = readings_24h[0].soil_moisture
            last_moisture = readings_24h[-1].soil_moisture
            time_diff_days = (readings_24h[-1].timestamp - readings_24h[0].timestamp).total_seconds() / 86400
            if time_diff_days > 0 and first_moisture is not None and last_moisture is not None:
                metrics["soil_moisture_drop_per_day"] = (first_moisture - last_moisture) / time_diff_days
        
        return metrics
    
    @staticmethod
    def detect_conditions(metrics: Dict[str, Optional[float]]) -> List[Tuple[str, str]]:
        """Detect conditions based on metrics.
        
        Args:
            metrics: Dictionary of calculated metrics
            
        Returns:
            List of tuples (condition_name, severity) where severity is 'low', 'medium', or 'high'
        """
        conditions = []
        
        # Overheating trend detection
        avg_temp_24h = metrics.get("avg_temp_24h")
        temp_rate = metrics.get("temp_rate_per_hour")
        
        if avg_temp_24h is not None:
            if avg_temp_24h > AIInsightsService.TEMP_OVERHEAT_THRESHOLD:
                if avg_temp_24h > 38.0:
                    conditions.append(("overheating", "high"))
                elif avg_temp_24h > 36.0:
                    conditions.append(("overheating", "medium"))
                else:
                    conditions.append(("overheating", "low"))
        
        # Rapid temperature increase
        if temp_rate is not None:
            if temp_rate > 1.5:
                conditions.append(("rapid_heating", "high"))
            elif temp_rate > AIInsightsService.TEMP_RATE_HIGH:
                conditions.append(("rapid_heating", "medium"))
            elif temp_rate > 0.5:
                conditions.append(("rapid_heating", "low"))
        
        # Soil moisture depletion
        soil_drop = metrics.get("soil_moisture_drop_per_day")
        avg_soil = metrics.get("avg_soil_moisture_24h")
        
        if soil_drop is not None and soil_drop > 0:
            if soil_drop > 10.0 or (avg_soil is not None and avg_soil < AIInsightsService.SOIL_MOISTURE_LOW):
                conditions.append(("soil_depletion", "high"))
            elif soil_drop > AIInsightsService.SOIL_MOISTURE_DROP_HIGH:
                conditions.append(("soil_depletion", "medium"))
            elif soil_drop > 3.0:
                conditions.append(("soil_depletion", "low"))
        
        # Fungal risk: High humidity + moderate temperature
        avg_humidity = metrics.get("avg_humidity_24h")
        if avg_temp_24h is not None and avg_humidity is not None:
            if (avg_humidity >= AIInsightsService.HUMIDITY_FUNGAL_RISK and 
                20.0 <= avg_temp_24h <= 30.0):
                if avg_humidity >= AIInsightsService.HUMIDITY_HIGH:
                    conditions.append(("fungal_risk", "high"))
                else:
                    conditions.append(("fungal_risk", "medium"))
        
        return conditions
    
    @staticmethod
    def assign_risk_level(conditions: List[Tuple[str, str]]) -> str:
        """Assign overall risk level based on detected conditions.
        
        Args:
            conditions: List of (condition_name, severity) tuples
            
        Returns:
            Risk level: 'low', 'medium', or 'high'
        """
        if not conditions:
            return "low"
        
        # Count high, medium, and low severity conditions
        high_count = sum(1 for _, severity in conditions if severity == "high")
        medium_count = sum(1 for _, severity in conditions if severity == "medium")
        low_count = sum(1 for _, severity in conditions if severity == "low")
        
        # Risk level logic
        if high_count > 0 or medium_count >= 2:
            return "high"
        elif medium_count > 0 or low_count >= 3:
            return "medium"
        else:
            return "low"
    
    @staticmethod
    def generate_recommendations(
        conditions: List[Tuple[str, str]],
        metrics: Dict[str, Optional[float]]
    ) -> List[str]:
        """Generate human-readable recommendations based on conditions.
        
        Args:
            conditions: List of (condition_name, severity) tuples
            metrics: Dictionary of calculated metrics
            
        Returns:
            List of recommendation strings
        """
        recommendations = []
        condition_names = {name for name, _ in conditions}
        
        # Overheating recommendations
        if "overheating" in condition_names:
            avg_temp = metrics.get("avg_temp_24h", 0)
            if avg_temp > 38.0:
                recommendations.append("Activate emergency cooling systems immediately")
                recommendations.append("Increase ventilation to maximum capacity")
            elif avg_temp > 36.0:
                recommendations.append("Start ventilation 30 minutes earlier than usual")
                recommendations.append("Increase ventilation frequency by 50%")
            else:
                recommendations.append("Start ventilation 15 minutes earlier")
        
        # Rapid heating recommendations
        if "rapid_heating" in condition_names:
            temp_rate = metrics.get("temp_rate_per_hour", 0)
            if temp_rate > 1.5:
                recommendations.append("Immediate ventilation required - temperature rising rapidly")
                recommendations.append("Check for heating system malfunction")
            elif temp_rate > 1.0:
                recommendations.append("Start ventilation 30 minutes earlier")
                recommendations.append("Monitor temperature every 15 minutes")
            else:
                recommendations.append("Consider starting ventilation earlier")
        
        # Soil moisture recommendations
        if "soil_depletion" in condition_names:
            soil_drop = metrics.get("soil_moisture_drop_per_day", 0)
            avg_soil = metrics.get("avg_soil_moisture_24h", 0)
            
            if soil_drop > 10.0 or (avg_soil is not None and avg_soil < AIInsightsService.SOIL_MOISTURE_LOW):
                recommendations.append("Increase irrigation frequency by 30%")
                recommendations.append("Check irrigation system for blockages")
            elif soil_drop > AIInsightsService.SOIL_MOISTURE_DROP_HIGH:
                recommendations.append("Increase irrigation frequency by 20%")
                recommendations.append("Monitor soil moisture twice daily")
            else:
                recommendations.append("Increase irrigation frequency by 10%")
        
        # Fungal risk recommendations
        if "fungal_risk" in condition_names:
            avg_humidity = metrics.get("avg_humidity_24h", 0)
            if avg_humidity >= AIInsightsService.HUMIDITY_HIGH:
                recommendations.append("Improve airflow immediately to reduce humidity")
                recommendations.append("Consider dehumidification system")
                recommendations.append("Increase ventilation to prevent fungal growth")
            else:
                recommendations.append("Improve airflow to reduce humidity")
                recommendations.append("Increase ventilation frequency")
        
        # If no specific conditions, provide general maintenance
        if not recommendations:
            recommendations.append("All systems operating within normal parameters")
        
        return recommendations
    
    @staticmethod
    def generate_summary(
        conditions: List[Tuple[str, str]],
        metrics: Dict[str, Optional[float]],
        node_id: str
    ) -> str:
        """Generate human-readable summary of analysis.
        
        Args:
            conditions: List of (condition_name, severity) tuples
            metrics: Dictionary of calculated metrics
            node_id: Sensor node identifier
            
        Returns:
            Summary string
        """
        if not conditions:
            return f"Node {node_id}: All conditions normal. Greenhouse operating within optimal parameters."
        
        # Build summary from conditions
        summaries = []
        
        for condition_name, severity in conditions:
            if condition_name == "overheating":
                avg_temp = metrics.get("avg_temp_24h", 0)
                summaries.append(f"Overheating detected (avg temp: {avg_temp:.1f}°C)")
            elif condition_name == "rapid_heating":
                temp_rate = metrics.get("temp_rate_per_hour", 0)
                summaries.append(f"Rapid temperature increase ({temp_rate:.1f}°C/hour)")
            elif condition_name == "soil_depletion":
                soil_drop = metrics.get("soil_moisture_drop_per_day", 0)
                summaries.append(f"Rapid soil moisture depletion ({soil_drop:.1f}%/day)")
            elif condition_name == "fungal_risk":
                avg_humidity = metrics.get("avg_humidity_24h", 0)
                summaries.append(f"High humidity conditions ({avg_humidity:.1f}%) - fungal risk")
        
        if summaries:
            return f"Node {node_id}: " + "; ".join(summaries)
        else:
            return f"Node {node_id}: Analysis complete. No significant issues detected."
    
    @staticmethod
    def analyze_node(
        db: Session,
        node_id: str
    ) -> Dict:
        """Perform complete analysis for a specific node.
        
        Args:
            db: Database session
            node_id: Sensor node identifier
            
        Returns:
            Dictionary with analysis results including:
            - node_id
            - summary
            - risk_level
            - recommendations
            - metrics
        """
        # Check if node exists
        node_exists = db.query(SensorReading).filter(
            SensorReading.node_id == node_id
        ).first()
        
        if not node_exists:
            return {
                "node_id": node_id,
                "summary": f"Node {node_id}: No data available",
                "risk_level": "low",
                "recommendations": ["No sensor data found for this node"],
                "metrics": {}
            }
        
        # Calculate metrics
        metrics = AIInsightsService.get_historical_metrics(db, node_id)
        
        # Check if we have sufficient data
        if metrics.get("avg_temp_24h") is None:
            return {
                "node_id": node_id,
                "summary": f"Node {node_id}: Insufficient data for analysis (need at least 24 hours of data)",
                "risk_level": "low",
                "recommendations": ["Collect more sensor data for accurate analysis"],
                "metrics": metrics
            }
        
        # Detect conditions
        conditions = AIInsightsService.detect_conditions(metrics)
        
        # Assign risk level
        risk_level = AIInsightsService.assign_risk_level(conditions)
        
        # Generate recommendations
        recommendations = AIInsightsService.generate_recommendations(conditions, metrics)
        
        # Generate summary
        summary = AIInsightsService.generate_summary(conditions, metrics, node_id)
        
        return {
            "node_id": node_id,
            "summary": summary,
            "risk_level": risk_level,
            "recommendations": recommendations,
            "metrics": metrics
        }

