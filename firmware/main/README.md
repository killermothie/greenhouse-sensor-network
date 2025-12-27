# Greenhouse Gateway Firmware

Production-ready ESP32 gateway firmware for a greenhouse wireless sensor network.

## Features

- **Network Management**: Automatic Wi-Fi STA/AP mode switching with fallback
- **Backend Communication**: HTTP POST to backend with automatic retry logic
- **Offline Mode**: Ring buffer for data storage when offline
- **Local REST API**: Status and sensor data endpoints when offline
- **Sensor Simulation**: Realistic greenhouse sensor data generation
- **OLED Display**: Real-time status display on SSD1306

## Hardware Requirements

- ESP32 development board
- SSD1306 OLED display (128x64, I2C)
- I2C connections: SDA, SCL, VCC, GND

## Software Requirements

### Arduino IDE / PlatformIO

Required libraries:
- `WiFi` (ESP32 built-in)
- `HTTPClient` (ESP32 built-in)
- `WebServer` (ESP32 built-in)
- `ArduinoJson` (install via Library Manager)
- `Adafruit_SSD1306` (install via Library Manager)
- `Adafruit_GFX` (install via Library Manager)

### PlatformIO Configuration

If using PlatformIO, create `platformio.ini`:

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200

lib_deps = 
    adafruit/Adafruit GFX Library
    adafruit/Adafruit SSD1306
    bblanchon/ArduinoJson
```

## Configuration

### Wi-Fi Credentials

Edit `main.ino` and set your Wi-Fi credentials:

```cpp
networkManager.setCredentials("YourWiFiSSID", "YourWiFiPassword");
```

If no credentials are set or connection fails, the gateway will start in AP mode:
- SSID: `Greenhouse-Gateway`
- Password: `12345678`

### Backend URL

Edit `main.ino` and set your backend URL:

```cpp
const char* BACKEND_URL = "http://192.168.1.100:8000";
```

## Project Structure

```
firmware/
├── main.ino                 # Main application entry point
├── network_manager.h/cpp    # Wi-Fi STA/AP management
├── backend_client.h/cpp     # HTTP backend communication
├── sensor_simulator.h/cpp   # Simulated sensor data generation
├── oled_display.h/cpp       # SSD1306 display management
├── state_manager.h/cpp      # Ring buffer and state management
└── README.md               # This file
```

## API Endpoints

### Backend Endpoint

**POST** `/api/sensors/data`

Request body:
```json
{
  "nodeId": "gateway-01",
  "temperature": 25.5,
  "humidity": 65.0,
  "soilMoisture": 45.0,
  "batteryLevel": 85,
  "rssi": -65,
  "timestamp": 1234567890
}
```

### Local REST API (Offline Mode)

**GET** `/status`

Response:
```json
{
  "status": "online",
  "network_mode": "ONLINE",
  "backend_reachable": true,
  "buffer_count": 5,
  "buffer_full": false,
  "uptime_ms": 123456
}
```

**GET** `/sensors/latest`

Response:
```json
{
  "nodeId": "gateway-01",
  "temperature": 25.5,
  "humidity": 65.0,
  "soilMoisture": 45.0,
  "batteryLevel": 85,
  "rssi": -65,
  "timestamp": 1234567890,
  "age_seconds": 10
}
```

## Operation Modes

### Online Mode
- Connected to Wi-Fi (STA mode)
- Internet connectivity available
- Backend is reachable
- Data sent directly to backend
- Buffered data synced periodically

### Offline Mode
- No internet or backend unreachable
- Data stored in ring buffer (100 entries)
- Local REST API available
- Automatic sync when connection restored

### AP Mode
- Wi-Fi connection failed
- Gateway creates access point
- Can still attempt STA connection in background
- Local REST API available

## Sensor Data Simulation

The simulator generates realistic greenhouse data:
- Temperature: 18-32°C
- Humidity: 40-85%
- Soil Moisture: 20-80%
- Battery Level: 20-100%
- RSSI: -90 to -40 dBm

Data updates every 10 seconds with gradual variations for realism.

## Future Enhancements

- ESP-NOW or LoRa integration for sensor nodes
- EEPROM/SPIFFS for credential storage
- Web configuration interface
- OTA updates
- MQTT support
- More sensor types

## Troubleshooting

### OLED Display Not Working
- Check I2C connections (SDA, SCL)
- Verify I2C address (default: 0x3C)
- Check power supply

### Wi-Fi Connection Issues
- Verify SSID and password
- Check signal strength
- Gateway will fall back to AP mode automatically

### Backend Connection Failed
- Verify backend URL is correct
- Check backend server is running
- Verify network connectivity
- Data will be buffered for later sync

## License

This firmware is designed for greenhouse monitoring applications.

