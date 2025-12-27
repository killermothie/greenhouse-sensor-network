#include "backend_client.h"
#include <Arduino.h>

BackendClient::BackendClient() 
  : backendReachable(false), 
    lastConnectivityCheck(0) {
}

void BackendClient::begin(const char* backendUrl) {
  this->backendUrl = String(backendUrl);
  checkBackendConnectivity();
}

bool BackendClient::sendSensorData(const char* nodeId, float temperature, 
                                   float humidity, float soilMoisture, 
                                   int batteryLevel, int rssi, 
                                   unsigned long timestamp) {
  // Create JSON payload
  StaticJsonDocument<512> doc;
  doc["nodeId"] = nodeId;
  doc["temperature"] = temperature;
  doc["humidity"] = humidity;
  doc["soilMoisture"] = soilMoisture;
  doc["batteryLevel"] = batteryLevel;
  doc["rssi"] = rssi;
  doc["timestamp"] = timestamp;
  
  String payload;
  serializeJson(doc, payload);
  
  Serial.print("[BACKEND] Sending sensor data to backend: ");
  Serial.println(payload);
  
  // Retry logic with non-blocking delays
  for (int attempt = 0; attempt < MAX_RETRIES; attempt++) {
    if (performRequest(payload)) {
      backendReachable = true;
      Serial.println("[BACKEND] Data sent successfully");
      return true;
    }
    
    if (attempt < MAX_RETRIES - 1) {
      Serial.print("[BACKEND] Retry attempt ");
      Serial.print(attempt + 2);
      Serial.print(" of ");
      Serial.print(MAX_RETRIES);
      Serial.print(" (non-blocking delay: ");
      Serial.print(RETRY_DELAY);
      Serial.println("ms)");
      delay(RETRY_DELAY); // Non-blocking delay (200ms max)
    }
  }
  
  backendReachable = false;
  Serial.println("[BACKEND] Failed to send data after all retries");
  return false;
}

bool BackendClient::performRequest(const String& payload) {
  String endpoint = backendUrl + "/api/sensors/data";
  
  http.begin(endpoint);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(5000); // 5 second timeout (reduced for faster failure detection)
  
  unsigned long startTime = millis();
  int httpResponseCode = http.POST(payload);
  unsigned long elapsed = millis() - startTime;
  
  bool success = (httpResponseCode > 0 && httpResponseCode < 400);
  
  if (success) {
    Serial.print("[BACKEND] HTTP ");
    Serial.print(httpResponseCode);
    Serial.print(" (");
    Serial.print(elapsed);
    Serial.println("ms)");
    String response = http.getString();
    if (response.length() < 200) { // Only log short responses
      Serial.print("[BACKEND] Response: ");
      Serial.println(response);
    }
  } else {
    Serial.print("[BACKEND] Error code: ");
    Serial.print(httpResponseCode);
    Serial.print(" (");
    Serial.print(elapsed);
    Serial.println("ms)");
    if (httpResponseCode == 0) {
      Serial.println("[BACKEND] Connection failed - backend unreachable or timeout");
    } else if (httpResponseCode >= 400) {
      Serial.print("[BACKEND] HTTP error: ");
      Serial.println(httpResponseCode);
    }
  }
  
  http.end();
  return success;
}

void BackendClient::checkBackendConnectivity() {
  unsigned long currentTime = millis();
  if (currentTime - lastConnectivityCheck < CONNECTIVITY_CHECK_INTERVAL) {
    return;
  }
  
  lastConnectivityCheck = currentTime;
  
  // Use the /health endpoint which is simpler and faster
  HTTPClient testClient;
  String testUrl = backendUrl + "/health";
  
  Serial.print("[BACKEND] Health check: ");
  Serial.println(testUrl);
  
  testClient.begin(testUrl);
  testClient.setTimeout(HEALTH_CHECK_TIMEOUT); // 3 second timeout
  
  unsigned long startTime = millis();
  // Try a GET request to /health endpoint
  int responseCode = testClient.GET();
  unsigned long elapsed = millis() - startTime;
  
  backendReachable = (responseCode == 200);
  
  if (responseCode > 0) {
    Serial.print("[BACKEND] Health check: HTTP ");
    Serial.print(responseCode);
    Serial.print(" (");
    Serial.print(elapsed);
    Serial.print("ms) - ");
    Serial.println(backendReachable ? "ONLINE" : "OFFLINE");
    if (responseCode == 200) {
      String response = testClient.getString();
      if (response.length() < 100) { // Only log short responses
        Serial.print("[BACKEND] Health response: ");
        Serial.println(response);
      }
    }
  } else {
    Serial.print("[BACKEND] Health check: OFFLINE (error: ");
    Serial.print(responseCode);
    Serial.print(", elapsed: ");
    Serial.print(elapsed);
    Serial.print("ms, timeout: ");
    Serial.print(HEALTH_CHECK_TIMEOUT);
    Serial.println("ms)");
    backendReachable = false;
  }
  
  testClient.end();
}

bool BackendClient::sendGatewayStatus(const char* gatewayId, int activeNodeCount, 
                                     const char* networkMode, bool backendReachable) {
  // Create JSON payload
  StaticJsonDocument<256> doc;
  doc["gatewayId"] = gatewayId;
  doc["activeNodeCount"] = activeNodeCount;
  doc["networkMode"] = networkMode;
  doc["backendReachable"] = backendReachable;
  doc["timestamp"] = millis();
  
  String payload;
  serializeJson(doc, payload);
  
  Serial.print("[BACKEND] Sending gateway status: ");
  Serial.println(payload);
  
  // Retry logic with non-blocking delays
  for (int attempt = 0; attempt < MAX_RETRIES; attempt++) {
    String endpoint = backendUrl + "/api/gateway/status";
    
    http.begin(endpoint);
    http.addHeader("Content-Type", "application/json");
    http.setTimeout(5000);
    
    unsigned long startTime = millis();
    int httpResponseCode = http.POST(payload);
    unsigned long elapsed = millis() - startTime;
    
    bool success = (httpResponseCode > 0 && httpResponseCode < 400);
    
    if (success) {
      Serial.print("[BACKEND] Gateway status sent successfully: HTTP ");
      Serial.print(httpResponseCode);
      Serial.print(" (");
      Serial.print(elapsed);
      Serial.println("ms)");
      http.end();
      return true;
    } else {
      Serial.print("[BACKEND] Failed to send gateway status: HTTP ");
      Serial.print(httpResponseCode);
      Serial.print(" (");
      Serial.print(elapsed);
      Serial.println("ms)");
      http.end();
    }
    
    if (attempt < MAX_RETRIES - 1) {
      delay(RETRY_DELAY);
    }
  }
  
  Serial.println("[BACKEND] Failed to send gateway status after all retries");
  return false;
}

