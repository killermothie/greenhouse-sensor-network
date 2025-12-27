# System Hardening Improvements

This document summarizes the hardening improvements made to the ESP32 Gateway + FastAPI backend + Flutter app system.

## ESP32 Gateway Improvements

### 1. Fast Wi-Fi STA → AP Fallback (Max 10 seconds)

**Implementation:**
- Reduced `STA_CONNECT_TIMEOUT` from 20 seconds to 10 seconds
- Implemented fast state machine transitions
- Added non-blocking connection checks with progress logging

**Files Modified:**
- `firmware/main/network_manager.h` - Added state machine enum (INIT, STA_CONNECTING, ONLINE, AP_MODE)
- `firmware/main/network_manager.cpp` - Implemented fast fallback logic

**Design Decision:** The 10-second timeout balances responsiveness with connection stability. Most successful Wi-Fi connections establish within 3-5 seconds, so 10 seconds is sufficient for legitimate connections while fast enough for fallback.

### 2. Non-Blocking Wi-Fi Reconnection

**Implementation:**
- All delays limited to 200ms maximum (`NON_BLOCKING_DELAY_MAX`)
- Retry logic uses non-blocking status checks
- Progress logging every 2 seconds during connection attempts

**Design Decision:** Non-blocking operations ensure the gateway remains responsive to sensor data and local API requests even during connection attempts. This prevents data loss and maintains local functionality.

### 3. Connection State Machine

**States:**
- `INIT`: Initial state on boot
- `STA_CONNECTING`: Actively attempting STA connection
- `ONLINE`: Connected to STA with internet access
- `AP_MODE`: Access Point mode (fallback)

**Implementation:**
- State transitions logged with detailed Serial output
- Each transition includes timestamp and reason
- State persisted in memory (`lastKnownMode`)

**Design Decision:** State machine provides clear visibility into network state, making debugging easier and enabling better error recovery.

### 4. SSID Clearing on Mode Switch

**Implementation:**
- Added `clearSSID()` method
- SSID cleared when switching from STA to AP mode
- Prevents confusion about which network is active

**Design Decision:** Clear SSID prevents user confusion and ensures accurate status reporting.

### 5. Backend Health Check Timeout Handling

**Implementation:**
- Health check timeout: 3 seconds (`HEALTH_CHECK_TIMEOUT`)
- Separate timeout for health checks vs data requests
- Detailed logging of health check results with timing

**Files Modified:**
- `firmware/main/backend_client.h` - Added timeout constant
- `firmware/main/backend_client.cpp` - Improved health check with timeout handling

**Design Decision:** Fast health checks prevent blocking the main loop while still providing accurate connectivity status.

### 6. Detailed Serial Logging

**Implementation:**
- All state transitions logged with `[NETWORK]` prefix
- Backend operations logged with `[BACKEND]` prefix
- Timestamps and elapsed times included in logs
- Format: `[COMPONENT] Message | Reason | Timestamp`

**Design Decision:** Consistent logging format makes debugging easier and provides clear audit trail of system behavior.

## Backend (FastAPI) Improvements

### 1. Health Endpoint

**Implementation:**
- `/health` endpoint already existed, enhanced with timestamp
- Returns JSON with status, service name, and ISO timestamp

**Design Decision:** Health endpoint is lightweight and fast, perfect for ESP32 connectivity checks.

### 2. Request Rate Limiting

**Implementation:**
- Added `slowapi` for rate limiting
- Sensor data endpoint: 100 requests/minute per IP
- Prevents abuse and DoS attacks

**Files Modified:**
- `requirements.txt` - Added `slowapi==0.1.9`
- `main.py` - Configured rate limiter
- `routes/sensors.py` - Applied rate limit to POST endpoint

**Design Decision:** 100 requests/minute is generous for normal sensor data (typically 1-6 per minute) but prevents abuse.

### 3. Strict Sensor Payload Validation

**Implementation:**
- Temperature range: -50°C to 100°C
- Humidity range: 0% to 100%
- Validation errors return 400 with clear error messages
- Invalid data logged with gateway_id and node_id

**Files Modified:**
- `routes/sensors.py` - Added validation checks

**Design Decision:** Strict validation prevents bad data from entering the database and helps identify sensor calibration issues.

### 4. Duplicate and Late Data Handling

**Implementation:**
- Duplicate detection: checks for readings within 5-second window
- Late data: accepts data up to 24 hours old (with warning)
- Future timestamps: uses current time instead
- Returns existing reading for duplicates instead of creating new entry

**Files Modified:**
- `services/sensor_service.py` - Added `check_duplicate()` method
- `routes/sensors.py` - Added duplicate and timestamp validation

**Design Decision:** Graceful handling of duplicates and late data prevents database bloat while handling network issues and buffered data sync.

### 5. Improved Logging Clarity

**Implementation:**
- Custom logging format with gateway_id and timestamp
- Request/response logging middleware
- Structured logging with context (gateway_id, node_id)
- Logs include HTTP method, path, status code, and processing time

**Files Modified:**
- `main.py` - Added logging configuration and middleware
- `routes/sensors.py` - Added structured logging

**Design Decision:** Structured logging makes it easier to trace requests from specific gateways and diagnose issues.

## Flutter App Improvements

### 1. Improved Connection Retry Logic

**Implementation:**
- Retry logic with exponential backoff
- Maximum 3 retries per request
- 500ms delay between retries
- Non-blocking retries (app remains responsive)

**Files Modified:**
- `flutter_dashboard/lib/services/api_service.dart` - Added `_requestWithRetry()` method

**Design Decision:** 3 retries with short delays balances reliability with user experience. More retries would delay error feedback unnecessarily.

### 2. Timeout Handling for All HTTP Calls

**Implementation:**
- All HTTP calls use 5-second timeout
- Separate connection timeout (3 seconds)
- Timeout exceptions caught and handled gracefully
- App never freezes on network failure

**Design Decision:** 5-second timeout is reasonable for most network conditions while preventing indefinite hangs.

### 3. Clear UI Connection States

**Implementation:**
- Three connection states: ONLINE, OFFLINE, GATEWAY-ONLY
- Color-coded status indicators (green/orange/red)
- Connection state banner in status card
- Tooltip in app bar for connection status

**Files Modified:**
- `flutter_dashboard/lib/services/api_service.dart` - Added `ConnectionState` enum
- `flutter_dashboard/lib/widgets/status_card.dart` - Enhanced with connection state display
- `flutter_dashboard/lib/screens/dashboard_screen.dart` - Added connection indicator

**Design Decision:** Clear visual states help users understand system connectivity at a glance. GATEWAY-ONLY state indicates local network availability even when backend is unreachable.

### 4. App Never Freezes on Network Failure

**Implementation:**
- All network calls wrapped in try-catch
- Timeouts prevent indefinite waiting
- Cached data shown immediately while fetching fresh data
- Errors handled gracefully with fallback to cache

**Design Decision:** User experience is prioritized - app remains functional even during network issues by using cached data.

## Summary of Design Decisions

### ESP32 Gateway
1. **Fast fallback (10s)**: Balances responsiveness with connection stability
2. **Non-blocking operations**: Maintains functionality during connection attempts
3. **State machine**: Provides visibility and better error recovery
4. **Detailed logging**: Aids debugging and system monitoring

### Backend
1. **Rate limiting**: Prevents abuse while allowing normal operation
2. **Strict validation**: Prevents bad data and identifies issues early
3. **Graceful duplicate handling**: Prevents database bloat
4. **Structured logging**: Enables tracing and diagnostics

### Flutter App
1. **Retry logic**: Improves reliability without blocking UI
2. **Clear connection states**: Improves user understanding
3. **Cache-first approach**: Maintains functionality during outages
4. **Timeout handling**: Prevents app freezes

## Testing Recommendations

1. **ESP32**: Test STA→AP fallback by disconnecting router during connection attempt
2. **Backend**: Test rate limiting with rapid requests
3. **Flutter**: Test with network disabled/enabled to verify connection state display
4. **End-to-end**: Test duplicate data handling with buffered data sync

## Deployment Notes

1. Update ESP32 firmware with new network manager
2. Install backend dependencies: `pip install -r requirements.txt`
3. Update Flutter app: `flutter pub get` (if needed)
4. Monitor logs for connection state transitions and error patterns

