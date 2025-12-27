#include "state_manager.h"
#include <Arduino.h>

StateManager::StateManager() 
  : writeIndex(0), 
    bufferCount(0), 
    syncIndex(0),
    uniqueNodeCount(0),
    uniqueNodeArraySize(0) {
  // Initialize buffer
  for (int i = 0; i < BUFFER_SIZE; i++) {
    buffer[i].synced = true;
  }
  // Initialize unique nodes array
  for (int i = 0; i < 20; i++) {
    uniqueNodes[i] = "";
  }
}

void StateManager::addSensorData(const SensorSimulator::SensorData& data, const char* nodeId) {
  buffer[writeIndex].data = data;
  buffer[writeIndex].nodeId = String(nodeId);
  buffer[writeIndex].synced = false;
  
  // Track unique nodes (excluding gateway)
  String nodeIdStr = String(nodeId);
  if (!nodeIdStr.equals("gateway-01") && !nodeIdStr.startsWith("gateway-")) {
    if (isNodeUnique(nodeId)) {
      addUniqueNode(nodeId);
    }
  }
  
  writeIndex = getNextIndex(writeIndex);
  
  if (bufferCount < BUFFER_SIZE) {
    bufferCount++;
  }
  
  Serial.print("Added data to buffer. Count: ");
  Serial.print(bufferCount);
  Serial.print(", Nodes: ");
  Serial.println(uniqueNodeCount);
}

SensorSimulator::SensorData StateManager::getLatestData() const {
  if (bufferCount == 0) {
    SensorSimulator::SensorData empty;
    empty.timestamp = 0;
    return empty;
  }
  
  int latestIndex = (writeIndex == 0) ? BUFFER_SIZE - 1 : writeIndex - 1;
  return buffer[latestIndex].data;
}

bool StateManager::getNextBufferedData(SensorSimulator::SensorData& data, String& nodeId, int& bufferIndex) {
  if (bufferCount == 0) {
    return false;
  }
  
  // Calculate the oldest entry in the buffer
  // The oldest entry is at (writeIndex - bufferCount + BUFFER_SIZE) % BUFFER_SIZE
  int oldestIndex = (writeIndex - bufferCount + BUFFER_SIZE) % BUFFER_SIZE;
  
  // Search from oldest to newest for unsynced data
  for (int i = 0; i < bufferCount; i++) {
    int index = (oldestIndex + i) % BUFFER_SIZE;
    
    if (!buffer[index].synced) {
      data = buffer[index].data;
      nodeId = buffer[index].nodeId;
      bufferIndex = index;
      return true;
    }
  }
  
  return false; // No more unsynced data
}

void StateManager::markDataAsSynced(int bufferIndex) {
  if (bufferIndex >= 0 && bufferIndex < BUFFER_SIZE) {
    buffer[bufferIndex].synced = true;
  }
}

bool StateManager::isNodeUnique(const char* nodeId) {
  String nodeIdStr = String(nodeId);
  for (int i = 0; i < uniqueNodeArraySize; i++) {
    if (uniqueNodes[i].equals(nodeIdStr)) {
      return false; // Node already exists
    }
  }
  return true; // New unique node
}

void StateManager::addUniqueNode(const char* nodeId) {
  // Exclude gateway from node count (gateway is not a sensor node)
  String nodeIdStr = String(nodeId);
  if (nodeIdStr.equals("gateway-01") || nodeIdStr.startsWith("gateway-")) {
    return; // Don't count gateway as a node
  }
  
  if (uniqueNodeArraySize < 20) {
    uniqueNodes[uniqueNodeArraySize] = nodeIdStr;
    uniqueNodeArraySize++;
    // Recalculate uniqueNodeCount excluding gateway
    uniqueNodeCount = 0;
    for (int i = 0; i < uniqueNodeArraySize; i++) {
      if (!uniqueNodes[i].equals("gateway-01") && !uniqueNodes[i].startsWith("gateway-")) {
        uniqueNodeCount++;
      }
    }
    Serial.print("New node detected: ");
    Serial.print(nodeId);
    Serial.print(" (Total nodes: ");
    Serial.print(uniqueNodeCount);
    Serial.println(")");
  }
}

int StateManager::getNextIndex(int index) const {
  return (index + 1) % BUFFER_SIZE;
}

int StateManager::getNodeCount() const {
  // Recalculate node count excluding gateway (in case gateway was added before this fix)
  int count = 0;
  for (int i = 0; i < uniqueNodeArraySize; i++) {
    if (!uniqueNodes[i].equals("gateway-01") && !uniqueNodes[i].startsWith("gateway-")) {
      count++;
    }
  }
  return count;
}

void StateManager::clearGatewayEntries() {
  // Remove gateway entries from unique nodes array
  int writePos = 0;
  for (int i = 0; i < uniqueNodeArraySize; i++) {
    if (!uniqueNodes[i].equals("gateway-01") && !uniqueNodes[i].startsWith("gateway-")) {
      if (writePos != i) {
        uniqueNodes[writePos] = uniqueNodes[i];
      }
      writePos++;
    }
  }
  uniqueNodeArraySize = writePos;
  uniqueNodeCount = writePos;
  Serial.println("Cleared gateway entries from node list");
}

int StateManager::getActiveNodeCount(unsigned long timeWindowMs) const {
  if (bufferCount == 0) {
    return 0;
  }
  
  unsigned long currentTime = millis();
  unsigned long cutoffTime = currentTime - timeWindowMs;
  
  // Track unique active nodes (excluding gateway)
  String activeNodes[20];
  int activeNodeCount = 0;
  
  // Calculate the oldest entry in the buffer
  int oldestIndex = (writeIndex - bufferCount + BUFFER_SIZE) % BUFFER_SIZE;
  
  // Check all entries in the buffer
  for (int i = 0; i < bufferCount; i++) {
    int index = (oldestIndex + i) % BUFFER_SIZE;
    
    // Skip gateway nodes (gateway is not a sensor node)
    String nodeIdStr = buffer[index].nodeId;
    if (nodeIdStr.equals("gateway-01") || nodeIdStr.startsWith("gateway-")) {
      continue; // Skip gateway
    }
    
    // Check if this entry is within the time window
    if (buffer[index].data.timestamp >= cutoffTime) {
      // Check if this node is already counted
      bool alreadyCounted = false;
      for (int j = 0; j < activeNodeCount; j++) {
        if (activeNodes[j].equals(nodeIdStr)) {
          alreadyCounted = true;
          break;
        }
      }
      
      // Add to active nodes if not already counted
      if (!alreadyCounted && activeNodeCount < 20) {
        activeNodes[activeNodeCount] = nodeIdStr;
        activeNodeCount++;
      }
    }
  }
  
  return activeNodeCount;
}

