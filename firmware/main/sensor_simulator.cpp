#include "sensor_simulator.h"
#include <Arduino.h>
#include <esp_random.h>

const float SensorSimulator::TEMP_MIN = 18.0;
const float SensorSimulator::TEMP_MAX = 32.0;
const float SensorSimulator::HUMIDITY_MIN = 40.0;
const float SensorSimulator::HUMIDITY_MAX = 85.0;
const float SensorSimulator::SOIL_MOISTURE_MIN = 20.0;
const float SensorSimulator::SOIL_MOISTURE_MAX = 80.0;
const int SensorSimulator::BATTERY_MIN = 20;
const int SensorSimulator::BATTERY_MAX = 100;
const int SensorSimulator::RSSI_MIN = -90;
const int SensorSimulator::RSSI_MAX = -40;

SensorSimulator::SensorSimulator() 
  : lastUpdate(0) {
  lastData = {0};
}

void SensorSimulator::begin() {
  // ESP32 has hardware RNG, no need to seed
  // esp_random() is already available
}

SensorSimulator::SensorData SensorSimulator::generateData(const char* nodeId) {
  unsigned long currentTime = millis();
  
  // Only generate new data if interval has passed
  if (currentTime - lastUpdate < UPDATE_INTERVAL && lastData.timestamp > 0) {
    return lastData;
  }
  
  lastUpdate = currentTime;
  
  SensorData data;
  data.timestamp = currentTime;
  
  // Generate base values with realistic ranges
  data.temperature = randomFloat(TEMP_MIN, TEMP_MAX);
  data.humidity = randomFloat(HUMIDITY_MIN, HUMIDITY_MAX);
  data.soilMoisture = randomFloat(SOIL_MOISTURE_MIN, SOIL_MOISTURE_MAX);
  data.batteryLevel = BATTERY_MIN + (esp_random() % (BATTERY_MAX - BATTERY_MIN + 1));
  data.rssi = RSSI_MIN + (esp_random() % (RSSI_MAX - RSSI_MIN + 1));
  
  // Add realistic variation (gradual changes, not completely random)
  addRealisticVariation(data);
  
  lastData = data;
  
  Serial.print("Generated sensor data - Temp: ");
  Serial.print(data.temperature);
  Serial.print("°C, Humidity: ");
  Serial.print(data.humidity);
  Serial.print("%, Soil: ");
  Serial.print(data.soilMoisture);
  Serial.print("%, Battery: ");
  Serial.print(data.batteryLevel);
  Serial.print("%, RSSI: ");
  Serial.print(data.rssi);
  Serial.println(" dBm");
  
  return data;
}

float SensorSimulator::randomFloat(float min, float max) {
  return min + (max - min) * ((esp_random() % 10000) / 10000.0);
}

void SensorSimulator::addRealisticVariation(SensorData& data) {
  // If we have previous data, make gradual changes instead of random jumps
  if (lastData.timestamp > 0) {
    // Temperature: gradual changes (±2°C max)
    float tempChange = randomFloat(-2.0, 2.0);
    data.temperature = constrain(lastData.temperature + tempChange, TEMP_MIN, TEMP_MAX);
    
    // Humidity: gradual changes (±5% max)
    float humidityChange = randomFloat(-5.0, 5.0);
    data.humidity = constrain(lastData.humidity + humidityChange, HUMIDITY_MIN, HUMIDITY_MAX);
    
    // Soil moisture: gradual changes (±3% max)
    float soilChange = randomFloat(-3.0, 3.0);
    data.soilMoisture = constrain(lastData.soilMoisture + soilChange, SOIL_MOISTURE_MIN, SOIL_MOISTURE_MAX);
    
    // Battery: slow drain (0-1% decrease, occasional small increase)
    int batteryChange = -1 + (esp_random() % 3); // -1 to 1
    data.batteryLevel = constrain(lastData.batteryLevel + batteryChange, BATTERY_MIN, BATTERY_MAX);
    
    // RSSI: small variations (±5 dBm)
    int rssiChange = -5 + (esp_random() % 11); // -5 to 5
    data.rssi = constrain(lastData.rssi + rssiChange, RSSI_MIN, RSSI_MAX);
  }
}

