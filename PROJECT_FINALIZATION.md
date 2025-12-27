# Greenhouse IoT System - Final Project Documentation

## System Architecture

### Overview
A comprehensive IoT greenhouse monitoring system consisting of:
- **ESP32 Gateway**: Wireless sensor data collection with offline buffering
- **FastAPI Backend**: RESTful API with AI-powered insights
- **Flutter Mobile App**: Real-time monitoring dashboard
- **Web Dashboard** (optional): Web-based monitoring interface

### Architecture Diagram Description

```
┌─────────────────────────────────────────────────────────────────┐
│                    Greenhouse Sensor Network                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
        ┌───────▼────────┐          ┌───────▼────────┐
        │  Sensor Nodes  │          │  Sensor Nodes  │
        │  (ESP-NOW)     │          │  (ESP-NOW)     │
        │  - Temperature │          │  - Temperature │
        │  - Humidity    │          │  - Humidity    │
        │  - Soil Moisture│         │  - Soil Moisture│
        │  - Battery     │          │  - Battery     │
        └───────┬────────┘          └───────┬────────┘
                │                           │
                │  ESP-NOW Protocol         │
                │                           │
        ┌───────▼───────────────────────────▼────────┐
        │         ESP32 Gateway                       │
        │  ┌────────────────────────────────────┐    │
        │  │  STA Mode (WiFi)                   │    │
        │  │  └─> Connect to Backend            │    │
        │  └────────────────────────────────────┘    │
        │  ┌────────────────────────────────────┐    │
        │  │  AP Mode (Offline)                 │    │
        │  │  └─> Local Buffer (100 readings)   │    │
        │  └────────────────────────────────────┘    │
        └────────────────┬───────────────────────────┘
                         │
                         │  HTTP POST /api/v1/sensors/data
                         │
        ┌────────────────▼───────────────────────────┐
        │         FastAPI Backend                     │
        │  ┌────────────────────────────────────┐    │
        │  │  REST API (v1)                     │    │
        │  │  - Sensor Data Collection          │    │
        │  │  - Gateway Management              │    │
        │  │  - System Status                   │    │
        │  └────────────────────────────────────┘    │
        │  ┌────────────────────────────────────┐    │
        │  │  AI Insight Engine                 │    │
        │  │  - Trend Analysis                  │    │
        │  │  - Risk Detection                  │    │
        │  │  - Recommendations                 │    │
        │  └────────────────────────────────────┘    │
        │  ┌────────────────────────────────────┐    │
        │  │  SQLite Database                   │    │
        │  │  - Sensor Readings                 │    │
        │  │  - Gateway Registry                │    │
        │  │  - Node Registry                   │    │
        │  └────────────────────────────────────┘    │
        └────────────────┬───────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
┌───────▼────────┐  ┌────▼────┐  ┌───────▼────────┐
│ Flutter App    │  │  Web    │  │  External      │
│ (Mobile)       │  │ Dashboard│  │  Services      │
│ - Real-time    │  │ (Opt)    │  │  (Future)      │
│ - Alerts       │  │          │  │                │
│ - History      │  │          │  │                │
└────────────────┘  └──────────┘  └────────────────┘
```

### Component Details

#### 1. Sensor Nodes (ESP32 with Sensors)
- **Communication**: ESP-NOW (mesh networking)
- **Data**: Temperature, Humidity, Soil Moisture, Battery Level, RSSI
- **Power**: Battery-powered with low-power modes
- **Range**: ~100m line-of-sight

#### 2. ESP32 Gateway
- **Dual Mode Operation**:
  - **STA Mode**: Connected to WiFi, forwards data to backend
  - **AP Mode**: Offline operation, buffers data locally
- **Buffer Capacity**: 100 sensor readings
- **Features**: OLED display, HTTP server for local access

#### 3. FastAPI Backend
- **API Version**: v1 (`/api/v1/`)
- **Features**:
  - Sensor data collection and storage
  - Gateway and node management
  - AI-powered trend analysis
  - Real-time insights generation
- **Database**: SQLite (production-ready, can migrate to PostgreSQL)
- **Authentication**: Token-based (optional)

#### 4. Flutter Mobile App
- **Platforms**: Android, iOS
- **Features**:
  - Real-time sensor data display
  - AI insights and recommendations
  - Historical data visualization
  - System status monitoring
  - Offline caching

## API Structure (v1)

### Base URL
```
http://your-domain.com/api/v1
```

### Authentication
All endpoints (except sensor data POST) require authentication:
```
Authorization: Bearer <token>
```
Or via query parameter (ESP32 compatibility):
```
?api_token=<token>
```

### Endpoints

#### Sensor Data
- `POST /api/v1/sensors/data` - Receive sensor readings (ESP32)
- `GET /api/v1/sensors/latest` - Get latest reading
- `GET /api/v1/sensors/history?hours=24` - Get historical data
- `GET /api/v1/sensors/status` - Get system status

#### AI Insights
- `GET /api/v1/ai/insights?minutes=60` - Get trend-based insights
- `GET /api/v1/ai/insights/{node_id}` - Get node-specific insights

#### Gateways
- `GET /api/v1/gateways/status?gateway_id=xxx` - Get gateway status
- `GET /api/v1/gateways` - List all gateways

#### System
- `GET /health` - Health check (no auth required)
- `GET /` - API information

### Standard Response Format

#### Success Response
```json
{
  "success": true,
  "message": "Success",
  "data": { ... },
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "v1"
}
```

#### Error Response
```json
{
  "success": false,
  "message": "Error message",
  "error": {
    "code": "RES_001",
    "message": "Resource not found",
    "details": { ... },
    "field": "node_id"
  },
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "v1"
}
```

### Error Codes

| Code | Category | Description |
|------|----------|-------------|
| AUTH_001 | Authentication | Authentication required |
| AUTH_002 | Authentication | Invalid token |
| VAL_001 | Validation | Validation error |
| RES_001 | Resource | Resource not found |
| SEN_001 | Sensor | No sensor data available |
| GAT_001 | Gateway | Gateway not found |
| SRV_001 | Server | Internal server error |
| RATE_001 | Rate Limit | Rate limit exceeded |

## Deployment

### Free Cloud Deployment Options

#### 1. Render (Recommended)
- **Free Tier**: 750 hours/month
- **Steps**:
  1. Create account at render.com
  2. Connect GitHub repository
  3. Create new Web Service
  4. Set build command: `pip install -r requirements.txt`
  5. Set start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
  6. Add environment variables:
     - `DATABASE_URL` (optional, uses SQLite by default)
     - `API_TOKEN` (for authentication)
  7. Deploy

#### 2. Railway
- **Free Tier**: $5 credit/month
- **Steps**:
  1. Create account at railway.app
  2. New Project → Deploy from GitHub
  3. Add environment variables
  4. Deploy

#### 3. Fly.io
- **Free Tier**: 3 shared VMs
- **Steps**:
  1. Install Fly CLI
  2. `fly launch`
  3. Configure `fly.toml`
  4. `fly deploy`

#### 4. PythonAnywhere
- **Free Tier**: Limited hours, single web app
- **Steps**:
  1. Create account
  2. Upload code via Files tab
  3. Configure web app
  4. Set up virtual environment
  5. Deploy

### Environment Variables
```bash
# Required
API_TOKEN=your-secure-token-here

# Optional
DATABASE_URL=sqlite:///./greenhouse.db
ENVIRONMENT=production
LOG_LEVEL=INFO
```

### Deployment Checklist

- [ ] Code reviewed and tested locally
- [ ] Environment variables configured
- [ ] Database migrations completed (if any)
- [ ] CORS configured for Flutter app domain
- [ ] API token generated and secured
- [ ] Health check endpoint tested
- [ ] Rate limiting configured
- [ ] Error handling verified
- [ ] Logging configured
- [ ] Flutter app updated with new API URL
- [ ] ESP32 gateway updated with new backend URL
- [ ] Documentation updated

## Flutter UI Improvements

### Status Banners
Add colored status banners at the top of the dashboard:
- **Green**: All systems normal
- **Yellow**: Warnings detected
- **Red**: Critical issues
- **Gray**: Offline/No data

### Icons
Use Material Design icons for:
- Temperature: `thermostat`
- Humidity: `water_drop`
- Soil Moisture: `eco`
- Battery: `battery_charging_full` / `battery_alert`
- WiFi: `wifi` / `wifi_off`
- Alert: `warning` / `error` / `check_circle`

### UI Components to Add
1. **Status Banner Widget**
2. **Icon-based Metric Cards**
3. **Risk Level Indicators** (color-coded)
4. **Refresh Indicators** (loading states)
5. **Empty States** (no data messages)

## Demo Scenarios

### Scenario 1: Normal Operation (2 minutes)
1. Show system overview (all sensors online)
2. Display real-time sensor readings
3. Show AI insights (all LOW risk)
4. Demonstrate historical data chart

### Scenario 2: Drought Detection (3 minutes)
1. Simulate low soil moisture data
2. Show AI insight detection (MEDIUM risk)
3. Display recommendation banner
4. Show trend chart indicating decline

### Scenario 3: Temperature Stress (3 minutes)
1. Simulate high temperature reading
2. Show AI insight (HIGH risk)
3. Display urgent recommendation
4. Show temperature trend

### Scenario 4: Sensor Failure (2 minutes)
1. Stop sending data from one sensor
2. Show sensor failure detection
3. Display maintenance alert
4. Demonstrate offline buffering on gateway

### Scenario 5: Offline Operation (2 minutes)
1. Disconnect backend
2. Show gateway AP mode operation
3. Show Flutter app offline state
4. Reconnect and show data sync

### Total Demo Time: ~12 minutes
**Viva Preparation**: Be ready to explain:
- System architecture and design decisions
- ESP-NOW vs WiFi trade-offs
- Offline buffering strategy
- AI insight algorithms
- API design choices
- Deployment considerations
- Future enhancements

## Talking Points for Viva

### Technical Decisions
1. **ESP-NOW Protocol**: Why mesh networking for sensors?
   - Low power consumption
   - No WiFi dependency
   - Long range
   - Mesh redundancy

2. **Offline Buffering**: Why 100 readings?
   - Trade-off between memory and reliability
   - Covers ~2 hours at 1 reading/minute
   - Prevents data loss during outages

3. **SQLite Database**: Why not PostgreSQL?
   - Simplicity for MVP
   - Zero configuration
   - Sufficient for single-instance deployment
   - Easy migration path if needed

4. **AI Insights**: Rule-based vs ML?
   - Rule-based for MVP (no training data needed)
   - ML-ready architecture
   - Explainable results
   - Fast inference

5. **API Versioning**: Why /api/v1?
   - Future-proofing
   - Backward compatibility
   - Professional standard

### Future Enhancements
1. Machine Learning integration
2. Multi-user support with roles
3. SMS/Email alerts
4. Predictive maintenance
5. Multi-greenhouse management
6. Mobile app notifications
7. Web dashboard
8. OTA updates for ESP32
9. Energy harvesting for sensors
10. Integration with irrigation systems

## Presentation Structure

1. **Introduction** (1 min)
   - Problem statement
   - Solution overview

2. **System Architecture** (2 min)
   - Component diagram
   - Data flow

3. **Live Demo** (12 min)
   - Scenarios 1-5

4. **Technical Deep Dive** (3 min)
   - Key technologies
   - Design decisions

5. **Results & Future Work** (2 min)
   - Achievements
   - Future enhancements

**Total**: ~20 minutes

