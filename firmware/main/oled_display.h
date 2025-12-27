#ifndef OLED_DISPLAY_H
#define OLED_DISPLAY_H

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_GFX.h>

/**
 * OLED Display Manager
 * Handles SSD1306 OLED display updates
 * Shows network status, backend status, and sensor info
 */
class OLEDDisplay {
public:
  OLEDDisplay();
  bool begin();
  void update(const char* networkMode, const char* ssid, 
             bool backendConnected, unsigned long lastUpdate);
  void update(const char* networkMode, const char* ssid, 
             bool backendConnected, unsigned long lastUpdate,
             const char* loraNodeId, int loraRSSI);
  void clear();
  
private:
  static const int SCREEN_WIDTH = 128;
  static const int SCREEN_HEIGHT = 64;
  static const int OLED_RESET = -1; // Reset pin # (or -1 if sharing Arduino reset pin)
  static const int SCREEN_ADDRESS = 0x3C; // I2C address
  
  Adafruit_SSD1306 display;
  unsigned long lastDisplayUpdate;
  static const unsigned long DISPLAY_UPDATE_INTERVAL = 1000; // Update every second
  
  void drawStatusScreen(const char* networkMode, const char* ssid, 
                       bool backendConnected, unsigned long lastUpdate,
                       const char* loraNodeId = nullptr, int loraRSSI = 0);
};

#endif // OLED_DISPLAY_H

