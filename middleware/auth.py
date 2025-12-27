"""Basic token authentication middleware."""
from fastapi import Security, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Optional
import os
import secrets


# Security scheme
security = HTTPBearer(auto_error=False)

# Token storage (in production, use environment variable or secure storage)
API_TOKEN = os.getenv("API_TOKEN", secrets.token_urlsafe(32))

# Allow token to be passed via query parameter for ESP32 compatibility
# (since some ESP32 HTTP clients don't support headers well)
QUERY_PARAM_TOKEN = "api_token"


def verify_token(credentials: Optional[HTTPAuthorizationCredentials] = None, token: Optional[str] = None) -> bool:
    """
    Verify API token from header or query parameter.
    
    Args:
        credentials: HTTP Bearer credentials from header
        token: Token from query parameter (for ESP32 compatibility)
        
    Returns:
        True if token is valid, False otherwise
    """
    # Check header first (standard way)
    if credentials and credentials.credentials == API_TOKEN:
        return True
    
    # Check query parameter (ESP32 compatibility)
    if token and token == API_TOKEN:
        return True
    
    return False


async def get_current_token(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security),
    token: Optional[str] = None
) -> str:
    """
    Dependency to get and verify API token.
    
    Usage:
        @router.get("/protected")
        async def protected_endpoint(token: str = Depends(get_current_token)):
            ...
    """
    if verify_token(credentials, token):
        return API_TOKEN
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing API token"
    )


def optional_token(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security),
    token: Optional[str] = None
) -> Optional[str]:
    """
    Optional token dependency - returns token if valid, None otherwise.
    Useful for endpoints that work with or without authentication.
    """
    if verify_token(credentials, token):
        return API_TOKEN
    return None

