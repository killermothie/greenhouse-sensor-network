# Flutter UI/UX Improvements

## Status Banners

A new `StatusBanner` widget has been created (`lib/widgets/status_banner.dart`) for displaying system-wide alerts and status messages.

### Usage Example

```dart
// In dashboard_screen.dart
StatusBanner(
  level: StatusLevel.warning,
  message: "Low soil moisture detected. Irrigation recommended.",
  icon: Icons.water_drop,
)

StatusBanner(
  level: StatusLevel.error,
  message: "Sensor offline: node-01",
  icon: Icons.error,
  onDismiss: () {
    // Handle dismiss
  },
)
```

### Status Levels
- **Success** (Green): All systems normal
- **Warning** (Orange): Issues detected, attention needed
- **Error** (Red): Critical issues
- **Info** (Blue): Informational messages

## Icon Improvements

### Recommended Icons (Material Design)

#### Sensor Metrics
- **Temperature**: `Icons.thermostat`
- **Humidity**: `Icons.water_drop`
- **Soil Moisture**: `Icons.eco` or `Icons.grass`
- **Light Level**: `Icons.light_mode` or `Icons.wb_sunny`

#### Status Indicators
- **Online**: `Icons.cloud_done` or `Icons.check_circle`
- **Offline**: `Icons.cloud_off` or `Icons.error`
- **Warning**: `Icons.warning` or `Icons.error_outline`
- **Info**: `Icons.info` or `Icons.info_outline`

#### Battery
- **Full**: `Icons.battery_full` or `Icons.battery_charging_full`
- **Medium**: `Icons.battery_5_bar` or `Icons.battery_4_bar`
- **Low**: `Icons.battery_1_bar` or `Icons.battery_alert`

#### Connectivity
- **WiFi Strong**: `Icons.wifi` or `Icons.signal_wifi_4_bar`
- **WiFi Weak**: `Icons.signal_wifi_2_bar` or `Icons.signal_wifi_1_bar`
- **WiFi Off**: `Icons.wifi_off` or `Icons.signal_wifi_off`
- **RSSI**: `Icons.signal_cellular_alt`

#### Actions
- **Refresh**: `Icons.refresh` or `Icons.update`
- **Settings**: `Icons.settings` or `Icons.tune`
- **History**: `Icons.history` or `Icons.timeline`
- **Insights**: `Icons.psychology` or `Icons.insights`

## UI Component Suggestions

### 1. Enhanced Status Card
Already implemented with connection state indicators. Consider adding:
- Battery status icon
- Last update indicator (spinning icon when refreshing)
- Quick action buttons

### 2. Metric Cards with Icons
The `SensorDataCard` already includes icons. Enhancements:
- Larger, more prominent icons
- Color-coded values based on thresholds
- Trend indicators (↑ ↓ →)
- Comparison with optimal ranges

### 3. Risk Level Indicators
For AI insights:
```dart
Widget buildRiskIndicator(String riskLevel) {
  Color color;
  IconData icon;
  
  switch (riskLevel) {
    case 'HIGH':
      color = Colors.red;
      icon = Icons.priority_high;
      break;
    case 'MEDIUM':
      color = Colors.orange;
      icon = Icons.warning;
      break;
    case 'LOW':
      color = Colors.green;
      icon = Icons.check_circle;
      break;
  }
  
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        SizedBox(width: 4),
        Text(
          riskLevel,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
```

### 4. Loading States
Add loading indicators:
```dart
if (isLoading)
  Center(child: CircularProgressIndicator())
else
  // Content
```

### 5. Empty States
Add empty state messages:
```dart
if (readings.isEmpty)
  Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inbox, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text(
          'No sensor data available',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    ),
  )
```

### 6. Refresh Indicators
Show refresh status:
```dart
AppBar(
  actions: [
    if (isRefreshing)
      Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      )
    else
      IconButton(
        icon: Icon(Icons.refresh),
        onPressed: _refreshAll,
      ),
  ],
)
```

## Color Coding Standards

### Temperature
- **< 18°C**: Blue (cold)
- **18-28°C**: Green (optimal)
- **28-35°C**: Orange (warm)
- **> 35°C**: Red (hot)

### Soil Moisture
- **< 30%**: Red (dry)
- **30-70%**: Green (optimal)
- **> 70%**: Orange (wet)

### Battery
- **< 20%**: Red (critical)
- **20-50%**: Orange (low)
- **> 50%**: Green (good)

### RSSI
- **> -50 dBm**: Green (excellent)
- **-50 to -70 dBm**: Orange (good)
- **< -70 dBm**: Red (poor)

### Risk Levels
- **HIGH**: Red
- **MEDIUM**: Orange
- **LOW**: Green

## Suggested Layout Improvements

### Dashboard Layout
1. **Top Banner**: System status (online/offline, alerts)
2. **Quick Stats**: Cards with key metrics
3. **Latest Reading**: Detailed sensor data card
4. **AI Insights**: Risk indicators and recommendations
5. **History Chart**: Trend visualization
6. **Settings**: Access to configuration

### Card Design
- Consistent padding: `EdgeInsets.all(16)`
- Elevation: 2-4 for cards
- Border radius: 8-12px
- Spacing between cards: 16px

### Typography
- **Headings**: Bold, 18-24px
- **Body**: Regular, 14-16px
- **Labels**: Medium weight, 12-14px
- **Values**: Bold, 16-20px

## Implementation Checklist

- [x] Status banner widget created
- [ ] Status banners integrated into dashboard
- [ ] Icons updated across all cards
- [ ] Risk level indicators added to AI insights
- [ ] Loading states added
- [ ] Empty states added
- [ ] Refresh indicators added
- [ ] Color coding standardized
- [ ] Typography consistent
- [ ] Accessibility labels added (for screen readers)

## Future Enhancements

1. **Dark Mode**: Support for dark theme
2. **Animations**: Smooth transitions between states
3. **Gestures**: Swipe to refresh, pull to reload
4. **Notifications**: Push notifications for critical alerts
5. **Charts**: Interactive charts with zoom/pan
6. **Filters**: Filter by node, date range, etc.
7. **Export**: Export data to CSV/JSON
8. **Settings**: User preferences and configuration

