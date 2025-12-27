#include "espnow_receiver.h"

// Static members
ESPNowReceiver* ESPNowReceiver::instance = nullptr;
ESPNowReceiver::SensorMessage ESPNowReceiver::lastReceivedMessage;
bool ESPNowReceiver::messageReceived = false;

ESPNowReceiver::ESPNowReceiver() 
  : receivedCount(0),
    dataCallback(nullptr) {
  instance = this;
}

bool ESPNowReceiver::begin() {
  // Initialize ESP-NOW
  if (esp_now_init() != ESP_OK) {
    Serial.println("Error initializing ESP-NOW");
    return false;
  }
  
  // Register callback
  esp_now_register_recv_cb(onDataRecv);
  
  Serial.println("ESP-NOW receiver initialized");
  return true;
}

void ESPNowReceiver::setDataCallback(void (*callback)(const SensorMessage&)) {
  dataCallback = callback;
}

void ESPNowReceiver::onDataRecv(const esp_now_recv_info *recv_info, const uint8_t *incomingData, int len) {
  if (instance == nullptr) return;
  
  if (len == sizeof(SensorMessage)) {
    memcpy(&lastReceivedMessage, incomingData, sizeof(SensorMessage));
    // Update RSSI from received info if available
    if (recv_info != nullptr && recv_info->rx_ctrl != nullptr && recv_info->rx_ctrl->rssi != 0) {
      lastReceivedMessage.rssi = recv_info->rx_ctrl->rssi;
    }
    messageReceived = true;
  }
}

void ESPNowReceiver::processReceivedData() {
  if (messageReceived && instance != nullptr) {
    messageReceived = false;
    receivedCount++;
    instance->handleReceivedMessage(lastReceivedMessage);
  }
}

void ESPNowReceiver::handleReceivedMessage(const SensorMessage& msg) {
  Serial.print("ESP-NOW data received from: ");
  Serial.print(msg.nodeId);
  Serial.print(" - Temp: ");
  Serial.print(msg.temperature);
  Serial.print("°C, Humidity: ");
  Serial.print(msg.humidity);
  Serial.print("%, Soil: ");
  Serial.print(msg.soilMoisture);
  Serial.print("%, Battery: ");
  Serial.print(msg.batteryLevel);
  Serial.print("%, RSSI: ");
  Serial.print(msg.rssi);
  Serial.println(" dBm");
  
  // Call callback if set
  if (dataCallback != nullptr) {
    dataCallback(msg);
  }
}

