# Greenhouse Monitoring System - Architecture Documentation

## Overview

This system is designed to work with **both real and simulated sensor data interchangeably**, making it perfect for development and testing before physical sensors are deployed.

## System Components

### 1. ESP32 Gateway
- Collects data from sensor nodes (ESP-NOW, LoRa, or simulated)
- Forwards data to backend API
- Operates in STA (Wi-Fi) or AP (Access Point) mode
- Buffers data when offline

### 2. Backend API (FastAPI)
- Receives and stores sensor data
- Provides REST API endpoints
- Performs AI analysis on historical data
- Tracks gateway and node status

### 3. Flutter Mobile App
- Real-time dashboard
- Historical charts
- AI insights display
- Offline support with caching

## Database Schema

### Tables

#### `gateways`
- `id`: Primary key
- `gateway_id`: Unique identifier (e.g., "gateway-01")
- `name`: Optional human-readable name
- `is_online`: Boolean status
- `last_seen`: Last contact timestamp
- `created_at`: Registration timestamp

#### `sensor_nodes`
- `id`: Primary key
- `node_id`: Unique identifier (e.g., "node-01")
- `gateway_id`: Foreign key to gateways
- `name`: Optional human-readable name
- `is_simulated`: Boolean (true for simulated nodes)
- `last_seen`: Last contact timestamp
- `created_at`: Registration timestamp

#### `sensor_readings`
- `id`: Primary key
- `node_id`: Foreign key to sensor_nodes
- `gateway_id`: Foreign key to gateways
- `temperature`: Float (°C)
- `humidity`: Float (%)
- `soil_moisture`: Float (%)
- `light_level`: Optional float (lux)
- `battery_level`: Optional int (%)
- `rssi`: Optional int (signal strength)
- `timestamp`: DateTime

## API Endpoints

### Sensor Data
- `POST /api/sensors/data` - Store sensor reading
- `GET /api/sensors/latest` - Latest reading
- `GET /api/sensors/history?node_id=&hours=` - Historical data
- `GET /api/sensors/status` - System health

### Gateway
- `GET /api/gateway/status?gateway_id=` - Gateway online/offline status
- `GET /api/gateway/list` - List all gateways

### AI Insights
- `GET /api/ai/insights?node_id=` - AI insights (latest data)
- `GET /api/ai/insights/{node_id}` - Historical AI insights per node

## Data Flow

### Real Sensor Data
```
Sensor Node (ESP-NOW/LoRa) 
  → ESP32 Gateway 
    → Backend API (POST /api/sensors/data)
      → Database (sensor_readings)
        → Flutter App (GET /api/sensors/latest)
```

### Simulated Data
```
ESP32 Gateway (simulator)
  → Backend API (POST /api/sensors/data)
    → Database (sensor_readings)
      → Flutter App (GET /api/sensors/latest)
```

## Key Features

### 1. Automatic Registration
- Gateways and nodes are automatically registered on first data receipt
- No manual configuration required
- Works seamlessly with real and simulated data

### 2. Online/Offline Detection
- Gateways marked online if seen within last 5 minutes
- Automatic offline detection after 10 minutes of inactivity
- Last seen timestamp tracked

### 3. AI Insights
- Rule-based analysis (no ML required)
- Trend detection (temperature rise, moisture drop)
- Risk level assignment (low, medium, high)
- Human-readable recommendations

### 4. Offline Support
- Flutter app caches data using Hive
- Displays cached data when backend unreachable
- Auto-syncs when connection restored

## Development Workflow

### Testing with Simulated Data
1. ESP32 gateway runs sensor simulator
2. Data sent to backend as if from real sensors
3. Backend treats it as real data (is_simulated flag set)
4. Flutter app displays normally

### Deploying Real Sensors
1. Replace simulator with ESP-NOW/LoRa receiver
2. Real nodes send data to gateway
3. Same API endpoints, same database schema
4. No code changes required

## Scalability

### Current
- SQLite (local file database)
- Single backend instance
- Suitable for small to medium deployments

### Future
- PostgreSQL/MySQL for production
- Multiple gateway support
- Cloud hosting (Render, AWS, etc.)
- ESP-NOW mesh networks
- LoRa long-range sensors

## File Structure

```
backend_AI/
├── models/
│   ├── database.py          # SQLAlchemy models
│   └── schemas.py           # Pydantic schemas
├── services/
│   ├── sensor_service.py    # Sensor data operations
│   ├── gateway_service.py   # Gateway management
│   ├── ai_insights.py       # Historical AI analysis
│   └── system_stats.py      # System statistics
├── routes/
│   ├── sensors.py           # Sensor endpoints
│   ├── gateway.py           # Gateway endpoints
│   └── ai.py                # AI insights endpoints
└── main.py                  # FastAPI app

flutter_dashboard/
├── lib/
│   ├── models/
│   │   └── sensor_data.dart # Data models
│   ├── services/
│   │   ├── api_service.dart # HTTP client
│   │   ├── cache_service.dart # Hive caching
│   │   └── notification_service.dart
│   ├── providers/
│   │   └── sensor_providers.dart # Riverpod state
│   ├── screens/
│   │   └── dashboard_screen.dart
│   └── widgets/
│       ├── sensor_data_card.dart
│       ├── history_chart.dart
│       └── ai_insights_card.dart
```

## Design Principles

1. **Modular**: Each component is independent and replaceable
2. **Backward Compatible**: Existing data migrates automatically
3. **Simulated + Real**: Works with both data sources
4. **Scalable**: Ready for cloud deployment
5. **Explainable**: AI insights are rule-based and transparent

