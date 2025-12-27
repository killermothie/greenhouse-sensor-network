# AI Insights Engine - ML Upgrade Guide

## Current Architecture

The AI insights engine uses rule-based logic to analyze sensor trends and detect risks. The architecture is designed to be **ML-ready**, meaning machine learning models can be integrated without changing the API interface.

## Current Rule-Based Detection

### 1. Drought Risk Detection
**Current Logic:**
- Thresholds: Critical (<20%), Low (<30%)
- Trend analysis: Rate of decline in soil moisture
- Risk levels based on current value and drop rate

**ML Upgrade Path:**
- Replace threshold logic with a classification model (e.g., Random Forest, Gradient Boosting)
- Features: Historical soil moisture patterns, temperature, humidity, time of day, season
- Use time series models (LSTM, GRU) for predictive drought forecasting
- Incorporate weather forecasts as external features

### 2. Overwatering Risk Detection
**Current Logic:**
- Thresholds: Critical (>90%), High (>80%)
- Drainage analysis: Rate of change in soil moisture
- Risk levels based on current value and drainage efficiency

**ML Upgrade Path:**
- Binary classification: Overwatering vs. Normal
- Features: Soil moisture level, change rate, temperature, humidity, light levels
- Consider plant-specific models (different plants have different moisture needs)
- Use anomaly detection (Isolation Forest, Autoencoders) for unusual patterns

### 3. Temperature Stress Detection
**Current Logic:**
- Optimal range: 18-32°C
- Stress thresholds: Critical (>38°C or <10°C), High (>35°C)
- Rate of change analysis

**ML Upgrade Path:**
- Regression model for optimal temperature prediction (varies by plant type, time of day)
- Time series forecasting for temperature prediction
- Multi-class classification: Optimal, Hot Stress, Cold Stress, Rapid Change
- Features: Historical temperature, humidity, time of day, season, external weather data

### 4. Sensor Failure Detection
**Current Logic:**
- Missing data detection (no readings for extended period)
- Constant value detection (sensor stuck)
- Stale data detection (old timestamps)
- Unrealistic value detection (out of range)

**ML Upgrade Path:**
- Anomaly detection models: Isolation Forest, One-Class SVM, Autoencoders
- Time series anomaly detection: Detect unusual patterns, not just constant values
- Multi-sensor correlation: Compare readings across sensors to detect failures
- Predictive maintenance: Predict sensor failure before it happens

## Recommended ML Implementation Strategy

### Phase 1: Feature Engineering & Data Collection
1. **Collect labeled data:**
   - Historical sensor data with known events (drought periods, overwatering incidents, equipment failures)
   - Label data with ground truth (e.g., "drought confirmed", "sensor replaced due to failure")

2. **Feature extraction:**
   ```python
   # Example features for ML models
   features = {
       # Temporal features
       'hour_of_day': int,
       'day_of_week': int,
       'month': int,
       'season': str,
       
       # Current readings
       'temperature': float,
       'humidity': float,
       'soil_moisture': float,
       'light_level': float,
       
       # Historical statistics (last N hours/days)
       'temp_mean_24h': float,
       'temp_std_24h': float,
       'temp_trend': float,  # Slope of linear regression
       'humidity_mean_24h': float,
       'soil_moisture_mean_24h': float,
       'soil_moisture_change_rate': float,
       
       # Derived features
       'temp_humidity_ratio': float,
       'vapor_pressure_deficit': float,
       
       # External data (if available)
       'external_temp': float,
       'external_humidity': float,
       'weather_forecast': dict
   }
   ```

### Phase 2: Model Development
1. **Start with simpler models:**
   - Random Forest for classification (drought/overwatering risk)
   - Gradient Boosting (XGBoost, LightGBM) for better performance
   - Baseline comparison: Compare ML predictions with current rule-based system

2. **Time series models:**
   - LSTM/GRU for sequential pattern recognition
   - Prophet for time series forecasting
   - Attention mechanisms for identifying important time periods

3. **Anomaly detection:**
   - Isolation Forest for sensor failure detection
   - Autoencoders for learning normal patterns
   - DBSCAN clustering for unusual patterns

### Phase 3: Model Integration
Replace rule-based logic in `TrendInsightService` while maintaining the same interface:

```python
# Example: ML-ready interface
class TrendInsightService:
    @staticmethod
    def detect_drought_risk(readings: List[SensorReading]) -> Optional[Dict]:
        # Option 1: Use rule-based (current)
        if USE_RULE_BASED:
            return self._detect_drought_risk_rules(readings)
        
        # Option 2: Use ML model
        features = self._extract_features(readings)
        prediction = drought_risk_model.predict(features)
        return self._format_ml_prediction(prediction, readings)
```

### Phase 4: Continuous Improvement
1. **Model monitoring:**
   - Track prediction accuracy over time
   - A/B testing: Compare rule-based vs. ML predictions
   - Collect feedback on recommendation effectiveness

2. **Retraining pipeline:**
   - Automatically retrain models with new data
   - Handle concept drift (changing patterns over time)
   - Version control for models

## Recommended ML Libraries

- **Scikit-learn**: Random Forest, Gradient Boosting, SVM
- **XGBoost / LightGBM**: Gradient boosting frameworks
- **TensorFlow / PyTorch**: Deep learning for LSTM/GRU models
- **Prophet**: Time series forecasting
- **Isolation Forest**: Anomaly detection
- **MLflow**: Model versioning and deployment

## ML Model Training Data Requirements

### Minimum Data Requirements:
- **Drought/Overwatering Detection**: 
  - 100+ labeled examples of each condition
  - 6+ months of historical data
  - Multiple sensors/nodes for generalization

- **Temperature Stress**:
  - Seasonal data (all 4 seasons)
  - Different temperature scenarios
  - 50+ stress events

- **Sensor Failure**:
  - Known failure events with timestamps
  - Pre-failure patterns (sensor degradation)
  - 20+ failure cases

## Integration Points

The current code structure makes ML integration straightforward:

1. **Service Layer** (`services/trend_insights_service.py`):
   - Detection methods can be replaced with ML model calls
   - Same input/output interface maintained

2. **API Layer** (`routes/ai.py`):
   - No changes needed - uses service layer interface

3. **Response Schema** (`models/schemas.py`):
   - Already supports ML predictions through structured output format

## Example ML Integration Code Structure

```python
# services/ml_models.py
class DroughtRiskModel:
    def __init__(self, model_path: str):
        self.model = joblib.load(model_path)
        self.scaler = joblib.load(f"{model_path}.scaler")
    
    def predict(self, features: Dict) -> Dict:
        # Scale features
        feature_vector = self.scaler.transform([self._dict_to_vector(features)])
        
        # Predict
        risk_proba = self.model.predict_proba(feature_vector)[0]
        risk_class = self.model.predict(feature_vector)[0]
        
        return {
            "risk_level": self._class_to_risk_level(risk_class),
            "confidence": max(risk_proba),
            "probabilities": {
                "low": risk_proba[0],
                "medium": risk_proba[1],
                "high": risk_proba[2]
            }
        }

# services/trend_insights_service.py (updated)
class TrendInsightService:
    def __init__(self):
        self.use_ml = os.getenv("USE_ML_MODELS", "false").lower() == "true"
        if self.use_ml:
            self.drought_model = DroughtRiskModel("models/drought_risk.pkl")
            # ... load other models
    
    @staticmethod
    def detect_drought_risk(readings: List[SensorReading]) -> Optional[Dict]:
        if self.use_ml:
            features = self._extract_ml_features(readings)
            ml_result = self.drought_model.predict(features)
            return self._format_ml_result(ml_result, readings)
        else:
            # Use existing rule-based logic
            return self._detect_drought_risk_rules(readings)
```

## Benefits of ML Upgrade

1. **Improved Accuracy**: ML models can learn complex patterns not captured by simple rules
2. **Adaptability**: Models can adapt to different plant types, seasons, and local conditions
3. **Predictive Capabilities**: Forecast future risks before they occur
4. **Personalization**: Models can learn from specific greenhouse conditions
5. **Reduced False Positives**: Better discrimination between actual risks and normal variations

## Migration Strategy

1. **Parallel Run**: Run both rule-based and ML models in parallel, compare results
2. **Gradual Rollout**: Start with low-risk insights, gradually expand
3. **Fallback Mechanism**: Keep rule-based system as backup if ML models fail
4. **Monitoring**: Track ML model performance vs. rule-based system
5. **User Feedback**: Collect feedback on recommendation quality

