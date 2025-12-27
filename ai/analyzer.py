"""AI analysis module for detecting anomalies and providing insights."""
from typing import List, Dict
from datetime import datetime
from models.schemas import InsightItem
from models.database import SensorReading


# Optimal ranges for greenhouse conditions
OPTIMAL_TEMPERATURE_MIN = 18.0  # Celsius
OPTIMAL_TEMPERATURE_MAX = 28.0  # Celsius
CRITICAL_TEMPERATURE_MIN = 10.0  # Celsius
CRITICAL_TEMPERATURE_MAX = 35.0  # Celsius

OPTIMAL_SOIL_MOISTURE_MIN = 40.0  # Percentage
CRITICAL_SOIL_MOISTURE_MIN = 20.0  # Percentage

OPTIMAL_HUMIDITY_MIN = 40.0  # Percentage
OPTIMAL_HUMIDITY_MAX = 70.0  # Percentage


class SensorAnalyzer:
    """Analyzes sensor data and generates insights."""

    @staticmethod
    def analyze_temperature(temperature: float, sensor_id: str) -> List[InsightItem]:
        """Analyze temperature and return insights if abnormal."""
        insights = []

        if temperature < CRITICAL_TEMPERATURE_MIN:
            insights.append(InsightItem(
                type="warning",
                message=f"Critical: Temperature is dangerously low ({temperature:.1f}°C) at sensor {sensor_id}",
                severity="high",
                recommendation="Immediately check heating system and consider emergency heating measures"
            ))
        elif temperature < OPTIMAL_TEMPERATURE_MIN:
            insights.append(InsightItem(
                type="warning",
                message=f"Temperature is below optimal range ({temperature:.1f}°C) at sensor {sensor_id}",
                severity="medium",
                recommendation="Increase heating or reduce ventilation to maintain optimal growing conditions"
            ))
        elif temperature > CRITICAL_TEMPERATURE_MAX:
            insights.append(InsightItem(
                type="warning",
                message=f"Critical: Temperature is dangerously high ({temperature:.1f}°C) at sensor {sensor_id}",
                severity="high",
                recommendation="Immediately increase ventilation, activate cooling systems, or provide shade"
            ))
        elif temperature > OPTIMAL_TEMPERATURE_MAX:
            insights.append(InsightItem(
                type="warning",
                message=f"Temperature is above optimal range ({temperature:.1f}°C) at sensor {sensor_id}",
                severity="medium",
                recommendation="Consider increasing ventilation or reducing heating to maintain optimal conditions"
            ))

        return insights

    @staticmethod
    def analyze_soil_moisture(soil_moisture: float, sensor_id: str) -> List[InsightItem]:
        """Analyze soil moisture and return insights if low."""
        insights = []

        if soil_moisture < CRITICAL_SOIL_MOISTURE_MIN:
            insights.append(InsightItem(
                type="warning",
                message=f"Critical: Soil moisture is critically low ({soil_moisture:.1f}%) at sensor {sensor_id}",
                severity="high",
                recommendation="Water the plants immediately to prevent wilting and plant stress"
            ))
        elif soil_moisture < OPTIMAL_SOIL_MOISTURE_MIN:
            insights.append(InsightItem(
                type="warning",
                message=f"Soil moisture is below optimal range ({soil_moisture:.1f}%) at sensor {sensor_id}",
                severity="medium",
                recommendation="Schedule watering soon to maintain healthy plant growth"
            ))

        return insights

    @staticmethod
    def analyze_humidity(humidity: float, sensor_id: str) -> List[InsightItem]:
        """Analyze humidity and return insights if abnormal."""
        insights = []

        if humidity < OPTIMAL_HUMIDITY_MIN:
            insights.append(InsightItem(
                type="info",
                message=f"Humidity is below optimal range ({humidity:.1f}%) at sensor {sensor_id}",
                severity="low",
                recommendation="Consider increasing humidity through misting or water trays"
            ))
        elif humidity > OPTIMAL_HUMIDITY_MAX:
            insights.append(InsightItem(
                type="info",
                message=f"Humidity is above optimal range ({humidity:.1f}%) at sensor {sensor_id}",
                severity="low",
                recommendation="Increase ventilation to reduce humidity and prevent fungal growth"
            ))

        return insights

    @staticmethod
    def generate_insights(readings: List[SensorReading]) -> List[InsightItem]:
        """Generate comprehensive insights from sensor readings."""
        all_insights = []

        for reading in readings:
            # Analyze temperature
            all_insights.extend(
                SensorAnalyzer.analyze_temperature(reading.temperature, reading.sensor_id)
            )

            # Analyze soil moisture
            all_insights.extend(
                SensorAnalyzer.analyze_soil_moisture(reading.soil_moisture, reading.sensor_id)
            )

            # Analyze humidity
            all_insights.extend(
                SensorAnalyzer.analyze_humidity(reading.humidity, reading.sensor_id)
            )

        # If no issues found, provide positive feedback
        if not all_insights:
            all_insights.append(InsightItem(
                type="success",
                message="All sensor readings are within optimal ranges",
                severity="low",
                recommendation="Continue monitoring. Current conditions are ideal for plant growth."
            ))

        return all_insights

