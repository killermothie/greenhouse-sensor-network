#include "network_manager.h"

const char* GatewayNetworkManager::AP_SSID = "Greenhouse-Gateway";
const char* GatewayNetworkManager::AP_PASSWORD = "12345678";

GatewayNetworkManager::GatewayNetworkManager() 
  : currentState(INIT), 
    lastKnownMode(INIT),
    internetAvailable(false),
    staConnectStartTime(0),
    lastInternetCheck(0),
    lastSTARetryAttempt(0),
    lastStateTransitionTime(0),
    staConnectionInProgress(false) {
}

void GatewayNetworkManager::begin() {
  Serial.println("\n[NETWORK] === Network Manager Starting ===");
  transitionToState(INIT, "Initialization");
  
  // Restore last known mode if available (from memory)
  if (lastKnownMode != INIT && lastKnownMode != AP_MODE) {
    Serial.print("[NETWORK] Restoring last known mode: ");
    Serial.println(lastKnownMode == ONLINE ? "ONLINE" : "STA_CONNECTING");
  }
  
  WiFi.mode(WIFI_STA);
  transitionToState(STA_CONNECTING, "Starting STA connection");
  staConnectStartTime = millis();
  staConnectionInProgress = true;
  attemptSTAConnection();
}

void GatewayNetworkManager::update() {
  unsigned long currentTime = millis();
  
  // Non-blocking state machine - no delays > 200ms
  switch (currentState) {
    case INIT:
      // Should not stay in INIT after begin() is called
      break;
      
    case STA_CONNECTING:
      {
        wl_status_t wifiStatus = WiFi.status();
        
        // Check for successful connection
        if (wifiStatus == WL_CONNECTED) {
          // Ensure we're in pure STA mode (not AP_STA)
          if (WiFi.getMode() != WIFI_STA) {
            WiFi.mode(WIFI_STA);
            WiFi.softAPdisconnect(true);
            clearSSID();
          }
          
          String currentSSID = WiFi.SSID();
          if (currentSSID != lastSSID) {
            lastSSID = currentSSID;
            Serial.print("[NETWORK] Connected to SSID: ");
            Serial.println(currentSSID);
          }
          
          transitionToState(ONLINE, "STA connection successful");
          staConnectionInProgress = false;
          Serial.print("[NETWORK] IP address: ");
          Serial.println(WiFi.localIP());
          
          // Check internet immediately after connection (non-blocking)
          checkInternetConnectivity();
        } 
        // Fast timeout: max 10 seconds
        else if (currentTime - staConnectStartTime > STA_CONNECT_TIMEOUT) {
          Serial.print("[NETWORK] STA connection timeout after ");
          Serial.print((currentTime - staConnectStartTime) / 1000);
          Serial.println(" seconds - switching to AP mode");
          startAPMode();
          staConnectionInProgress = false;
        }
        // Non-blocking status check - log progress every 2 seconds
        else if ((currentTime - staConnectStartTime) % 2000 < 50) {
          Serial.print("[NETWORK] STA connecting... Status: ");
          Serial.print(wifiStatus);
          Serial.print(" (elapsed: ");
          Serial.print((currentTime - staConnectStartTime) / 1000);
          Serial.println("s)");
        }
      }
      break;
      
    case ONLINE:
      {
        // Check WiFi connection status (non-blocking)
        if (WiFi.status() != WL_CONNECTED) {
          Serial.println("[NETWORK] WiFi connection lost while ONLINE");
          transitionToState(AP_MODE, "WiFi connection lost");
          startAPMode();
          break;
        }
        
        // Periodic internet connectivity check (non-blocking)
        if (currentTime - lastInternetCheck > INTERNET_CHECK_INTERVAL) {
          checkInternetConnectivity();
        }
      }
      break;
      
    case AP_MODE:
      {
        // Non-blocking STA retry from AP mode
        if (staSSID.length() > 0 && !staConnectionInProgress) {
          if (currentTime - lastSTARetryAttempt > STA_RETRY_INTERVAL) {
            lastSTARetryAttempt = currentTime;
            Serial.println("[NETWORK] Retrying STA connection from AP mode...");
            WiFi.mode(WIFI_AP_STA);
            WiFi.begin(staSSID.c_str(), staPassword.c_str());
            staConnectStartTime = currentTime;
            staConnectionInProgress = true;
          }
        }
        
        // Check if STA connection succeeded while in AP mode (non-blocking)
        if (staConnectionInProgress) {
          if (WiFi.status() == WL_CONNECTED) {
            Serial.println("[NETWORK] STA connected from AP mode - switching to pure STA");
            WiFi.mode(WIFI_STA);
            WiFi.softAPdisconnect(true);
            clearSSID();
            transitionToState(ONLINE, "STA reconnected from AP mode");
            staConnectionInProgress = false;
            Serial.print("[NETWORK] STA IP address: ");
            Serial.println(WiFi.localIP());
            checkInternetConnectivity();
          } else if (currentTime - staConnectStartTime > STA_CONNECT_TIMEOUT) {
            Serial.println("[NETWORK] STA retry timeout - staying in AP mode");
            staConnectionInProgress = false;
          }
        }
      }
      break;
  }
}

void GatewayNetworkManager::attemptSTAConnection() {
  if (staSSID.length() == 0) {
    Serial.println("[NETWORK] No STA credentials configured, switching to AP mode");
    startAPMode();
    return;
  }
  
  Serial.print("[NETWORK] Attempting STA connection to: ");
  Serial.println(staSSID);
  
  // Clear any previous SSID
  clearSSID();
  
  // Non-blocking connection attempt
  WiFi.begin(staSSID.c_str(), staPassword.c_str());
  lastSSID = staSSID;
}

void GatewayNetworkManager::startAPMode() {
  Serial.println("[NETWORK] Starting AP mode...");
  
  // Fast, non-blocking switch to AP mode (no delays)
  // Clear STA SSID when switching to AP
  clearSSID();
  
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(AP_SSID, AP_PASSWORD);
  
  IPAddress IP = WiFi.softAPIP();
  Serial.print("[NETWORK] AP IP address: ");
  Serial.println(IP);
  Serial.print("[NETWORK] AP SSID: ");
  Serial.println(AP_SSID);
  
  transitionToState(AP_MODE, "STA connection failed or timeout");
  internetAvailable = false; // Reset internet status when switching to AP
  
  // Don't immediately try STA - let update() handle retries periodically
  staConnectionInProgress = false;
}

void GatewayNetworkManager::checkInternetConnectivity() {
  lastInternetCheck = millis();
  bool previousInternetState = internetAvailable;
  internetAvailable = testInternetConnection();
  
  if (internetAvailable != previousInternetState) {
    Serial.print("[NETWORK] Internet connectivity changed: ");
    Serial.println(internetAvailable ? "ONLINE" : "OFFLINE");
  }
  
  // If we're in ONLINE state but lost internet, stay in ONLINE but mark as offline
  // (WiFi is still connected, just no internet)
  if (!internetAvailable && currentState == ONLINE) {
    Serial.println("[NETWORK] WiFi connected but no internet access");
  }
}

bool GatewayNetworkManager::testInternetConnection() {
  // Fast, non-blocking internet connectivity test
  // Try to connect to Google DNS (port 53) with short timeout (< 200ms)
  WiFiClient client;
  client.setTimeout(1); // 1 second timeout for fast response
  unsigned long startTime = millis();
  
  bool connected = client.connect("8.8.8.8", 53);
  unsigned long elapsed = millis() - startTime;
  
  if (connected) {
    client.stop();
    if (elapsed > 200) {
      Serial.print("[NETWORK] Internet check took ");
      Serial.print(elapsed);
      Serial.println("ms (slow but OK)");
    }
    return true;
  }
  
  client.stop();
  return false;
}

void GatewayNetworkManager::setCredentials(const char* ssid, const char* password) {
  staSSID = String(ssid);
  staPassword = String(password);
  Serial.print("[NETWORK] Credentials set for SSID: ");
  Serial.println(staSSID);
}

void GatewayNetworkManager::transitionToState(NetworkState newState, const char* reason) {
  if (newState != currentState) {
    logStateTransition(currentState, newState, reason);
    lastKnownMode = currentState; // Persist in memory
    currentState = newState;
    lastStateTransitionTime = millis();
  }
}

void GatewayNetworkManager::logStateTransition(NetworkState from, NetworkState to, const char* reason) {
  const char* stateNames[] = {"INIT", "STA_CONNECTING", "ONLINE", "AP_MODE"};
  Serial.print("[NETWORK] State transition: ");
  Serial.print(stateNames[from]);
  Serial.print(" -> ");
  Serial.print(stateNames[to]);
  Serial.print(" | Reason: ");
  Serial.println(reason);
  Serial.print("[NETWORK] Timestamp: ");
  Serial.println(millis());
}

void GatewayNetworkManager::clearSSID() {
  // Clear SSID when switching modes to avoid confusion
  if (lastSSID.length() > 0) {
    Serial.print("[NETWORK] Clearing SSID: ");
    Serial.println(lastSSID);
    lastSSID = "";
  }
}

String GatewayNetworkManager::getSSID() const {
  if (currentState == ONLINE || currentState == STA_CONNECTING) {
    if (lastSSID.length() > 0) {
      return lastSSID;
    }
    return WiFi.SSID().length() > 0 ? WiFi.SSID() : staSSID;
  } else if (currentState == AP_MODE) {
    return String(AP_SSID);
  }
  return String("N/A");
}

IPAddress GatewayNetworkManager::getIP() const {
  if (currentState == ONLINE || currentState == STA_CONNECTING) {
    return WiFi.localIP();
  } else if (currentState == AP_MODE) {
    return WiFi.softAPIP();
  }
  return IPAddress(0, 0, 0, 0);
}

String GatewayNetworkManager::getNetworkModeString() const {
  if (currentState == AP_MODE) {
    return "AP";
  } else if (currentState == ONLINE && internetAvailable) {
    return "ONLINE";
  } else if (currentState == STA_CONNECTING) {
    return "CONNECTING";
  } else {
    return "OFFLINE";
  }
}

