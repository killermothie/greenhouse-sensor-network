"""Main FastAPI application entry point."""
import logging
from datetime import datetime
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from models.database import init_db
from routes import sensors, insights, ai, gateway

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - [gateway_id=%(gateway_id)s] - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown events."""
    # Startup: Initialize database
    init_db()
    logger.info("Backend online - Database initialized")
    yield
    # Shutdown: Cleanup if needed
    logger.info("Backend shutting down")


# Create FastAPI app
app = FastAPI(
    title="Greenhouse Sensor Network API",
    description="Production-ready FastAPI backend for greenhouse wireless sensor network",
    version="1.0.0",
    lifespan=lifespan
)

# Configure rate limiting
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Configure CORS for Flutter app and ESP32 gateway
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Middleware for logging requests with gateway_id
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log all requests with gateway_id and timestamp."""
    import time
    start_time = time.time()
    
    # Extract gateway_id from query params or body if available
    gateway_id = request.query_params.get("gateway_id", "unknown")
    
    # Try to extract from JSON body for POST requests (non-blocking)
    if request.method == "POST" and "application/json" in request.headers.get("content-type", ""):
        try:
            body = await request.body()
            if body:
                import json
                try:
                    body_json = json.loads(body)
                    gateway_id = body_json.get("gatewayId") or body_json.get("gateway_id") or gateway_id
                except:
                    pass
            # Recreate request with body for downstream handlers
            async def receive():
                return body
            request._receive = receive
        except:
            pass
    
    # Log request
    logger.info(
        f"{request.method} {request.url.path}",
        extra={"gateway_id": gateway_id}
    )
    
    response = await call_next(request)
    
    # Log response
    process_time = time.time() - start_time
    logger.info(
        f"{request.method} {request.url.path} - {response.status_code} ({process_time:.3f}s)",
        extra={"gateway_id": gateway_id}
    )
    
    return response

# Include routers
# Note: Routers have their own prefixes defined. For v1, we maintain backward compatibility
# by keeping existing routes while documenting v1 as preferred.
app.include_router(sensors.router)
app.include_router(insights.router)
app.include_router(ai.router)
app.include_router(gateway.router)


@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "message": "Greenhouse Sensor Network API",
        "version": "1.0.0",
        "docs": "/docs",
        "version": "1.0.0",
        "api_version": "v1",
        "endpoints": {
            "v1": {
                "POST /api/v1/sensors/data": "Receive sensor data from ESP32",
                "GET /api/v1/sensors/latest": "Get latest sensor reading",
                "GET /api/v1/sensors/status": "Get system health status",
                "GET /api/v1/sensors/history": "Get historical sensor data",
                "GET /api/v1/gateways/status": "Get gateway online/offline status",
                "GET /api/v1/gateways": "List all registered gateways",
                "GET /api/v1/ai/insights": "Get AI insights with trend analysis",
                "GET /api/v1/ai/insights/{node_id}": "Get node-specific AI insights"
            },
            "legacy": {
                "note": "Legacy endpoints maintained for backward compatibility",
                "POST /api/sensors/data": "Receive sensor data (deprecated, use /api/v1/sensors/data)",
                "GET /api/ai/insights": "Get AI insights (deprecated, use /api/v1/ai/insights)"
            }
        }
    }


@app.get("/health")
async def health_check():
    """Health check endpoint for deployment monitoring and ESP32 connectivity checks."""
    import os
    return {
        "status": "healthy",
        "service": "greenhouse-sensor-api",
        "version": "1.0.0",
        "environment": "production" if os.getenv("PORT") else "local",
        "timestamp": datetime.utcnow().isoformat()
    }


@app.get("/status")
async def status_endpoint():
    """
    Status endpoint for compatibility with ESP32 gateway local API.
    
    This endpoint provides basic status information and redirects callers
    to use the proper API endpoints:
    - For system status: GET /api/sensors/status
    - For gateway status: GET /api/gateway/status?gateway_id=xxx
    """
    import os
    return {
        "status": "online",
        "service": "greenhouse-sensor-api",
        "version": "1.0.0",
        "environment": "production" if os.getenv("PORT") else "local",
        "timestamp": datetime.utcnow().isoformat(),
        "endpoints": {
            "system_status": "/api/sensors/status",
            "gateway_status": "/api/gateway/status",
            "health": "/health"
        }
    }


if __name__ == "__main__":
    import uvicorn
    import os
    import socket
    
    # Get port from environment variable (Render sets $PORT), default to 8000 for local dev
    port = int(os.getenv("PORT", "8000"))
    host = "0.0.0.0"  # Bind to all interfaces for cloud deployment
    
    # Get local IP address for display (only in local development)
    local_ip = "localhost"
    if port == 8000:  # Only try to get local IP if using default port (local dev)
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
            s.close()
        except Exception:
            pass
    
    # Clear startup logs
    print("=" * 60)
    print("Greenhouse Sensor Network API")
    print("=" * 60)
    if port == 8000:
        print(f"Starting server on http://{host}:{port}")
        print(f"Local access: http://{local_ip}:{port}")
        print(f"API Documentation: http://{local_ip}:{port}/docs")
        print(f"Health Check: http://{local_ip}:{port}/health")
        print("=" * 60)
        print("Press CTRL+C to stop the server")
    else:
        print(f"Backend online - Listening on {host}:{port}")
        print(f"API Documentation: /docs")
        print(f"Health Check: /health")
    print("=" * 60)
    
    uvicorn.run(app, host=host, port=port, log_level="info")

