# AI Insights Engine - Implementation Summary

## Overview

A comprehensive AI insight engine for greenhouse sensor systems that analyzes recent sensor trends and detects risks using rule-based logic (ML-ready architecture).

## Architecture

### Components

1. **Service Layer** (`services/trend_insights_service.py`)
   - Core analysis logic
   - Trend detection algorithms
   - Risk assessment rules

2. **API Layer** (`routes/ai.py`)
   - RESTful endpoint: `GET /api/ai/insights`
   - Query parameters: `node_id` (optional), `minutes` (default: 60)

3. **Data Models** (`models/schemas.py`)
   - Response schemas: `TrendInsightsResponse`, `InsightDetail`
   - Structured output format

## Detection Capabilities

### 1. Drought Risk
**Detection Logic:**
- Critical: Soil moisture ≤ 20%
- Medium: Soil moisture ≤ 30% or rapid decline (>3%/hour)
- Low: Rapid decline even if above threshold

**Output:**
- Risk level (LOW/MEDIUM/HIGH)
- Explanation with current values and thresholds
- Recommended action (irrigation adjustments)

### 2. Overwatering Risk
**Detection Logic:**
- Critical: Soil moisture ≥ 90% with poor drainage
- High: Soil moisture ≥ 80% with poor drainage
- Medium: High average moisture (>75%) with slow drainage

**Output:**
- Risk level
- Explanation of drainage issues
- Recommended action (reduce irrigation, improve drainage)

### 3. Temperature Stress
**Detection Logic:**
- Critical: Temperature ≥ 38°C or ≤ 10°C
- High: Temperature ≥ 35°C with rapid increase
- Medium: Outside optimal range (18-32°C) or rapid changes

**Output:**
- Risk level
- Explanation with temperature values and trends
- Recommended action (ventilation, heating, cooling)

### 4. Sensor Failure Patterns
**Detection Logic:**
- No data: Missing readings for requested period
- Stale data: Last reading > 60 seconds old
- Constant values: Low variation in readings (< 0.1°C or < 0.1%)
- Unrealistic values: Out of valid range

**Output:**
- Risk level
- Explanation of failure pattern
- Recommended action (hardware check, connectivity verification)

## API Endpoint

### Endpoint
`GET /api/ai/insights`

### Query Parameters
- `node_id` (optional, string): Filter insights for specific sensor node
- `minutes` (optional, integer, default: 60): Number of minutes of data to analyze (range: 5-1440)

### Response Format
```json
{
  "insights": [
    {
      "type": "drought_risk|overwatering_risk|temperature_stress|sensor_failure",
      "risk_level": "LOW|MEDIUM|HIGH",
      "explanation": "Detailed explanation...",
      "recommended_action": "Specific actionable recommendation..."
    }
  ],
  "overall_risk_level": "LOW|MEDIUM|HIGH",
  "summary": "Human-readable summary",
  "analysis_period_minutes": 60,
  "readings_analyzed": 12,
  "node_id": "node-01" | null
}
```

## Usage Examples

### Basic Usage
```bash
curl "http://localhost:8000/api/ai/insights"
```

### Filter by Node
```bash
curl "http://localhost:8000/api/ai/insights?node_id=node-01"
```

### Custom Analysis Period
```bash
curl "http://localhost:8000/api/ai/insights?minutes=120"
```

### Combined Parameters
```bash
curl "http://localhost:8000/api/ai/insights?node_id=node-01&minutes=180"
```

## Thresholds (Configurable)

### Soil Moisture
- Drought Critical: ≤ 20%
- Drought Low: ≤ 30%
- Overwatering Critical: ≥ 90%
- Overwatering High: ≥ 80%

### Temperature
- Optimal Range: 18-32°C
- Stress High: ≥ 35°C
- Stress Critical: ≥ 38°C or ≤ 10°C
- Rapid Change Threshold: ≥ 2.0°C/hour

### Sensor Failure
- Stale Data Threshold: 60 seconds
- Missing Data Threshold: 15 minutes
- Constant Value Variation: < 0.1

## ML-Ready Architecture

The system is designed to be easily upgraded to machine learning models:

1. **Modular Detection Methods**: Each detection method is a separate function that can be replaced with ML model calls
2. **Structured Output**: Consistent output format regardless of analysis method
3. **Feature Extraction**: Data processing can be reused for ML feature engineering
4. **Interface Preservation**: API interface remains unchanged when switching to ML

See `AI_INSIGHTS_ML_UPGRADE.md` for detailed ML upgrade guidance.

## Integration with Existing System

### Database Schema
Uses existing `SensorReading` model with fields:
- `node_id`: Sensor node identifier
- `temperature`: Temperature in Celsius
- `humidity`: Humidity percentage
- `soil_moisture`: Soil moisture percentage
- `timestamp`: Reading timestamp

### Service Dependencies
- `SensorService`: For querying sensor data (already exists)
- `TrendInsightService`: New service for trend analysis

### Backward Compatibility
- Existing `/api/ai/insights` endpoint enhanced (previously analyzed only latest reading)
- Response format changed to structured insights (previous format still available via other endpoints)
- All existing sensor data compatible

## Testing Recommendations

1. **Unit Tests**: Test each detection method with various input scenarios
2. **Integration Tests**: Test API endpoint with mock data
3. **Edge Cases**: 
   - No data available
   - Single reading
   - Constant values
   - Extreme values
4. **Performance Tests**: Verify response time with large datasets

## Future Enhancements

1. **ML Model Integration**: Replace rule-based logic with trained models
2. **Custom Thresholds**: Allow per-node or per-plant-type thresholds
3. **Historical Patterns**: Learn optimal ranges from historical data
4. **Predictive Insights**: Forecast future risks before they occur
5. **Multi-Sensor Correlation**: Cross-validate readings across sensors
6. **External Data Integration**: Incorporate weather forecasts, seasonality
7. **Alert System**: Push notifications for high-risk conditions
8. **Confidence Scores**: Add confidence levels to predictions

## Files Modified/Created

### New Files
- `services/trend_insights_service.py`: Core trend analysis service
- `AI_INSIGHTS_ML_UPGRADE.md`: ML upgrade guide
- `AI_INSIGHTS_EXAMPLES.md`: API response examples
- `AI_INSIGHTS_IMPLEMENTATION.md`: This file

### Modified Files
- `routes/ai.py`: Updated `/api/ai/insights` endpoint to use trend analysis
- `models/schemas.py`: Added `TrendInsightsResponse` and `InsightDetail` schemas
- `services/ai_insights.py`: Fixed bug (sensor_id → node_id)

## Dependencies

No new external dependencies required. Uses existing:
- FastAPI
- SQLAlchemy
- Python standard library (`statistics`, `datetime`, `enum`)

## Performance Considerations

- **Database Queries**: Uses indexed timestamp and node_id columns for efficient queries
- **Analysis Period**: Default 60 minutes balances detail vs. performance
- **Caching**: Consider caching results for frequently accessed nodes
- **Background Processing**: For large-scale deployments, consider background analysis jobs

## Security Considerations

- Uses existing authentication/authorization (if implemented)
- Input validation via FastAPI query parameters
- SQL injection protection via SQLAlchemy ORM
- Rate limiting via existing middleware

## Deployment Notes

1. No database migrations required (uses existing schema)
2. No configuration changes needed (uses environment variables if configured)
3. Backward compatible with existing API clients (response format change is additive)
4. Can be deployed incrementally (old endpoint behavior can be preserved if needed)

