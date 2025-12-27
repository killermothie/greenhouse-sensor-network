#ifndef LORA_RECEIVER_H
#define LORA_RECEIVER_H

#include <Arduino.h>
#include <ArduinoJson.h>
#include <RadioLib.h>
#include "sensor_simulator.h"

/**
 * LoRa Receiver
 * Receives sensor data from LoRa SX1278 nodes
 * Handles packet reception and JSON deserialization
 * Mirrors ESPNowReceiver pattern for seamless integration
 */
class LoRaReceiver {
public:
  // Data structure for LoRa messages (matches ESP-NOW format)
  struct SensorMessage {
    char nodeId[16];        // Node identifier
    float temperature;      // Celsius
    float humidity;         // Percentage
    float soilMoisture;     // Percentage
    int batteryLevel;       // Percentage
    int rssi;              // Signal strength
    unsigned long timestamp;
  };
  
  LoRaReceiver();
  bool begin();
  void setDataCallback(void (*callback)(const SensorMessage&));
  void processReceivedData();
  
  int getReceivedCount() const { return receivedCount; }
  String getLastNodeId() const { return lastNodeId; }
  int getLastRSSI() const { return lastRSSI; }
  bool isNodeActive(unsigned long timeoutMs = 60000) const; // Check if node is still active (default 60 seconds)
  unsigned long getLastReceiveTime() const { return lastReceiveTime; }
  
private:
  // SX1278 LoRa module pin definitions (matching node firmware)
  static const int LORA_SCK = 18;
  static const int LORA_MISO = 19;
  static const int LORA_MOSI = 23;
  static const int LORA_NSS = 5;
  static const int LORA_DIO0 = 26;
  static const int LORA_RST = 14;
  
  SX1278* lora;
  int receivedCount;
  void (*dataCallback)(const SensorMessage&);
  String lastNodeId;
  int lastRSSI;
  unsigned long lastReceiveTime; // Timestamp of last received packet
  
  static LoRaReceiver* instance;
  static SensorMessage lastReceivedMessage;
  static bool messageReceived;
  static volatile bool interruptFlag;
  
  static void IRAM_ATTR setFlag(void);
  void handleReceivedPacket(uint8_t* data, size_t len, int rssi);
  void handleReceivedMessage(const SensorMessage& msg);
  bool parseJsonPacket(const char* json, SensorMessage& msg);
};

#endif // LORA_RECEIVER_H

