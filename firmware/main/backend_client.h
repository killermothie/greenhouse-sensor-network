#ifndef BACKEND_CLIENT_H
#define BACKEND_CLIENT_H

#include <Arduino.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

/**
 * Backend Client
 * Handles HTTP communication with the backend server
 * Implements retry logic for failed requests
 */
class BackendClient {
public:
  BackendClient();
  void begin(const char* backendUrl);
  
  // Send sensor data to backend
  bool sendSensorData(const char* nodeId, float temperature, float humidity, 
                     float soilMoisture, int batteryLevel, int rssi, 
                     unsigned long timestamp);
  
  // Send gateway status to backend (active node count, etc.)
  bool sendGatewayStatus(const char* gatewayId, int activeNodeCount, 
                        const char* networkMode, bool backendReachable);
  
  bool isBackendReachable() const { return backendReachable; }
  void checkBackendConnectivity();
  
private:
  static const int MAX_RETRIES = 3;
  static const unsigned long RETRY_DELAY = 200; // 200ms - non-blocking retry delay
  static const unsigned long CONNECTIVITY_CHECK_INTERVAL = 5000; // 5 seconds - check more frequently
  static const unsigned long HEALTH_CHECK_TIMEOUT = 3000; // 3 seconds timeout for health checks
  
  String backendUrl;
  bool backendReachable;
  unsigned long lastConnectivityCheck;
  HTTPClient http;
  
  bool performRequest(const String& payload);
};

#endif // BACKEND_CLIENT_H

