#include "lora_receiver.h"
#include <SPI.h>

// Static members
LoRaReceiver* LoRaReceiver::instance = nullptr;
LoRaReceiver::SensorMessage LoRaReceiver::lastReceivedMessage;
bool LoRaReceiver::messageReceived = false;
volatile bool LoRaReceiver::interruptFlag = false;

LoRaReceiver::LoRaReceiver() 
  : receivedCount(0),
    dataCallback(nullptr),
    lastRSSI(0),
    lastReceiveTime(0) {
  instance = this;
  lora = nullptr;
}

bool LoRaReceiver::begin() {
  Serial.println("\n=== LoRa Gateway Receiver Initialization ===");
  Serial.println("Hardware Configuration:");
  Serial.print("  SCK: GPIO ");
  Serial.println(LORA_SCK);
  Serial.print("  MISO: GPIO ");
  Serial.println(LORA_MISO);
  Serial.print("  MOSI: GPIO ");
  Serial.println(LORA_MOSI);
  Serial.print("  NSS: GPIO ");
  Serial.println(LORA_NSS);
  Serial.print("  DIO0: GPIO ");
  Serial.println(LORA_DIO0);
  Serial.print("  RST: GPIO ");
  Serial.println(LORA_RST);
  
  // Initialize SPI for LoRa
  SPI.begin(LORA_SCK, LORA_MISO, LORA_MOSI, LORA_NSS);
  Serial.println("SPI initialized");
  
  // Create SX1278 instance (DIO0 for interrupt, no BUSY pin on SX1278)
  lora = new SX1278(new Module(LORA_NSS, LORA_DIO0, LORA_RST));
  
  Serial.print("Initializing SX1278 LoRa receiver... ");
  
  // Initialize SX1278 in receive mode
  // Frequency: 433.0 MHz (433MHz LoRa module)
  int state = lora->begin(433.0);
  
  if (state != RADIOLIB_ERR_NONE) {
    Serial.print("FAILED, error code: ");
    Serial.println(state);
    Serial.println("Gateway will continue without LoRa receiver");
    delete lora;
    lora = nullptr;
    return false;
  }
  
  Serial.println("SUCCESS");
  
  // Configure LoRa parameters (must match node settings)
  Serial.println("Configuring LoRa parameters...");
  state = lora->setBandwidth(125.0);
  if (state != RADIOLIB_ERR_NONE) {
    Serial.print("  Warning: Error setting bandwidth: ");
    Serial.println(state);
  } else {
    Serial.println("  Bandwidth: 125.0 kHz");
  }
  
  state = lora->setSpreadingFactor(7);
  if (state != RADIOLIB_ERR_NONE) {
    Serial.print("  Warning: Error setting spreading factor: ");
    Serial.println(state);
  } else {
    Serial.println("  Spreading Factor: 7");
  }
  
  state = lora->setCodingRate(5); // 4/5 coding rate
  if (state != RADIOLIB_ERR_NONE) {
    Serial.print("  Warning: Error setting coding rate: ");
    Serial.println(state);
  } else {
    Serial.println("  Coding Rate: 4/5");
  }
  
  state = lora->setOutputPower(17);
  if (state != RADIOLIB_ERR_NONE) {
    Serial.print("  Warning: Error setting output power: ");
    Serial.println(state);
  } else {
    Serial.println("  Output Power: 17 dBm");
  }
  
  // Set DIO0 interrupt for packet reception (SX1278 uses DIO0)
  pinMode(LORA_DIO0, INPUT);
  attachInterrupt(digitalPinToInterrupt(LORA_DIO0), LoRaReceiver::setFlag, RISING);
  Serial.println("DIO0 interrupt configured");
  
  // Start receiving
  state = lora->startReceive();
  if (state != RADIOLIB_ERR_NONE) {
    Serial.print("Error starting receive mode: ");
    Serial.println(state);
    delete lora;
    lora = nullptr;
    return false;
  }
  
  Serial.println("=== LoRa Gateway Receiver Ready ===");
  Serial.println("Status: Listening for LoRa nodes on 433.0 MHz");
  Serial.println("Waiting for node connections...\n");
  return true;
}

void IRAM_ATTR LoRaReceiver::setFlag(void) {
  LoRaReceiver::interruptFlag = true;
}

void LoRaReceiver::setDataCallback(void (*callback)(const SensorMessage&)) {
  dataCallback = callback;
}

void LoRaReceiver::processReceivedData() {
  if (lora == nullptr) {
    return;
  }
  
  // Check if packet was received
  if (LoRaReceiver::interruptFlag) {
    LoRaReceiver::interruptFlag = false;
    
    // Read received packet
    size_t packetLen = 0;
    int state = lora->available();
    
    if (state == RADIOLIB_ERR_NONE) {
      // Get packet length
      packetLen = lora->getPacketLength();
      
      if (packetLen > 0 && packetLen < 256) {
        // Allocate buffer for packet
        uint8_t* packet = new uint8_t[packetLen];
        
        // Read packet data
        state = lora->readData(packet, packetLen);
        
        if (state == RADIOLIB_ERR_NONE) {
          // Get RSSI if available
          int rssi = lora->getRSSI();
          
          // Handle received packet
          instance->handleReceivedPacket(packet, packetLen, rssi);
          
          receivedCount++;
        } else {
          Serial.print("Error reading packet data: ");
          Serial.println(state);
        }
        
        delete[] packet;
      }
      
      // Restart receiving for next packet
      lora->startReceive();
    } else if (state != RADIOLIB_ERR_NONE && state != RADIOLIB_ERR_RX_TIMEOUT) {
      Serial.print("Error checking for packet: ");
      Serial.println(state);
      // Restart receiving on error
      lora->startReceive();
    }
  }
}

void LoRaReceiver::handleReceivedPacket(uint8_t* data, size_t len, int rssi) {
  // Null-terminate the data for string parsing
  if (len >= 256) {
    Serial.println("Error: Packet too large");
    return;
  }
  
  char jsonBuffer[256];
  memcpy(jsonBuffer, data, len);
  jsonBuffer[len] = '\0';
  
  // Parse JSON packet
  SensorMessage msg;
  if (parseJsonPacket(jsonBuffer, msg)) {
    // Update RSSI from LoRa module
    msg.rssi = rssi;
    lastRSSI = rssi;
    lastNodeId = String(msg.nodeId);
    lastReceiveTime = millis(); // Update last receive timestamp
    
    // Store message and set flag
    lastReceivedMessage = msg;
    messageReceived = true;
    
    // Process the message
    handleReceivedMessage(msg);
  } else {
    Serial.print("Error parsing JSON packet: ");
    Serial.println((const char*)jsonBuffer);
  }
}

bool LoRaReceiver::parseJsonPacket(const char* json, SensorMessage& msg) {
  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, json);
  
  if (error) {
    Serial.print("JSON deserialize error: ");
    Serial.println(error.c_str());
    return false;
  }
  
  // Extract fields from JSON
  const char* nodeId = doc["nodeId"];
  if (nodeId != nullptr) {
    strncpy(msg.nodeId, nodeId, sizeof(msg.nodeId) - 1);
    msg.nodeId[sizeof(msg.nodeId) - 1] = '\0';
  } else {
    return false;
  }
  
  msg.temperature = doc["temperature"] | 0.0;
  msg.humidity = doc["humidity"] | 0.0;
  msg.soilMoisture = doc["soilMoisture"] | 0.0;
  msg.batteryLevel = doc["batteryLevel"] | 0;
  msg.rssi = doc["rssi"] | 0;
  msg.timestamp = doc["timestamp"] | millis();
  
  return true;
}

bool LoRaReceiver::isNodeActive(unsigned long timeoutMs) const {
  if (lastReceiveTime == 0) {
    return false; // No packet ever received
  }
  
  unsigned long currentTime = millis();
  unsigned long timeSinceLastPacket = currentTime - lastReceiveTime;
  
  // Handle millis() overflow
  if (timeSinceLastPacket > 2147483647UL) {
    return false; // Overflow occurred, consider inactive
  }
  
  return timeSinceLastPacket < timeoutMs;
}

void LoRaReceiver::handleReceivedMessage(const SensorMessage& msg) {
  Serial.println("\n=== LoRa Packet Received ===");
  Serial.print("Node ID: ");
  Serial.println(msg.nodeId);
  Serial.print("Temperature: ");
  Serial.print(msg.temperature);
  Serial.println(" °C");
  Serial.print("Humidity: ");
  Serial.print(msg.humidity);
  Serial.println(" %");
  Serial.print("Soil Moisture: ");
  Serial.print(msg.soilMoisture);
  Serial.println(" %");
  Serial.print("Battery Level: ");
  Serial.print(msg.batteryLevel);
  Serial.println(" %");
  Serial.print("Signal Strength (RSSI): ");
  Serial.print(msg.rssi);
  Serial.println(" dBm");
  Serial.print("Timestamp: ");
  Serial.println(msg.timestamp);
  Serial.println("Status: Node CONNECTED to gateway");
  Serial.println("============================\n");
  
  // Call callback if set
  if (dataCallback != nullptr) {
    dataCallback(msg);
  }
}

