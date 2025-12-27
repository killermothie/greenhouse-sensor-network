# Deployment Guide - Render (Free Tier)

This guide explains how to deploy the Greenhouse Sensor Network API to Render's free tier.

## Prerequisites

- GitHub account (for connecting to Render)
- Render account (free tier available)
- Backend code pushed to a GitHub repository

## Quick Deploy on Render

### Option 1: Using Render Dashboard (Recommended)

1. **Log in to Render**: https://dashboard.render.com
2. **Create New Web Service**:
   - Click "New +" → "Web Service"
   - Connect your GitHub repository
   - Select the repository containing this backend

3. **Configure Service**:
   - **Name**: `greenhouse-sensor-api` (or your preferred name)
   - **Environment**: `Python 3`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
   - **Root Directory**: Leave empty (or specify if backend is in a subdirectory)

4. **Environment Variables** (Optional):
   - `DATABASE_URL`: `sqlite:///./greenhouse.db` (default, can be left empty)
   - Render automatically sets `$PORT` - **DO NOT** override it

5. **Click "Create Web Service"**

### Option 2: Using render.yaml (Infrastructure as Code)

If you have `render.yaml` in your repository:

1. Log in to Render
2. Go to "Blueprints"
3. Click "New Blueprint"
4. Connect your GitHub repository
5. Render will automatically detect `render.yaml` and create the service

## Post-Deployment

### 1. Get Your Backend URL

After deployment, Render will provide a URL like:
```
https://greenhouse-sensor-api.onrender.com
```

### 2. Update Flutter App

Update `flutter_dashboard/lib/services/api_service.dart`:

```dart
// For production (Render)
static const String baseUrl = 'https://your-app-name.onrender.com';

// For local development, use:
// static const String baseUrl = 'http://192.168.8.253:8000';
```

**Tip**: Use environment variables or build flavors to switch between local and production URLs.

### 3. Update ESP32 Gateway

Update `firmware/main/main.ino`:

```cpp
// For production (Render)
const char* BACKEND_URL = "https://your-app-name.onrender.com";

// For local development:
// const char* BACKEND_URL = "http://192.168.8.253:8000";
```

### 4. Verify Deployment

1. **Health Check**: Visit `https://your-app-name.onrender.com/health`
   - Should return: `{"status": "healthy", ...}`

2. **API Docs**: Visit `https://your-app-name.onrender.com/docs`
   - Swagger UI should load

3. **Test Endpoint**: 
   ```bash
   curl https://your-app-name.onrender.com/api/sensors/status
   ```

## Important Notes

### Render Free Tier Limitations

- **Spins down after 15 minutes of inactivity**
- **Takes ~30-60 seconds to spin up** when first request arrives
- **Limited to 750 hours/month** (enough for always-on if single service)

### Database Persistence

- SQLite database is **ephemeral** on Render free tier
- Data will be lost on redeploy or service restart
- For production, consider:
  - Upgrading to paid tier with persistent disk
  - Using external database (PostgreSQL, etc.)
  - Using Render PostgreSQL (free tier available)

### CORS Configuration

The backend is configured to accept requests from any origin (`allow_origins=["*"]`). This works for:
- Flutter mobile apps (any origin)
- ESP32 gateways
- Web browsers

For enhanced security in production, you can restrict origins:

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://your-flutter-app.com",
        "https://your-app-name.onrender.com",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### Environment-Specific Configuration

The backend automatically detects the environment:
- **Local**: Uses port 8000, shows detailed startup logs
- **Render**: Uses `$PORT` from environment, shows concise logs

## Troubleshooting

### Service Won't Start

1. Check Render logs: Dashboard → Your Service → Logs
2. Verify `requirements.txt` is correct
3. Ensure `main.py` exists in root directory
4. Check that start command is correct: `uvicorn main:app --host 0.0.0.0 --port $PORT`

### Database Issues

- SQLite file is created automatically on first run
- If database errors occur, check file permissions
- Consider using PostgreSQL for production

### CORS Errors

- Backend allows all origins by default
- If issues persist, check Flutter app's baseUrl
- Verify backend URL is correct (HTTPS for Render)

### Slow First Request

- Normal on free tier (cold start)
- Service spins up automatically
- Subsequent requests are fast

## Local Development

To run locally (unchanged):

```bash
python main.py
# or
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The app automatically detects local vs. cloud environment and adjusts accordingly.

## Monitoring

- **Health Endpoint**: `GET /health` - Use for uptime monitoring
- **Render Dashboard**: View logs, metrics, and service status
- **API Docs**: `GET /docs` - Interactive API documentation

## Next Steps

1. Deploy to Render
2. Update Flutter app with Render URL
3. Update ESP32 gateway with Render URL
4. Test end-to-end connectivity
5. Monitor logs for any issues

