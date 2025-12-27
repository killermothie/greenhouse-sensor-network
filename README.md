# Greenhouse Sensor Network API

Production-ready FastAPI backend for a greenhouse wireless sensor network. This API receives sensor data from ESP32 gateways and provides AI-powered insights for Flutter applications.

## Features

- **RESTful API** for ESP32 gateway and Flutter app communication
- **SQLite database** for sensor data storage
- **AI-powered analysis** with anomaly detection
- **Production-ready** architecture with clean separation of concerns
- **Cloud deployment ready** (Render, Heroku, etc.)

## Project Structure

```
backend_AI/
├── main.py                 # FastAPI application entry point
├── requirements.txt        # Python dependencies
├── routes/                 # API route handlers
│   ├── sensors.py         # Sensor data endpoints
│   └── insights.py        # AI insights endpoint
├── services/               # Business logic layer
│   └── sensor_service.py  # Sensor data operations
├── models/                 # Data models
│   ├── database.py        # SQLAlchemy models and DB setup
│   └── schemas.py         # Pydantic validation models
└── ai/                     # AI analysis module
    └── analyzer.py        # Anomaly detection and insights
```

## Installation

1. **Clone the repository** (or navigate to the project directory)

2. **Create a virtual environment:**
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. **Install dependencies:**
```bash
pip install -r requirements.txt
```

4. **Run the application:**
```bash
python main.py
```

Or using uvicorn directly:
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API will be available at `http://localhost:8000`

## API Documentation

Once the server is running, visit:
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

## API Endpoints

### 1. POST /api/sensors/data

Receive sensor data from ESP32 gateway.

**Request Body:**
```json
{
    "sensor_id": "ESP32_001",
    "temperature": 25.5,
    "humidity": 65.0,
    "soil_moisture": 45.0,
    "light_level": 850.0
}
```

**Response (201 Created):**
```json
{
    "id": 1,
    "sensor_id": "ESP32_001",
    "temperature": 25.5,
    "humidity": 65.0,
    "soil_moisture": 45.0,
    "light_level": 850.0,
    "timestamp": "2024-01-15T10:30:00"
}
```

**cURL Example:**
```bash
curl -X POST "http://localhost:8000/api/sensors/data" \
  -H "Content-Type: application/json" \
  -d '{
    "sensor_id": "ESP32_001",
    "temperature": 25.5,
    "humidity": 65.0,
    "soil_moisture": 45.0,
    "light_level": 850.0
  }'
```

### 2. GET /api/sensors/latest

Fetch the latest sensor readings.

**Query Parameters:**
- `limit` (optional): Maximum number of readings (1-100, default: 10)
- `sensor_id` (optional): Filter by specific sensor ID

**Response (200 OK):**
```json
{
    "readings": [
        {
            "id": 1,
            "sensor_id": "ESP32_001",
            "temperature": 25.5,
            "humidity": 65.0,
            "soil_moisture": 45.0,
            "light_level": 850.0,
            "timestamp": "2024-01-15T10:30:00"
        }
    ],
    "count": 1
}
```

**cURL Example:**
```bash
curl "http://localhost:8000/api/sensors/latest?limit=10&sensor_id=ESP32_001"
```

### 3. GET /api/insights

Get AI-generated insights based on latest sensor readings.

**Response (200 OK):**
```json
{
    "insights": [
        {
            "type": "warning",
            "message": "Temperature is above optimal range (30.5°C)",
            "severity": "medium",
            "recommendation": "Consider increasing ventilation or reducing heating"
        },
        {
            "type": "warning",
            "message": "Soil moisture is low (25.0%)",
            "severity": "high",
            "recommendation": "Water the plants immediately"
        }
    ],
    "timestamp": "2024-01-15T10:30:00",
    "sensor_count": 3
}
```

**cURL Example:**
```bash
curl "http://localhost:8000/api/insights"
```

## AI Analysis Features

The AI analysis module detects:

1. **Temperature Anomalies:**
   - Critical low (< 10°C) or high (> 35°C)
   - Sub-optimal ranges (< 18°C or > 28°C)

2. **Soil Moisture Warnings:**
   - Critical low (< 20%)
   - Below optimal (< 40%)

3. **Humidity Monitoring:**
   - Below optimal (< 40%)
   - Above optimal (> 70%)

All insights include:
- **Type**: `warning`, `info`, or `success`
- **Severity**: `low`, `medium`, or `high`
- **Message**: Human-readable description
- **Recommendation**: Actionable advice

## Deployment to Render

### 1. Prepare for Deployment

The application is ready for Render deployment. Ensure you have:

- `requirements.txt` (already included)
- `main.py` as entry point (already configured)

### 2. Deploy on Render

1. **Create a new Web Service** on Render
2. **Connect your repository** or deploy from this codebase
3. **Configure the service:**
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
   - **Environment**: Python 3

4. **Environment Variables** (optional):
   - `DATABASE_URL`: For PostgreSQL (if upgrading from SQLite)
   - `PORT`: Automatically set by Render

### 3. Database Considerations

- **Development**: Uses SQLite (file-based, included in repo)
- **Production**: Consider upgrading to PostgreSQL on Render
  - Add `psycopg2-binary` to `requirements.txt`
  - Set `DATABASE_URL` environment variable
  - Update `models/database.py` to use the env variable (already configured)

## Development

### Running Tests

```bash
# Install test dependencies
pip install pytest pytest-asyncio httpx

# Run tests (when implemented)
pytest
```

### Code Structure

- **routes/**: API endpoint definitions
- **services/**: Business logic and database operations
- **models/**: Database models (SQLAlchemy) and schemas (Pydantic)
- **ai/**: AI analysis and anomaly detection logic

## Environment Variables

- `DATABASE_URL`: Database connection string (default: `sqlite:///./greenhouse.db`)
- `PORT`: Server port (default: 8000)

## License

MIT License

## Support

For issues or questions, please open an issue in the repository.

