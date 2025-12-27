/**
 * LoRa Node Firmware
 * ESP32 + SX1278 LoRa Node
 * Sends sensor data packets to gateway via LoRa
 * 
 * Hardware Configuration:
 * - SCK   → GPIO 18
 * - MISO  → GPIO 19
 * - MOSI  → GPIO 23
 * - NSS   → GPIO 5
 * - DIO0  → GPIO 26
 * - RESET → GPIO 14
 * - VCC   → 3.3V
 * - GND   → GND
 */

#include <Arduino.h>
#include <SPI.h>
#include <ArduinoJson.h>
#include <RadioLib.h>

// Node configuration
const char* NODE_ID = "lora-node-01";
const unsigned long TRANSMIT_INTERVAL = 5000; // 5 seconds

// SX1278 LoRa module pin definitions
#define LORA_SCK   18
#define LORA_MISO  19
#define LORA_MOSI  23
#define LORA_NSS   5
#define LORA_DIO0  26
#define LORA_RST   14

// Create SX1278 instance (DIO0 for interrupt, no BUSY pin on SX1278)
SX1278 lora = new Module(LORA_NSS, LORA_DIO0, LORA_RST);

// Timing
unsigned long lastTransmit = 0;

// Sensor data structure
struct SensorData {
  char nodeId[16];
  float temperature;
  float humidity;
  float soilMoisture;
  int batteryLevel;
  int rssi;
  unsigned long timestamp;
};

// Simulated sensor values (replace with actual sensor readings)
float readTemperature() {
  // Simulate temperature reading (20-30°C)
  return 22.5 + (random(0, 100) / 10.0);
}

float readHumidity() {
  // Simulate humidity reading (40-80%)
  return 60.0 + (random(0, 400) / 10.0);
}

float readSoilMoisture() {
  // Simulate soil moisture reading (30-70%)
  return 50.0 + (random(0, 400) / 10.0);
}

int readBatteryLevel() {
  // Simulate battery level (0-100%)
  return 85 + random(0, 15);
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== LoRa Node Starting ===");
  Serial.print("Node ID: ");
  Serial.println(NODE_ID);
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
  
  // Initialize SX1278 LoRa module
  Serial.print("Initializing SX1278 LoRa module... ");
  
  // Point-to-point mode with default settings
  // Frequency: 433.0 MHz (433MHz LoRa module)
  int state = lora.begin(433.0);
  
  if (state == RADIOLIB_ERR_NONE) {
    Serial.println("SUCCESS");
    
    // Configure LoRa parameters for point-to-point communication
    // Frequency: 433.0 MHz (already set)
    // Bandwidth: 125.0 kHz (typical for SX1278)
    // Spreading Factor: 7
    // Coding Rate: 5 (4/5)
    // Output Power: 17 dBm (max for SX1278)
    Serial.println("Configuring LoRa parameters...");
    
    state = lora.setBandwidth(125.0);
    if (state != RADIOLIB_ERR_NONE) {
      Serial.print("  Error setting bandwidth: ");
      Serial.println(state);
    } else {
      Serial.println("  Bandwidth: 125.0 kHz");
    }
    
    state = lora.setSpreadingFactor(7);
    if (state != RADIOLIB_ERR_NONE) {
      Serial.print("  Error setting spreading factor: ");
      Serial.println(state);
    } else {
      Serial.println("  Spreading Factor: 7");
    }
    
    state = lora.setCodingRate(5); // 4/5 coding rate
    if (state != RADIOLIB_ERR_NONE) {
      Serial.print("  Error setting coding rate: ");
      Serial.println(state);
    } else {
      Serial.println("  Coding Rate: 4/5");
    }
    
    state = lora.setOutputPower(17);
    if (state != RADIOLIB_ERR_NONE) {
      Serial.print("  Error setting output power: ");
      Serial.println(state);
    } else {
      Serial.println("  Output Power: 17 dBm");
    }
    
    Serial.println("=== LoRa Node Ready ===");
    Serial.print("Status: Node ");
    Serial.print(NODE_ID);
    Serial.println(" is ready to transmit");
    Serial.println("Frequency: 433.0 MHz");
    Serial.print("Transmit interval: ");
    Serial.print(TRANSMIT_INTERVAL / 1000);
    Serial.println(" seconds");
    Serial.println("Waiting to send data to gateway...\n");
  } else {
    Serial.print("FAILED, error code: ");
    Serial.println(state);
    Serial.println("Node will not function properly");
    while(1) {
      delay(1000); // Halt on initialization failure
    }
  }
}

void loop() {
  unsigned long currentTime = millis();
  
  // Transmit sensor data every TRANSMIT_INTERVAL
  if (currentTime - lastTransmit >= TRANSMIT_INTERVAL) {
    lastTransmit = currentTime;
    transmitSensorData();
  }
  
  // Small delay to prevent watchdog issues
  delay(100);
}

void transmitSensorData() {
  // Read sensor values
  SensorData sensorData;
  strncpy(sensorData.nodeId, NODE_ID, sizeof(sensorData.nodeId) - 1);
  sensorData.nodeId[sizeof(sensorData.nodeId) - 1] = '\0';
  sensorData.temperature = readTemperature();
  sensorData.humidity = readHumidity();
  sensorData.soilMoisture = readSoilMoisture();
  sensorData.batteryLevel = readBatteryLevel();
  sensorData.rssi = 0; // Not available for transmitter
  sensorData.timestamp = millis();
  
  // Create JSON document
  StaticJsonDocument<256> doc;
  doc["nodeId"] = sensorData.nodeId;
  doc["temperature"] = sensorData.temperature;
  doc["humidity"] = sensorData.humidity;
  doc["soilMoisture"] = sensorData.soilMoisture;
  doc["batteryLevel"] = sensorData.batteryLevel;
  doc["rssi"] = sensorData.rssi;
  doc["timestamp"] = sensorData.timestamp;
  
  // Serialize JSON to string
  String jsonString;
  serializeJson(doc, jsonString);
  
  // Convert to byte array for transmission
  uint8_t packet[256];
  int packetLen = jsonString.length();
  if (packetLen > 255) {
    Serial.println("Error: JSON packet too large");
    return;
  }
  
  memcpy(packet, jsonString.c_str(), packetLen);
  
  // Transmit packet via LoRa
  Serial.println("\n=== Transmitting to Gateway ===");
  Serial.print("Node ID: ");
  Serial.println(sensorData.nodeId);
  Serial.print("Packet: ");
  Serial.println(jsonString);
  
  int state = lora.transmit(packet, packetLen);
  
  if (state == RADIOLIB_ERR_NONE) {
    Serial.println("Status: Packet transmitted SUCCESSFULLY");
    Serial.println("Sensor Data:");
    Serial.print("  Temperature: ");
    Serial.print(sensorData.temperature);
    Serial.println(" °C");
    Serial.print("  Humidity: ");
    Serial.print(sensorData.humidity);
    Serial.println(" %");
    Serial.print("  Soil Moisture: ");
    Serial.print(sensorData.soilMoisture);
    Serial.println(" %");
    Serial.print("  Battery Level: ");
    Serial.print(sensorData.batteryLevel);
    Serial.println(" %");
    Serial.println("Status: Node CONNECTED to gateway");
    Serial.println("==============================\n");
  } else {
    Serial.print("Status: Transmission FAILED, error code: ");
    Serial.println(state);
    Serial.println("Status: Node NOT connected to gateway");
    Serial.println("==============================\n");
  }
}

