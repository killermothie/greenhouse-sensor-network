# Deployment Checklist

## Pre-Deployment

### Code Review
- [ ] All code reviewed and tested locally
- [ ] Unit tests pass (if implemented)
- [ ] Integration tests pass
- [ ] No console.log or debug statements in production code
- [ ] Error handling verified
- [ ] Security vulnerabilities addressed

### Configuration
- [ ] Environment variables documented
- [ ] API token generated and secured
- [ ] Database migrations completed (if any)
- [ ] CORS configured for production domains
- [ ] Logging level set appropriately
- [ ] Rate limiting configured

### Database
- [ ] Database backup strategy in place
- [ ] Migration scripts tested
- [ ] Database connection pool configured
- [ ] Indexes optimized for queries

### Security
- [ ] API token set in environment variables
- [ ] HTTPS enabled (if applicable)
- [ ] CORS origins restricted to known domains
- [ ] Input validation on all endpoints
- [ ] SQL injection prevention verified (using ORM)
- [ ] Rate limiting enabled
- [ ] Error messages don't expose sensitive information

## Platform-Specific Deployment

### Render.com

#### Setup
- [ ] Account created at render.com
- [ ] GitHub repository connected
- [ ] Environment variables configured:
  - [ ] `API_TOKEN`
  - [ ] `DATABASE_URL` (optional)
  - [ ] `ENVIRONMENT=production`
  - [ ] `LOG_LEVEL=INFO`

#### Configuration
- [ ] Build command: `pip install -r requirements.txt`
- [ ] Start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
- [ ] Python version specified (e.g., 3.11)
- [ ] Health check path: `/health`
- [ ] Auto-deploy from main branch enabled (optional)

#### Post-Deployment
- [ ] Health check endpoint accessible
- [ ] API documentation accessible at `/docs`
- [ ] Test sensor data endpoint
- [ ] Verify database persistence
- [ ] Check logs for errors

### Railway.app

#### Setup
- [ ] Account created at railway.app
- [ ] GitHub repository connected
- [ ] Project created
- [ ] Environment variables configured

#### Configuration
- [ ] Start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
- [ ] Python version: 3.11
- [ ] Health check configured

#### Post-Deployment
- [ ] Verify deployment successful
- [ ] Test all endpoints
- [ ] Monitor resource usage

### Fly.io

#### Setup
- [ ] Fly CLI installed
- [ ] Account created
- [ ] `fly launch` completed
- [ ] `fly.toml` configured

#### Configuration
- [ ] Port configured (typically 8000)
- [ ] Environment variables set via `fly secrets`
- [ ] Health check configured

#### Post-Deployment
- [ ] Verify app is running: `fly status`
- [ ] Check logs: `fly logs`
- [ ] Test endpoints

### PythonAnywhere

#### Setup
- [ ] Account created
- [ ] Files uploaded via Files tab or Git

#### Configuration
- [ ] Virtual environment created
- [ ] Dependencies installed
- [ ] Web app configured
- [ ] Static files mapped (if any)
- [ ] WSGI file configured

#### Post-Deployment
- [ ] Web app reloaded
- [ ] Test endpoints
- [ ] Check error log

## Post-Deployment Verification

### API Testing
- [ ] Health check: `GET /health` returns 200
- [ ] API docs: `/docs` accessible
- [ ] Sensor data POST: `POST /api/v1/sensors/data` works
- [ ] Latest reading: `GET /api/v1/sensors/latest` works
- [ ] AI insights: `GET /api/v1/ai/insights` works
- [ ] Authentication: Protected endpoints require token

### Integration Testing
- [ ] ESP32 gateway can connect and send data
- [ ] Flutter app can fetch data
- [ ] Database persists data correctly
- [ ] Rate limiting works
- [ ] Error responses are correct

### Monitoring
- [ ] Logs are accessible and readable
- [ ] Error tracking set up (if applicable)
- [ ] Uptime monitoring configured
- [ ] Performance metrics available

## Client Updates

### ESP32 Gateway
- [ ] Backend URL updated to production URL
- [ ] API token configured (if required)
- [ ] Tested connection to production backend
- [ ] Offline buffering verified

### Flutter App
- [ ] API base URL updated to production
- [ ] API token configured (if required)
- [ ] Tested all API calls
- [ ] Error handling verified
- [ ] Offline behavior tested

### Web Dashboard (if applicable)
- [ ] API URL updated
- [ ] CORS configured
- [ ] Tested all features

## Documentation Updates

- [ ] API documentation updated with production URL
- [ ] README updated with deployment information
- [ ] Environment variables documented
- [ ] Client configuration guides updated

## Backup and Recovery

- [ ] Database backup strategy in place
- [ ] Backup frequency determined
- [ ] Recovery procedure documented
- [ ] Backup restoration tested

## Maintenance

- [ ] Log rotation configured
- [ ] Database cleanup scheduled (if needed)
- [ ] Monitoring alerts configured
- [ ] Update procedure documented

## Rollback Plan

- [ ] Previous version tagged in Git
- [ ] Rollback procedure documented
- [ ] Database migration rollback tested (if applicable)

## Performance Optimization

- [ ] Database queries optimized
- [ ] Response times acceptable
- [ ] Connection pooling configured
- [ ] Caching implemented (if applicable)

## Security Checklist

- [ ] API token is strong and unique
- [ ] HTTPS enabled (if using custom domain)
- [ ] Sensitive data not logged
- [ ] Input validation on all endpoints
- [ ] Rate limiting prevents abuse
- [ ] Error messages don't leak information
- [ ] Dependencies up to date
- [ ] Security headers configured (if applicable)

## Final Checklist

- [ ] All tests pass in production environment
- [ ] All endpoints accessible and working
- [ ] Client applications tested
- [ ] Documentation complete
- [ ] Monitoring configured
- [ ] Backup strategy in place
- [ ] Team notified of deployment

