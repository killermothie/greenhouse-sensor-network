/**
 * Greenhouse Gateway Firmware
 * ESP32-based gateway for wireless sensor network
 * 
 * Features:
 * - Wi-Fi STA/AP mode switching
 * - Backend HTTP communication
 * - Offline data buffering
 * - Local REST API
 * - OLED status display
 * - Sensor data simulation
 */

#include "network_manager.h"
#include "backend_client.h"
#include "sensor_simulator.h"
#include "oled_display.h"
#include "state_manager.h"
#include "espnow_receiver.h"
#include "lora_receiver.h"
#include <WebServer.h>
#include <ArduinoJson.h>
#include <Wire.h>

// Configuration
const char* BACKEND_URL = "http://192.168.8.253:8000"; // Change to your backend URL
const char* NODE_ID = "gateway-01";
const unsigned long SENSOR_UPDATE_INTERVAL = 10000; // 10 seconds
const unsigned long SYNC_INTERVAL = 5000; // Sync buffered data every 5 seconds
const unsigned long GATEWAY_STATUS_INTERVAL = 30000; // Send gateway status every 30 seconds

// Component instances
GatewayNetworkManager networkManager;
BackendClient backendClient;
SensorSimulator sensorSimulator;
OLEDDisplay oledDisplay;
StateManager stateManager;
ESPNowReceiver espNowReceiver;
LoRaReceiver loraReceiver;

// Web server for local REST API
WebServer server(80);

// Timing
unsigned long lastSensorUpdate = 0;
unsigned long lastSyncAttempt = 0;
unsigned long lastGatewayStatusUpdate = 0;

// Forward declarations
void processReceivedSensorData(const SensorSimulator::SensorData& data, const char* nodeId);

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== Greenhouse Gateway Starting ===");
  
  // Initialize I2C for OLED display (default pins: SDA=21, SCL=22 on ESP32)
  Wire.begin();
  
  // Initialize OLED display
  if (!oledDisplay.begin()) {
    Serial.println("Warning: OLED display initialization failed");
  }
  
  // Initialize sensor simulator
  sensorSimulator.begin();
  
  // Initialize network manager
  // TODO: Load Wi-Fi credentials from EEPROM/SPIFFS in production
  // For now, set credentials here or use AP mode
  networkManager.setCredentials("OKC", "vwiuken7");
  networkManager.begin();
  
  // Initialize backend client
  backendClient.begin(BACKEND_URL);
  
  // Initialize ESP-NOW receiver
  if (espNowReceiver.begin()) {
    Serial.println("ESP-NOW receiver started");
    // Set callback for received ESP-NOW data
    espNowReceiver.setDataCallback([](const ESPNowReceiver::SensorMessage& msg) {
      // Convert ESP-NOW message to SensorData format
      SensorSimulator::SensorData data;
      data.temperature = msg.temperature;
      data.humidity = msg.humidity;
      data.soilMoisture = msg.soilMoisture;
      data.batteryLevel = msg.batteryLevel;
      data.rssi = msg.rssi;
      data.timestamp = msg.timestamp > 0 ? msg.timestamp : millis();
      
      // Process the received data
      processReceivedSensorData(data, msg.nodeId);
    });
  } else {
    Serial.println("ESP-NOW initialization failed - continuing without it");
  }
  
  // Initialize LoRa receiver
  if (loraReceiver.begin()) {
    Serial.println("LoRa receiver started");
    // Set callback for received LoRa data
    loraReceiver.setDataCallback([](const LoRaReceiver::SensorMessage& msg) {
      // Convert LoRa message to SensorData format (same as ESP-NOW)
      SensorSimulator::SensorData data;
      data.temperature = msg.temperature;
      data.humidity = msg.humidity;
      data.soilMoisture = msg.soilMoisture;
      data.batteryLevel = msg.batteryLevel;
      data.rssi = msg.rssi;
      data.timestamp = msg.timestamp > 0 ? msg.timestamp : millis();
      
      // Process the received data (treat LoRa data exactly like ESP-NOW data)
      processReceivedSensorData(data, msg.nodeId);
    });
  } else {
    Serial.println("LoRa initialization failed - continuing without it");
  }
  
  // Setup local REST API endpoints
  setupLocalAPI();
  
  // Clear any gateway entries that might have been added before the fix
  // This ensures gateway is never counted as a node
  stateManager.clearGatewayEntries();
  
  Serial.println("Gateway initialized");
  oledDisplay.update("INIT", "Starting...", false, 0);
}

void loop() {
  unsigned long currentTime = millis();
  
  // Update network manager (handles connection state - fast, non-blocking)
  networkManager.update();
  
  // Process ESP-NOW received data (non-blocking)
  espNowReceiver.processReceivedData();
  
  // Process LoRa received data (non-blocking)
  loraReceiver.processReceivedData();
  
  // Update backend connectivity check (check whenever we have any network connection)
  if (networkManager.isOnline() || networkManager.getNetworkModeString() == "AP") {
    backendClient.checkBackendConnectivity();
  }
  
  // Generate and process simulated sensor data (for testing)
  // Only generate if no real nodes are connected (to avoid counting gateway as a node)
  // Check if we have any real nodes (non-gateway nodes) in the buffer
  int realNodeCount = stateManager.getNodeCount(); // This excludes gateway
  if (realNodeCount == 0 && currentTime - lastSensorUpdate >= SENSOR_UPDATE_INTERVAL) {
    // Only generate simulated data if no real nodes are connected
    lastSensorUpdate = currentTime;
    processSensorData();
  } else if (realNodeCount > 0) {
    // Reset lastSensorUpdate to prevent generating when real nodes exist
    lastSensorUpdate = currentTime;
  }
  
  // Sync buffered data when online and backend is reachable
  if (networkManager.isOnline() && backendClient.isBackendReachable()) {
    if (currentTime - lastSyncAttempt >= SYNC_INTERVAL) {
      lastSyncAttempt = currentTime;
      syncBufferedData();
    }
    
    // Send gateway status periodically when connected to backend
    if (currentTime - lastGatewayStatusUpdate >= GATEWAY_STATUS_INTERVAL) {
      lastGatewayStatusUpdate = currentTime;
      int activeNodeCount = stateManager.getActiveNodeCount(300000); // Active in last 5 minutes
      String networkMode = networkManager.getNetworkModeString();
      backendClient.sendGatewayStatus(
        NODE_ID,
        activeNodeCount,
        networkMode.c_str(),
        backendClient.isBackendReachable()
      );
    }
  }
  
  // Handle local API requests
  server.handleClient();
  
  // Update OLED display (real-time status)
  updateDisplay();
  
  // Small delay to prevent watchdog issues
  delay(10);
}

void processSensorData() {
  // Generate simulated sensor data (for testing when no ESP-NOW nodes are present)
  SensorSimulator::SensorData data = sensorSimulator.generateData(NODE_ID);
  processReceivedSensorData(data, NODE_ID);
}

void processReceivedSensorData(const SensorSimulator::SensorData& data, const char* nodeId) {
  // Always add to buffer first to track nodes (even if we send to backend)
  // This ensures active node count is always accurate
  stateManager.addSensorData(data, nodeId);
  
  // Try to send to backend if online and backend is reachable
  bool sent = false;
  if (networkManager.isOnline() && backendClient.isBackendReachable()) {
    sent = backendClient.sendSensorData(
      nodeId,
      data.temperature,
      data.humidity,
      data.soilMoisture,
      data.batteryLevel,
      data.rssi,
      data.timestamp
    );
  }
  
  if (!sent) {
    Serial.println("Data buffered (offline mode)");
  } else {
    Serial.println("Data sent to backend successfully (also tracked in buffer)");
  }
}

void syncBufferedData() {
  if (stateManager.getBufferCount() == 0) {
    return; // Nothing to sync
  }
  
  Serial.println("Syncing buffered data...");
  int syncedCount = 0;
  
  // Try to sync up to 5 items per sync cycle to avoid blocking
  for (int i = 0; i < 5; i++) {
    SensorSimulator::SensorData data;
    String nodeId;
    int bufferIndex;
    
    if (!stateManager.getNextBufferedData(data, nodeId, bufferIndex)) {
      break; // No more data to sync
    }
    
    bool success = backendClient.sendSensorData(
      nodeId.c_str(),
      data.temperature,
      data.humidity,
      data.soilMoisture,
      data.batteryLevel,
      data.rssi,
      data.timestamp
    );
    
    if (success) {
      stateManager.markDataAsSynced(bufferIndex);
      syncedCount++;
      Serial.print("Synced data from ");
      Serial.print((millis() - data.timestamp) / 1000);
      Serial.println(" seconds ago");
    } else {
      // Stop syncing if backend becomes unreachable
      break;
    }
  }
  
  if (syncedCount > 0) {
    Serial.print("Synced ");
    Serial.print(syncedCount);
    Serial.println(" buffered data entries");
  }
}

void setupLocalAPI() {
  // GET /status
  server.on("/status", HTTP_GET, []() {
    StaticJsonDocument<256> doc;
    doc["status"] = "online";
    doc["network_mode"] = networkManager.isOnline() ? "ONLINE" : "OFFLINE";
    doc["backend_reachable"] = backendClient.isBackendReachable();
    doc["buffer_count"] = stateManager.getBufferCount();
    doc["buffer_full"] = stateManager.isBufferFull();
    doc["uptime_ms"] = millis();
    
    String response;
    serializeJson(doc, response);
    
    server.send(200, "application/json", response);
  });
  
  // GET /sensors/latest
  server.on("/sensors/latest", HTTP_GET, []() {
    SensorSimulator::SensorData latest = stateManager.getLatestData();
    
    if (latest.timestamp == 0) {
      server.send(404, "application/json", "{\"error\":\"No sensor data available\"}");
      return;
    }
    
    StaticJsonDocument<512> doc;
    doc["nodeId"] = NODE_ID;
    doc["temperature"] = latest.temperature;
    doc["humidity"] = latest.humidity;
    doc["soilMoisture"] = latest.soilMoisture;
    doc["batteryLevel"] = latest.batteryLevel;
    doc["rssi"] = latest.rssi;
    doc["timestamp"] = latest.timestamp;
    doc["age_seconds"] = (millis() - latest.timestamp) / 1000;
    
    String response;
    serializeJson(doc, response);
    
    server.send(200, "application/json", response);
  });
  
  // GET /nodes
  server.on("/nodes", HTTP_GET, []() {
    StaticJsonDocument<256> doc;
    doc["node_count"] = stateManager.getNodeCount();
    doc["active_nodes"] = stateManager.getActiveNodeCount(300000); // Active in last 5 minutes
    doc["buffer_count"] = stateManager.getBufferCount();
    doc["espnow_received"] = espNowReceiver.getReceivedCount();
    doc["lora_received"] = loraReceiver.getReceivedCount();
    
    String response;
    serializeJson(doc, response);
    server.send(200, "application/json", response);
  });
  
  // GET /api/system/network
  server.on("/api/system/network", HTTP_GET, []() {
    StaticJsonDocument<512> doc;
    
    // Get current WiFi mode
    wifi_mode_t wifiMode = WiFi.getMode();
    bool isAPMode = (wifiMode == WIFI_AP || wifiMode == WIFI_AP_STA);
    bool isSTAMode = (wifiMode == WIFI_STA || wifiMode == WIFI_AP_STA);
    
    // Check if STA is connected
    bool staConnected = (isSTAMode && WiFi.status() == WL_CONNECTED);
    
    // Check if AP is active (AP mode or AP_STA mode with AP active)
    IPAddress apIPCheck = WiFi.softAPIP();
    bool apActive = (wifiMode == WIFI_AP) || (wifiMode == WIFI_AP_STA && apIPCheck != IPAddress(0, 0, 0, 0));
    
    if (staConnected) {
      // STA mode - connected to router
      doc["mode"] = "STA";
      
      // Get STA IP address
      IPAddress staIP = WiFi.localIP();
      if (staIP != IPAddress(0, 0, 0, 0)) {
        doc["ip"] = staIP.toString();
      } else {
        doc["ip"] = "0.0.0.0";
      }
      
      // Get connected SSID
      String ssid = WiFi.SSID();
      if (ssid.length() == 0) {
        ssid = networkManager.getSSID();
      }
      if (ssid.length() > 0 && ssid != "N/A") {
        doc["ssid"] = ssid;
      } else {
        doc["ssid"] = "Not connected";
      }
      
      // Get gateway IP
      IPAddress gatewayIP = WiFi.gatewayIP();
      if (gatewayIP != IPAddress(0, 0, 0, 0)) {
        doc["gateway"] = gatewayIP.toString();
      } else {
        doc["gateway"] = "0.0.0.0";
      }
    } else if (apActive) {
      // AP mode - access point active
      doc["mode"] = "AP";
      
      // Get AP IP address
      IPAddress apIP = WiFi.softAPIP();
      if (apIP != IPAddress(0, 0, 0, 0)) {
        doc["ip"] = apIP.toString();
      } else {
        doc["ip"] = "192.168.4.1"; // Default AP IP
      }
      
      // Get AP SSID using networkManager method
      String apSSID = networkManager.getSSID();
      if (apSSID.length() > 0 && apSSID != "N/A") {
        doc["ssid"] = apSSID;
      } else {
        doc["ssid"] = "Greenhouse-Gateway"; // Fallback to known AP SSID
      }
      
      // Get number of connected clients
      doc["clients"] = WiFi.softAPgetStationNum();
    } else {
      // Not connected or initializing
      doc["mode"] = "OFFLINE";
      doc["ip"] = "0.0.0.0";
      doc["ssid"] = "Not connected";
    }
    
    String response;
    serializeJson(doc, response);
    server.send(200, "application/json", response);
  });
  
  // 404 handler
  server.onNotFound([]() {
    server.send(404, "application/json", "{\"error\":\"Endpoint not found\"}");
  });
  
  server.begin();
  Serial.println("Local REST API server started on port 80");
}

void updateDisplay() {
  // Get network mode string (ONLINE/OFFLINE/AP)
  String networkModeStr = networkManager.getNetworkModeString();
  String ssid = networkManager.getSSID();
  bool backendConnected = backendClient.isBackendReachable();
  
  SensorSimulator::SensorData latest = stateManager.getLatestData();
  unsigned long lastUpdate = latest.timestamp;
  
  // Get LoRa node info if available and still active
  String loraNodeId = loraReceiver.getLastNodeId();
  int loraRSSI = loraReceiver.getLastRSSI();
  bool loraNodeActive = loraReceiver.isNodeActive(25000); // 25 second timeout (node sends every 5s)
  
  // Static variable to track previous active state for logging
  static bool prevLoraNodeActive = false;
  static String prevLoraNodeId = "";
  
  // Log when node becomes inactive
  if (prevLoraNodeActive && !loraNodeActive && loraNodeId.length() > 0) {
    Serial.print("LoRa node ");
    Serial.print(loraNodeId);
    Serial.println(" DISCONNECTED (timeout)");
  }
  
  // Log when node becomes active
  if (!prevLoraNodeActive && loraNodeActive && loraNodeId.length() > 0) {
    Serial.print("LoRa node ");
    Serial.print(loraNodeId);
    Serial.println(" CONNECTED");
  }
  
  prevLoraNodeActive = loraNodeActive;
  prevLoraNodeId = loraNodeId;
  
  // Update OLED display with LoRa node info only if node is still active
  if (loraNodeId.length() > 0 && loraNodeActive) {
    oledDisplay.update(
      networkModeStr.c_str(), 
      ssid.c_str(), 
      backendConnected, 
      lastUpdate,
      loraNodeId.c_str(),
      loraRSSI
    );
  } else {
    // Use original update method when no LoRa node connected or node is inactive
    oledDisplay.update(
      networkModeStr.c_str(), 
      ssid.c_str(), 
      backendConnected, 
      lastUpdate
    );
  }
}

