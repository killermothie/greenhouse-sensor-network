#include "oled_display.h"
#include <Arduino.h>

OLEDDisplay::OLEDDisplay() 
  : display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET),
    lastDisplayUpdate(0) {
}

bool OLEDDisplay::begin() {
  if (!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println("SSD1306 allocation failed");
    return false;
  }
  
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("Greenhouse Gateway");
  display.println("Initializing...");
  display.display();
  
  Serial.println("OLED display initialized");
  return true;
}

void OLEDDisplay::update(const char* networkMode, const char* ssid, 
                        bool backendConnected, unsigned long lastUpdate) {
  update(networkMode, ssid, backendConnected, lastUpdate, nullptr, 0);
}

void OLEDDisplay::update(const char* networkMode, const char* ssid, 
                        bool backendConnected, unsigned long lastUpdate,
                        const char* loraNodeId, int loraRSSI) {
  unsigned long currentTime = millis();
  
  // Throttle display updates
  if (currentTime - lastDisplayUpdate < DISPLAY_UPDATE_INTERVAL) {
    return;
  }
  
  lastDisplayUpdate = currentTime;
  drawStatusScreen(networkMode, ssid, backendConnected, lastUpdate, loraNodeId, loraRSSI);
}

void OLEDDisplay::drawStatusScreen(const char* networkMode, const char* ssid, 
                                  bool backendConnected, unsigned long lastUpdate,
                                  const char* loraNodeId, int loraRSSI) {
  display.clearDisplay();
  
  // Title
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("Greenhouse Gateway");
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);
  
  // LoRa node connection status - Priority display (Line 1)
  display.setCursor(0, 12);
  if (loraNodeId != nullptr && strlen(loraNodeId) > 0) {
    // Show connected node prominently
    display.print("Connected to:");
    display.setCursor(0, 22);
    String nodeStr = String(loraNodeId);
    if (nodeStr.length() > 15) {
      nodeStr = nodeStr.substring(0, 12) + "...";
    }
    display.print(nodeStr);
    
    // Show RSSI and signal strength (Line 2)
    display.setCursor(0, 32);
    if (loraRSSI != 0) {
      display.print("Signal: ");
      display.print(loraRSSI);
      display.print(" dBm");
    } else {
      display.print("Signal: --");
    }
    
    // Network mode (Line 3)
    display.setCursor(0, 42);
    display.print("Net: ");
    display.print(networkMode);
    
    // Backend status (Line 4)
    display.setCursor(0, 52);
    if (backendConnected) {
      display.print("Backend: OK");
    } else {
      display.print("Backend: Off");
    }
  } else {
    // No LoRa node connected
    display.print("No node connected");
    
    // Network mode (Line 2)
    display.setCursor(0, 22);
    display.print("Net: ");
    display.print(networkMode);
    
    // SSID (Line 3)
    display.setCursor(0, 32);
    display.print("SSID: ");
    String ssidStr = String(ssid);
    if (ssidStr.length() > 12) {
      ssidStr = ssidStr.substring(0, 9) + "...";
    }
    display.print(ssidStr);
    
    // Last update time (Line 4)
    display.setCursor(0, 42);
    display.print("Last: ");
    if (lastUpdate > 0) {
      unsigned long secondsAgo = (millis() - lastUpdate) / 1000;
      if (secondsAgo < 60) {
        display.print(secondsAgo);
        display.print("s");
      } else {
        display.print(secondsAgo / 60);
        display.print("m");
      }
    } else {
      display.print("N/A");
    }
    
    // Backend status (Line 5)
    display.setCursor(0, 52);
    if (backendConnected) {
      display.print("Backend: OK");
    } else {
      display.print("Backend: Off");
    }
  }
  
  display.display();
}

void OLEDDisplay::clear() {
  display.clearDisplay();
  display.display();
}

