# AI Insights API - Example Responses

This document provides example responses from the `/api/ai/insights` endpoint to demonstrate the structured output format.

## Endpoint

`GET /api/ai/insights?node_id=node-01&minutes=60`

### Query Parameters
- `node_id` (optional): Filter insights for specific sensor node
- `minutes` (optional): Number of minutes of data to analyze (default: 60, range: 5-1440)

## Example 1: Drought Risk Detected

**Request:**
```bash
GET /api/ai/insights?minutes=60
```

**Response:**
```json
{
  "insights": [
    {
      "type": "drought_risk",
      "risk_level": "MEDIUM",
      "explanation": "Low soil moisture detected: 25.0% (threshold: 30.0%)",
      "recommended_action": "Increase irrigation frequency by 30-50%. Monitor soil moisture closely. Check if irrigation system is functioning properly."
    }
  ],
  "overall_risk_level": "MEDIUM",
  "summary": "Detected 1 insight(s): 0 high-risk, 1 medium-risk - drought_risk: Low soil moisture detected: 25.0% (threshold: 30.0%)",
  "analysis_period_minutes": 60,
  "readings_analyzed": 12,
  "node_id": null
}
```

## Example 2: Multiple Risks Detected

**Request:**
```bash
GET /api/ai/insights?node_id=node-01&minutes=120
```

**Response:**
```json
{
  "insights": [
    {
      "type": "drought_risk",
      "risk_level": "HIGH",
      "explanation": "Critical soil moisture level: 18.5% (critical threshold: 20.0%)",
      "recommended_action": "Immediate irrigation required. Check irrigation system for blockages. Consider increasing watering frequency by 50-100%."
    },
    {
      "type": "temperature_stress",
      "risk_level": "MEDIUM",
      "explanation": "High temperature detected: 36.5°C (threshold: 35.0°C)",
      "recommended_action": "Increase ventilation. Activate cooling systems if available. Start ventilation earlier and increase frequency."
    }
  ],
  "overall_risk_level": "HIGH",
  "summary": "Detected 2 insight(s): 1 high-risk, 1 medium-risk - drought_risk: Critical soil moisture level: 18.5% (critical threshold: 20.0%); temperature_stress: High temperature detected: 36.5°C (threshold: 35.0°C)",
  "analysis_period_minutes": 120,
  "readings_analyzed": 24,
  "node_id": "node-01"
}
```

## Example 3: Overwatering Risk

**Request:**
```bash
GET /api/ai/insights?minutes=60
```

**Response:**
```json
{
  "insights": [
    {
      "type": "overwatering_risk",
      "risk_level": "MEDIUM",
      "explanation": "High soil moisture detected: 82.5% (threshold: 80.0%)",
      "recommended_action": "Reduce irrigation frequency by 30-50%. Monitor soil moisture levels. Ensure proper drainage."
    }
  ],
  "overall_risk_level": "MEDIUM",
  "summary": "Detected 1 insight(s): 0 high-risk, 1 medium-risk - overwatering_risk: High soil moisture detected: 82.5% (threshold: 80.0%)",
  "analysis_period_minutes": 60,
  "readings_analyzed": 12,
  "node_id": null
}
```

## Example 4: Sensor Failure Detected

**Request:**
```bash
GET /api/ai/insights?node_id=node-02&minutes=30
```

**Response:**
```json
{
  "insights": [
    {
      "type": "sensor_failure",
      "risk_level": "HIGH",
      "explanation": "Stale sensor data detected: last reading is 25.3 minutes old (threshold: 60s) (node: node-02)",
      "recommended_action": "Check sensor connectivity and communication. Verify sensor is powered. Check gateway connectivity if using wireless sensors. Inspect sensor hardware."
    }
  ],
  "overall_risk_level": "HIGH",
  "summary": "Detected 1 insight(s): 1 high-risk, 0 medium-risk - sensor_failure: Stale sensor data detected: last reading is 25.3 minutes old (threshold: 60s) (node: node-02)",
  "analysis_period_minutes": 30,
  "readings_analyzed": 1,
  "node_id": "node-02"
}
```

## Example 5: No Risks Detected (All Normal)

**Request:**
```bash
GET /api/ai/insights?minutes=60
```

**Response:**
```json
{
  "insights": [],
  "overall_risk_level": "LOW",
  "summary": "All systems operating normally. No significant risks detected in the analyzed period.",
  "analysis_period_minutes": 60,
  "readings_analyzed": 12,
  "node_id": null
}
```

## Example 6: Rapid Temperature Change

**Request:**
```bash
GET /api/ai/insights?minutes=60
```

**Response:**
```json
{
  "insights": [
    {
      "type": "temperature_stress",
      "risk_level": "MEDIUM",
      "explanation": "Rapid temperature change: 2.5°C/hour (increasing)",
      "recommended_action": "Temperature increasing rapidly. Check for system malfunction. Stabilize temperature gradually. Monitor closely."
    }
  ],
  "overall_risk_level": "MEDIUM",
  "summary": "Detected 1 insight(s): 0 high-risk, 1 medium-risk - temperature_stress: Rapid temperature change: 2.5°C/hour (increasing)",
  "analysis_period_minutes": 60,
  "readings_analyzed": 12,
  "node_id": null
}
```

## Example 7: Critical Overwatering with Poor Drainage

**Request:**
```bash
GET /api/ai/insights?node_id=node-03&minutes=90
```

**Response:**
```json
{
  "insights": [
    {
      "type": "overwatering_risk",
      "risk_level": "HIGH",
      "explanation": "High soil moisture (92.5%) with poor drainage (moisture not decreasing: -0.2%/hour)",
      "recommended_action": "Reduce irrigation frequency by 50-70%. Check drainage system. Improve soil aeration and drainage capacity."
    }
  ],
  "overall_risk_level": "HIGH",
  "summary": "Detected 1 insight(s): 1 high-risk, 0 medium-risk - overwatering_risk: High soil moisture (92.5%) with poor drainage (moisture not decreasing: -0.2%/hour)",
  "analysis_period_minutes": 90,
  "readings_analyzed": 18,
  "node_id": "node-03"
}
```

## Example 8: Sensor Stuck Detection

**Request:**
```bash
GET /api/ai/insights?node_id=node-04&minutes=60
```

**Response:**
```json
{
  "insights": [
    {
      "type": "sensor_failure",
      "risk_level": "MEDIUM",
      "explanation": "Temperature sensor appears stuck: constant value 25.0°C (variation: 0.005°C) (node: node-04)",
      "recommended_action": "Temperature sensor may be malfunctioning. Check sensor hardware. Verify sensor is not disconnected or damaged. Replace sensor if needed."
    }
  ],
  "overall_risk_level": "MEDIUM",
  "summary": "Detected 1 insight(s): 0 high-risk, 1 medium-risk - sensor_failure: Temperature sensor appears stuck: constant value 25.0°C (variation: 0.005°C) (node: node-04)",
  "analysis_period_minutes": 60,
  "readings_analyzed": 12,
  "node_id": "node-04"
}
```

## Response Schema

### InsightDetail
- `type` (string): Type of insight (`drought_risk`, `overwatering_risk`, `temperature_stress`, `sensor_failure`)
- `risk_level` (string): Risk level (`LOW`, `MEDIUM`, `HIGH`)
- `explanation` (string): Detailed explanation of the detected condition
- `recommended_action` (string): Specific recommended action to address the issue

### TrendInsightsResponse
- `insights` (array): List of InsightDetail objects
- `overall_risk_level` (string): Highest risk level from all insights (`LOW`, `MEDIUM`, `HIGH`)
- `summary` (string): Human-readable summary of all insights
- `analysis_period_minutes` (integer): Number of minutes of data analyzed
- `readings_analyzed` (integer): Number of sensor readings analyzed
- `node_id` (string|null): Node ID if filtered to specific node

## Risk Level Determination

- **HIGH**: Critical conditions requiring immediate action (e.g., critical drought, sensor offline, critical temperature)
- **MEDIUM**: Conditions needing attention soon (e.g., low moisture, high temperature, moderate sensor issues)
- **LOW**: Minor deviations from optimal (e.g., slightly above/below optimal ranges)

The `overall_risk_level` is the highest risk level from all detected insights.

