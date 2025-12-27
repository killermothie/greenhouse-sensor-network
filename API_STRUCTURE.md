# API Structure and Standards

## API Versioning

The API supports versioning through URL prefixes. Current version: **v1**

### Base URLs
- **V1 API**: `/api/v1/*` (preferred)
- **Legacy API**: `/api/*` (backward compatible, will be deprecated)

### Versioning Strategy
- Major version in URL path (`/api/v1/`)
- Backward compatibility maintained for legacy endpoints
- New features go into v1, legacy endpoints remain functional

## Endpoint Naming Conventions

### Resource-Based Naming
- Use nouns, not verbs: `/sensors`, `/gateways`, not `/get_sensors`
- Plural for collections: `/sensors`, `/gateways`
- Singular for specific resources: `/insights/{node_id}`
- Use hyphens for multi-word resources: `/sensor-readings`

### HTTP Methods
- `GET`: Retrieve data (idempotent)
- `POST`: Create new resources
- `PUT`: Update entire resource
- `PATCH`: Partial update
- `DELETE`: Remove resource

### Query Parameters
- Use snake_case: `node_id`, `gateway_id`, `hours`
- Use descriptive names: `hours` not `h`, `node_id` not `id`
- Filtering: `?node_id=xxx&hours=24`
- Pagination: `?page=1&limit=50` (if implemented)

## Standardized Response Format

### Success Response
```json
{
  "success": true,
  "message": "Success",
  "data": {
    // Response data here
  },
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "v1"
}
```

### Error Response
```json
{
  "success": false,
  "message": "Error message",
  "error": {
    "code": "RES_001",
    "message": "Resource not found",
    "details": {
      "resource": "node",
      "id": "node-01"
    },
    "field": "node_id"
  },
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "v1"
}
```

## Error Codes

### Authentication & Authorization (1000-1999)
- `AUTH_001`: Authentication required
- `AUTH_002`: Invalid token
- `AUTH_003`: Token expired

### Validation (2000-2999)
- `VAL_001`: Validation error
- `VAL_002`: Missing required field
- `VAL_003`: Invalid value
- `VAL_004`: Value out of range

### Resource Errors (3000-3999)
- `RES_001`: Resource not found
- `RES_002`: Resource already exists
- `RES_003`: Resource conflict

### Sensor Errors (4000-4999)
- `SEN_001`: No sensor data available
- `SEN_002`: Invalid sensor data
- `SEN_003`: Stale sensor data

### Gateway Errors (5000-5999)
- `GAT_001`: Gateway not found
- `GAT_002`: Gateway offline
- `GAT_003`: Gateway not registered

### Server Errors (9000-9999)
- `SRV_001`: Internal server error
- `SRV_002`: Database error
- `SRV_003`: External service error

### Rate Limiting (8000-8999)
- `RATE_001`: Rate limit exceeded

## HTTP Status Codes

| Code | Usage |
|------|-------|
| 200 | Success (GET, PUT, PATCH) |
| 201 | Created (POST) |
| 204 | No Content (DELETE) |
| 400 | Bad Request (validation errors) |
| 401 | Unauthorized (authentication required) |
| 403 | Forbidden (authorization failed) |
| 404 | Not Found (resource doesn't exist) |
| 409 | Conflict (resource conflict) |
| 429 | Too Many Requests (rate limited) |
| 500 | Internal Server Error |
| 503 | Service Unavailable |

## Authentication

### Token-Based Authentication
All endpoints (except sensor data POST and health check) support token authentication:

**Header (Preferred)**:
```
Authorization: Bearer <token>
```

**Query Parameter (ESP32 Compatibility)**:
```
?api_token=<token>
```

### Token Generation
- Set via environment variable: `API_TOKEN`
- Generate secure token: `python -c "import secrets; print(secrets.token_urlsafe(32))"`
- For production, use strong random tokens

## API Endpoints

### Sensor Data
- `POST /api/v1/sensors/data` - Receive sensor readings
- `GET /api/v1/sensors/latest` - Get latest reading
- `GET /api/v1/sensors/history?hours=24&node_id=xxx` - Get historical data
- `GET /api/v1/sensors/status` - Get system status

### AI Insights
- `GET /api/v1/ai/insights?minutes=60&node_id=xxx` - Get trend-based insights
- `GET /api/v1/ai/insights/{node_id}` - Get node-specific insights

### Gateways
- `GET /api/v1/gateways/status?gateway_id=xxx` - Get gateway status
- `GET /api/v1/gateways` - List all gateways

### System
- `GET /health` - Health check (no auth)
- `GET /` - API information (no auth)

## Rate Limiting

- **Sensor Data POST**: 100 requests/minute per IP
- **Other Endpoints**: 1000 requests/minute per IP
- **Rate Limit Header**: `X-RateLimit-Remaining`, `X-RateLimit-Reset`

## CORS

Configured for:
- Flutter mobile apps (all origins in development)
- ESP32 gateways
- Web dashboards

Production: Specify exact origins in `allow_origins`

## Content Types

- **Request**: `application/json`
- **Response**: `application/json`
- **Charset**: UTF-8

## Timestamps

- Format: ISO 8601 with UTC timezone
- Example: `2024-01-15T10:30:00Z`
- All timestamps in UTC

## Pagination (Future)

When implemented:
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 50,
    "total": 150,
    "pages": 3
  }
}
```

## Filtering (Future)

When implemented:
- `?filter[status]=active`
- `?sort=timestamp&order=desc`
- `?fields=id,name,status`

## Best Practices

1. **Consistent Naming**: Use consistent resource names across endpoints
2. **Error Handling**: Always return standardized error responses
3. **Documentation**: Keep API docs up to date
4. **Versioning**: Maintain backward compatibility
5. **Security**: Use HTTPS in production, validate all inputs
6. **Performance**: Use appropriate HTTP status codes, optimize queries
7. **Monitoring**: Log all requests, track errors

