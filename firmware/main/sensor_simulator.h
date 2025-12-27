#ifndef SENSOR_SIMULATOR_H
#define SENSOR_SIMULATOR_H

#include <Arduino.h>

/**
 * Sensor Simulator
 * Generates realistic simulated sensor data for greenhouse environment
 */
class SensorSimulator {
public:
  struct SensorData {
    float temperature;      // Celsius
    float humidity;         // Percentage (0-100)
    float soilMoisture;     // Percentage (0-100)
    int batteryLevel;       // Percentage (0-100)
    int rssi;               // Signal strength
    unsigned long timestamp;
  };
  
  SensorSimulator();
  void begin();
  SensorData generateData(const char* nodeId);
  
private:
  static const unsigned long UPDATE_INTERVAL = 10000; // 10 seconds
  
  unsigned long lastUpdate;
  SensorData lastData;
  
  // Realistic ranges for greenhouse environment
  static const float TEMP_MIN;
  static const float TEMP_MAX;
  static const float HUMIDITY_MIN;
  static const float HUMIDITY_MAX;
  static const float SOIL_MOISTURE_MIN;
  static const float SOIL_MOISTURE_MAX;
  static const int BATTERY_MIN;
  static const int BATTERY_MAX;
  static const int RSSI_MIN;
  static const int RSSI_MAX;
  
  float randomFloat(float min, float max);
  void addRealisticVariation(SensorData& data);
};

#endif // SENSOR_SIMULATOR_H

