# Render Deployment - Quick Reference

## Final Folder Structure

```
backend_AI/
├── main.py                 # FastAPI app (updated for Render)
├── requirements.txt        # Python dependencies
├── render.yaml            # Render configuration (optional)
├── DEPLOYMENT.md          # Detailed deployment guide
├── models/
│   ├── database.py        # SQLAlchemy models
│   └── schemas.py         # Pydantic schemas
├── routes/
│   ├── sensors.py        # Sensor endpoints
│   ├── insights.py       # Insights endpoints
│   ├── ai.py             # AI endpoints
│   └── gateway.py        # Gateway endpoints
├── services/
│   ├── sensor_service.py
│   ├── gateway_service.py
│   ├── system_stats.py
│   └── ai_insights.py
└── ai/
    └── analyzer.py       # AI analysis
```

## requirements.txt

```
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
pydantic==2.5.0
python-multipart==0.0.6
slowapi==0.1.9
httpx==0.25.2
```

## Uvicorn Start Command

**For Render:**
```bash
uvicorn main:app --host 0.0.0.0 --port $PORT
```

**For Local Development:**
```bash
python main.py
# or
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## Key Changes Made

1. ✅ **Port Configuration**: Uses `$PORT` environment variable (Render sets this automatically)
2. ✅ **Host Binding**: Binds to `0.0.0.0` (all interfaces) for cloud deployment
3. ✅ **Health Endpoint**: Enhanced `/health` endpoint with environment detection
4. ✅ **Startup Logs**: Clear, concise logs that adapt to environment
5. ✅ **CORS**: Already configured for Flutter app (allows all origins)
6. ✅ **Swagger UI**: `/docs` endpoint remains enabled

## Render-Specific Notes

### Free Tier Behavior

- **Auto-spin down**: Service sleeps after 15 minutes of inactivity
- **Cold start**: First request after sleep takes ~30-60 seconds
- **750 hours/month**: Free tier limit (sufficient for development)

### Database

- SQLite database is **ephemeral** (lost on restart/redeploy)
- For production data, consider:
  - Render PostgreSQL (free tier available)
  - External database service
  - Upgrade to paid tier with persistent disk

### Environment Variables

Render automatically sets:
- `$PORT` - **DO NOT override this**

Optional:
- `DATABASE_URL` - Defaults to `sqlite:///./greenhouse.db` if not set

## Deployment Steps

1. **Push code to GitHub**
2. **Log in to Render**: https://dashboard.render.com
3. **Create Web Service**:
   - Connect GitHub repository
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
4. **Deploy** - Render will build and start your service
5. **Get URL**: `https://your-app-name.onrender.com`

## Testing Deployment

```bash
# Health check
curl https://your-app-name.onrender.com/health

# API docs
open https://your-app-name.onrender.com/docs

# Test endpoint
curl https://your-app-name.onrender.com/api/sensors/status
```

## Updating Flutter App

In `flutter_dashboard/lib/services/api_service.dart`:

```dart
// Production (Render)
static const String baseUrl = 'https://your-app-name.onrender.com';

// Local development
// static const String baseUrl = 'http://192.168.8.253:8000';
```

## Updating ESP32 Gateway

In `firmware/main/main.ino`:

```cpp
// Production (Render)
const char* BACKEND_URL = "https://your-app-name.onrender.com";

// Local development
// const char* BACKEND_URL = "http://192.168.8.253:8000";
```

## Local Development (Unchanged)

The backend works exactly the same locally:

```bash
python main.py
```

It automatically detects local vs. cloud environment and adjusts logs accordingly.

