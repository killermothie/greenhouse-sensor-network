# API Quick Reference

## Base URL
```
http://your-domain.com/api/v1
```

## Authentication
```
Authorization: Bearer <token>
# OR
?api_token=<token>
```

## Endpoints

### Sensor Data
```http
POST   /api/v1/sensors/data
GET    /api/v1/sensors/latest
GET    /api/v1/sensors/history?hours=24&node_id=xxx
GET    /api/v1/sensors/status
```

### AI Insights
```http
GET    /api/v1/ai/insights?minutes=60&node_id=xxx
GET    /api/v1/ai/insights/{node_id}
```

### Gateways
```http
GET    /api/v1/gateways/status?gateway_id=xxx
GET    /api/v1/gateways
```

### System
```http
GET    /health
GET    /
```

## Response Format

### Success
```json
{
  "success": true,
  "data": {...},
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "v1"
}
```

### Error
```json
{
  "success": false,
  "error": {
    "code": "RES_001",
    "message": "Resource not found"
  },
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "v1"
}
```

## Error Codes

| Code | Meaning |
|------|---------|
| AUTH_001 | Authentication required |
| AUTH_002 | Invalid token |
| VAL_001 | Validation error |
| RES_001 | Resource not found |
| SEN_001 | No sensor data |
| GAT_001 | Gateway not found |
| SRV_001 | Internal error |
| RATE_001 | Rate limit exceeded |

## Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request |
| 401 | Unauthorized |
| 404 | Not Found |
| 429 | Rate Limited |
| 500 | Server Error |

