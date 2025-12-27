#ifndef STATE_MANAGER_H
#define STATE_MANAGER_H

#include <Arduino.h>
#include "sensor_simulator.h"

/**
 * State Manager
 * Manages sensor data ring buffer for offline mode
 * Handles data synchronization when connection is restored
 */
class StateManager {
public:
  static const int BUFFER_SIZE = 100; // Store up to 100 sensor readings
  
  StateManager();
  void addSensorData(const SensorSimulator::SensorData& data, const char* nodeId);
  int getBufferCount() const { return bufferCount; }
  bool isBufferFull() const { return bufferCount >= BUFFER_SIZE; }
  int getNodeCount() const; // Number of unique nodes received (excluding gateway)
  int getActiveNodeCount(unsigned long timeWindowMs = 300000) const; // Active nodes in last 5 minutes (default)
  void clearGatewayEntries(); // Remove gateway entries from unique nodes list
  
  // Get latest sensor data
  SensorSimulator::SensorData getLatestData() const;
  
  // Get data for syncing (returns false when no more data)
  // Returns the oldest unsynced data first
  bool getNextBufferedData(SensorSimulator::SensorData& data, String& nodeId, int& bufferIndex);
  void markDataAsSynced(int bufferIndex);
  
  void resetSyncIndex() { syncIndex = 0; }
  
private:
  struct BufferedData {
    SensorSimulator::SensorData data;
    String nodeId;
    bool synced;
  };
  
  BufferedData buffer[BUFFER_SIZE];
  int writeIndex;
  int bufferCount;
  int syncIndex; // For syncing buffered data
  int uniqueNodeCount; // Track number of unique nodes
  String uniqueNodes[20]; // Store up to 20 unique node IDs
  int uniqueNodeArraySize;
  
  bool isNodeUnique(const char* nodeId);
  void addUniqueNode(const char* nodeId);
  int getNextIndex(int index) const;
};

#endif // STATE_MANAGER_H

