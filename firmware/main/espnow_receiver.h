#ifndef ESPNOW_RECEIVER_H
#define ESPNOW_RECEIVER_H

#include <Arduino.h>
#include <esp_now.h>
#include <WiFi.h>
#include "sensor_simulator.h"

/**
 * ESP-NOW Receiver
 * Receives sensor data from ESP-NOW sensor nodes
 * Handles pairing and data reception
 */
class ESPNowReceiver {
public:
  // Data structure for ESP-NOW messages (must match sender)
  struct SensorMessage {
    char nodeId[16];        // Node identifier
    float temperature;      // Celsius
    float humidity;         // Percentage
    float soilMoisture;     // Percentage
    int batteryLevel;       // Percentage
    int rssi;              // Signal strength
    unsigned long timestamp;
  };
  
  ESPNowReceiver();
  bool begin();
  void setDataCallback(void (*callback)(const SensorMessage&));
  void processReceivedData();
  
  int getReceivedCount() const { return receivedCount; }
  
private:
  static const int MAX_PEERS = 20;
  
  int receivedCount;
  void (*dataCallback)(const SensorMessage&);
  
  static void onDataRecv(const esp_now_recv_info *recv_info, const uint8_t *incomingData, int len);
  static ESPNowReceiver* instance;
  static SensorMessage lastReceivedMessage;
  static bool messageReceived;
  
  void handleReceivedMessage(const SensorMessage& msg);
};

#endif // ESPNOW_RECEIVER_H

