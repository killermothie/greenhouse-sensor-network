"""Standardized API response models and error codes."""
from pydantic import BaseModel, Field
from typing import Optional, Any, Dict, List
from datetime import datetime
from enum import Enum


class ErrorCode(str, Enum):
    """Standardized error codes for the API."""
    # Authentication & Authorization (1000-1999)
    AUTH_REQUIRED = "AUTH_001"
    AUTH_INVALID_TOKEN = "AUTH_002"
    AUTH_TOKEN_EXPIRED = "AUTH_003"
    
    # Validation Errors (2000-2999)
    VALIDATION_ERROR = "VAL_001"
    VALIDATION_MISSING_FIELD = "VAL_002"
    VALIDATION_INVALID_VALUE = "VAL_003"
    VALIDATION_OUT_OF_RANGE = "VAL_004"
    
    # Resource Errors (3000-3999)
    RESOURCE_NOT_FOUND = "RES_001"
    RESOURCE_ALREADY_EXISTS = "RES_002"
    RESOURCE_CONFLICT = "RES_003"
    
    # Sensor Errors (4000-4999)
    SENSOR_NO_DATA = "SEN_001"
    SENSOR_INVALID_DATA = "SEN_002"
    SENSOR_STALE_DATA = "SEN_003"
    
    # Gateway Errors (5000-5999)
    GATEWAY_NOT_FOUND = "GAT_001"
    GATEWAY_OFFLINE = "GAT_002"
    GATEWAY_NOT_REGISTERED = "GAT_003"
    
    # Server Errors (9000-9999)
    INTERNAL_ERROR = "SRV_001"
    DATABASE_ERROR = "SRV_002"
    EXTERNAL_SERVICE_ERROR = "SRV_003"
    
    # Rate Limiting (8000-8999)
    RATE_LIMIT_EXCEEDED = "RATE_001"


class StandardResponse(BaseModel):
    """Standardized API response wrapper."""
    success: bool = Field(..., description="Whether the request was successful")
    message: Optional[str] = Field(None, description="Human-readable message")
    data: Optional[Any] = Field(None, description="Response data (if successful)")
    error: Optional["ErrorResponse"] = Field(None, description="Error details (if unsuccessful)")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Response timestamp")
    version: str = Field(default="v1", description="API version")


class ErrorResponse(BaseModel):
    """Standardized error response model."""
    code: str = Field(..., description="Error code (e.g., AUTH_001)")
    message: str = Field(..., description="Human-readable error message")
    details: Optional[Dict[str, Any]] = Field(None, description="Additional error details")
    field: Optional[str] = Field(None, description="Field name if validation error")


# Update forward reference
StandardResponse.model_rebuild()


def success_response(data: Any = None, message: str = "Success", version: str = "v1") -> StandardResponse:
    """Create a standardized success response."""
    return StandardResponse(
        success=True,
        message=message,
        data=data,
        error=None,
        version=version
    )


def error_response(
    code: ErrorCode,
    message: str,
    details: Optional[Dict[str, Any]] = None,
    field: Optional[str] = None,
    version: str = "v1"
) -> StandardResponse:
    """Create a standardized error response."""
    return StandardResponse(
        success=False,
        message=message,
        data=None,
        error=ErrorResponse(
            code=code.value,
            message=message,
            details=details,
            field=field
        ),
        version=version
    )

