#ifndef NETWORK_MANAGER_H
#define NETWORK_MANAGER_H

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiAP.h>

/**
 * Gateway Network Manager
 * Handles Wi-Fi STA and AP mode switching with fast fallback
 * State machine: INIT -> STA_CONNECTING -> ONLINE -> AP_MODE
 * Fast STA->AP fallback: max 10 seconds
 * Non-blocking reconnection: no delays > 200ms
 */
class GatewayNetworkManager {
public:
  enum NetworkState {
    INIT,              // Initial state
    STA_CONNECTING,    // Attempting STA connection
    ONLINE,            // Connected to STA with internet
    AP_MODE            // Access Point mode (fallback)
  };

  GatewayNetworkManager();
  void begin();
  void update(); // Non-blocking, called frequently
  
  NetworkState getState() const { return currentState; }
  bool isOnline() const { return internetAvailable && currentState == ONLINE; }
  String getSSID() const;
  IPAddress getIP() const;
  String getNetworkModeString() const; // Returns "ONLINE", "OFFLINE", or "AP"
  
  // Wi-Fi credentials (can be changed via web interface later)
  void setCredentials(const char* ssid, const char* password);
  
  // Get last known mode (persisted in memory)
  NetworkState getLastKnownMode() const { return lastKnownMode; }
  
private:
  // Fast fallback: max 10 seconds for STA connection
  static const unsigned long STA_CONNECT_TIMEOUT = 10000; // 10 seconds (reduced from 20s)
  static const unsigned long INTERNET_CHECK_INTERVAL = 10000; // 10 seconds
  static const unsigned long STA_RETRY_INTERVAL = 30000; // Retry STA connection every 30s when in AP mode
  static const unsigned long NON_BLOCKING_DELAY_MAX = 200; // Max delay for non-blocking operations
  static const char* AP_SSID;
  static const char* AP_PASSWORD;
  
  NetworkState currentState;
  NetworkState lastKnownMode; // Persisted in memory
  bool internetAvailable;
  unsigned long staConnectStartTime;
  unsigned long lastInternetCheck;
  unsigned long lastSTARetryAttempt;
  unsigned long lastStateTransitionTime;
  bool staConnectionInProgress;
  
  String staSSID;
  String staPassword;
  String lastSSID; // Track last SSID to detect changes
  
  void attemptSTAConnection();
  void startAPMode();
  void checkInternetConnectivity();
  bool testInternetConnection();
  void transitionToState(NetworkState newState, const char* reason);
  void logStateTransition(NetworkState from, NetworkState to, const char* reason);
  void clearSSID();
};

#endif // NETWORK_MANAGER_H

