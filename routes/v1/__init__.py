"""API v1 routes."""
from fastapi import APIRouter
from routes.v1 import sensors, ai, gateway, insights

# Create v1 API router
router = APIRouter(prefix="/api/v1", tags=["v1"])

# Include all v1 sub-routers
router.include_router(sensors.router, prefix="/sensors", tags=["sensors"])
router.include_router(ai.router, prefix="/ai", tags=["ai"])
router.include_router(gateway.router, prefix="/gateways", tags=["gateways"])
router.include_router(insights.router, prefix="/insights", tags=["insights"])

