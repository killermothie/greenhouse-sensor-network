# Greenhouse Dashboard - Enhanced Flutter App

A modern, production-ready Flutter dashboard for monitoring greenhouse sensor data with offline support, historical charts, AI insights, and push notifications.

## Features

### Core Functionality
- **Real-time Data**: Auto-refreshes every 8 seconds
- **Latest Sensor Data**: Temperature, Humidity, Soil Moisture, Battery, RSSI, Timestamp
- **Historical Charts**: 24-hour trend visualization for temperature, humidity, and soil moisture
- **Gateway Status**: Backend connectivity, total messages, active nodes, uptime
- **AI Insights**: Status, summary, recommendations, and confidence score with color-coded alerts

### Advanced Features
- **Offline Support**: 
  - Hive-based local caching of sensor data, AI insights, and system status
  - Automatic display of cached data when offline
  - Auto-sync to backend when connection is restored
- **Push Notifications**: 
  - Critical alerts for high temperature, low soil moisture, low battery
  - Warning notifications for AI-detected issues
- **View Modes**: 
  - **AI Mode**: Prominent AI insights with recommendations
  - **Raw Mode**: Detailed sensor data with AI insights at bottom
- **Connectivity Monitoring**: Real-time network status detection
- **Pull-to-Refresh**: Manual refresh gesture support

## Setup

### 1. Install Flutter
Ensure Flutter is installed and configured:
```bash
flutter --version
```

### 2. Install Dependencies
```bash
cd flutter_dashboard
flutter pub get
```

### 3. Configure Backend URL
Edit `lib/services/api_service.dart` and update the `baseUrl`:
```dart
static const String baseUrl = 'http://192.168.8.252:8000';
```

### 4. Run the App
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                      # App entry point with initialization
├── models/
│   └── sensor_data.dart          # Data models (LatestReading, HistoricalReading, SystemStatus, AIInsights)
├── services/
│   ├── api_service.dart         # HTTP API client
│   ├── cache_service.dart       # Hive-based offline caching
│   ├── notification_service.dart # Local push notifications
│   └── connectivity_service.dart # Network connectivity monitoring
├── providers/
│   └── sensor_providers.dart    # Riverpod state management providers
├── screens/
│   └── dashboard_screen.dart    # Main dashboard screen
└── widgets/
    ├── sensor_data_card.dart    # Latest sensor data display
    ├── status_card.dart         # Gateway status display
    ├── ai_insights_card.dart    # AI insights with badges and icons
    ├── history_chart.dart       # Historical trend charts
    └── metric_tabs.dart         # Tab selector for chart metrics
```

## API Endpoints Used

- `GET /api/sensors/latest` - Latest sensor reading
- `GET /api/sensors/history?hours=24` - Historical sensor data (last 24 hours)
- `GET /api/sensors/status` - System status and health
- `GET /api/ai/insights` - AI insights and recommendations

## State Management

The app uses **Riverpod** for state management with the following providers:

- `latestReadingProvider` - Latest sensor reading
- `historyProvider` - Historical sensor data
- `systemStatusProvider` - Gateway/system status
- `aiInsightsProvider` - AI insights and recommendations
- `viewModeProvider` - Toggle between AI and Raw view modes
- `connectivityProvider` - Network connectivity status

## Offline Caching

Data is automatically cached using **Hive**:
- Latest sensor reading
- AI insights
- System status
- Historical data (24 hours)

Cached data is displayed when the backend is unreachable, with an "Offline" indicator.

## Notifications

Local notifications are triggered for:
- **Critical** status: Red alerts with error icon
- **Warning** status: Orange warnings with warning icon

Notifications appear automatically when AI insights detect critical or warning conditions.

## Color Coding

- **Green**: Normal/OK status
- **Yellow/Orange**: Warning status
- **Red**: Critical status

Applied to:
- AI insights status badges
- Temperature, moisture, battery, RSSI values
- Gateway status indicators

## Dependencies

- `flutter_riverpod`: State management
- `hive` / `hive_flutter`: Offline data caching
- `fl_chart`: Historical trend charts
- `flutter_local_notifications`: Push notifications
- `connectivity_plus`: Network connectivity monitoring
- `http`: HTTP API client
- `intl`: Date/time formatting

## Troubleshooting

### Backend Connection Issues
- Verify backend URL in `api_service.dart`
- Check network connectivity
- Ensure backend is running and accessible

### Notifications Not Showing
- Check app notification permissions (Android/iOS)
- Verify notification service initialization in `main.dart`

### Charts Not Displaying
- Ensure backend `/api/sensors/history` endpoint is working
- Check that historical data exists (at least 1 reading)

### Offline Mode
- Cached data is automatically displayed when offline
- Data syncs automatically when connection is restored
- Last sync time is tracked and displayed
