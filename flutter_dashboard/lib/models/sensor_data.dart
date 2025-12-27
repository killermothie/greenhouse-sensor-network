/// Models for sensor data from the backend API
import 'package:flutter/material.dart';

class LatestReading {
  final String nodeId;
  final double temperature;
  final double humidity;
  final double soilMoisture;
  final int? batteryLevel;
  final int? rssi;
  final DateTime timestamp;
  final int ageSeconds;

  LatestReading({
    required this.nodeId,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    this.batteryLevel,
    this.rssi,
    required this.timestamp,
    required this.ageSeconds,
  });

  factory LatestReading.fromJson(Map<String, dynamic> json) {
    return LatestReading(
      nodeId: json['node_id'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      soilMoisture: (json['soil_moisture'] as num).toDouble(),
      batteryLevel: json['battery_level'] as int?,
      rssi: json['rssi'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      ageSeconds: json['age_seconds'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'node_id': nodeId,
      'temperature': temperature,
      'humidity': humidity,
      'soil_moisture': soilMoisture,
      'battery_level': batteryLevel,
      'rssi': rssi,
      'timestamp': timestamp.toIso8601String(),
      'age_seconds': ageSeconds,
    };
  }
}

class HistoricalReading {
  final int id;
  final String nodeId;
  final String gatewayId;
  final double temperature;
  final double humidity;
  final double soilMoisture;
  final int? batteryLevel;
  final int? rssi;
  final DateTime timestamp;

  HistoricalReading({
    required this.id,
    required this.nodeId,
    required this.gatewayId,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    this.batteryLevel,
    this.rssi,
    required this.timestamp,
  });

  factory HistoricalReading.fromJson(Map<String, dynamic> json) {
    return HistoricalReading(
      id: json['id'] as int,
      nodeId: json['node_id'] as String,
      gatewayId: json['gateway_id'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      soilMoisture: (json['soil_moisture'] as num).toDouble(),
      batteryLevel: json['battery_level'] as int?,
      rssi: json['rssi'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'gateway_id': gatewayId,
      'temperature': temperature,
      'humidity': humidity,
      'soil_moisture': soilMoisture,
      'battery_level': batteryLevel,
      'rssi': rssi,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class GatewayStatus {
  final String gatewayId;
  final String? name;
  final bool isOnline;
  final DateTime lastSeen;
  final int lastSeenSecondsAgo;
  final DateTime createdAt;
  final int? activeNodeCount;
  final String? networkMode;

  GatewayStatus({
    required this.gatewayId,
    this.name,
    required this.isOnline,
    required this.lastSeen,
    required this.lastSeenSecondsAgo,
    required this.createdAt,
    this.activeNodeCount,
    this.networkMode,
  });

  factory GatewayStatus.fromJson(Map<String, dynamic> json) {
    return GatewayStatus(
      gatewayId: json['gateway_id'] as String,
      name: json['name'] as String?,
      isOnline: json['is_online'] as bool,
      lastSeen: DateTime.parse(json['last_seen'] as String),
      lastSeenSecondsAgo: json['last_seen_seconds_ago'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      activeNodeCount: json['active_node_count'] as int?,
      networkMode: json['network_mode'] as String?,
    );
  }
}

class SystemStatus {
  final String backend;
  final int? lastDataReceivedSeconds;
  final int totalMessages;
  final int nodesActive;
  final int systemUptimeSeconds;
  final String? gatewayIp;

  SystemStatus({
    required this.backend,
    this.lastDataReceivedSeconds,
    required this.totalMessages,
    required this.nodesActive,
    required this.systemUptimeSeconds,
    this.gatewayIp,
  });

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    return SystemStatus(
      backend: json['backend'] as String,
      lastDataReceivedSeconds: json['last_data_received_seconds'] as int?,
      totalMessages: json['total_messages'] as int,
      nodesActive: json['nodes_active'] as int,
      systemUptimeSeconds: json['system_uptime_seconds'] as int,
      gatewayIp: json['gateway_ip'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backend': backend,
      'last_data_received_seconds': lastDataReceivedSeconds,
      'total_messages': totalMessages,
      'nodes_active': nodesActive,
      'system_uptime_seconds': systemUptimeSeconds,
      'gateway_ip': gatewayIp,
    };
  }

  bool get isOnline => backend == 'online';
}

class AIInsights {
  final String status;
  final String summary;
  final List<String> recommendations;
  final double confidence;

  AIInsights({
    required this.status,
    required this.summary,
    required this.recommendations,
    required this.confidence,
  });

  factory AIInsights.fromJson(Map<String, dynamic> json) {
    return AIInsights(
      status: json['status'] as String,
      summary: json['summary'] as String,
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'summary': summary,
      'recommendations': recommendations,
      'confidence': confidence,
    };
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'normal':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  bool get isCritical => status.toLowerCase() == 'critical';
  bool get isWarning => status.toLowerCase() == 'warning';
}

class NetworkStatus {
  final String mode;
  final String ip;
  final String ssid;
  final String? gateway;
  final int? clients;

  NetworkStatus({
    required this.mode,
    required this.ip,
    required this.ssid,
    this.gateway,
    this.clients,
  });

  factory NetworkStatus.fromJson(Map<String, dynamic> json) {
    return NetworkStatus(
      mode: json['mode'] as String,
      ip: json['ip'] as String,
      ssid: json['ssid'] as String,
      gateway: json['gateway'] as String?,
      clients: json['clients'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'ip': ip,
      'ssid': ssid,
      if (gateway != null) 'gateway': gateway,
      if (clients != null) 'clients': clients,
    };
  }
}

// AI Insights Latest Response
class AIInsightsLatest {
  final int healthScore; // 0-100
  final String riskLevel; // LOW, MEDIUM, HIGH
  final String summary; // 1-2 lines

  AIInsightsLatest({
    required this.healthScore,
    required this.riskLevel,
    required this.summary,
  });

  factory AIInsightsLatest.fromJson(Map<String, dynamic> json) {
    return AIInsightsLatest(
      healthScore: json['health_score'] as int? ?? json['healthScore'] as int? ?? 0,
      riskLevel: json['risk_level'] as String? ?? json['riskLevel'] as String? ?? 'LOW',
      summary: json['summary'] as String? ?? '',
    );
  }

  Color get riskColor {
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

// Node Status
class NodeStatus {
  final String nodeId;
  final bool isOnline;
  final int? rssi;
  final int? batteryPercentage;
  final DateTime? lastSeen;

  NodeStatus({
    required this.nodeId,
    required this.isOnline,
    this.rssi,
    this.batteryPercentage,
    this.lastSeen,
  });

  factory NodeStatus.fromJson(Map<String, dynamic> json) {
    return NodeStatus(
      nodeId: json['node_id'] as String? ?? json['nodeId'] as String,
      isOnline: json['is_online'] as bool? ?? json['isOnline'] as bool? ?? false,
      rssi: json['rssi'] as int?,
      batteryPercentage: json['battery_percentage'] as int? ?? json['batteryPercentage'] as int? ?? json['battery_level'] as int?,
      lastSeen: json['last_seen'] != null 
          ? DateTime.parse(json['last_seen'] as String)
          : json['lastSeen'] != null
              ? DateTime.parse(json['lastSeen'] as String)
              : null,
    );
  }

  int get minutesSinceLastSeen {
    if (lastSeen == null) return 999;
    return DateTime.now().difference(lastSeen!).inMinutes;
  }

  bool get isOfflineTooLong => !isOnline && minutesSinceLastSeen > 5;
}

// Recommendations Response
class Recommendation {
  final String text;
  final String priority; // LOW, MEDIUM, HIGH

  Recommendation({
    required this.text,
    required this.priority,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      text: json['text'] as String? ?? json['recommendation'] as String? ?? '',
      priority: json['priority'] as String? ?? 'LOW',
    );
  }

  Color get priorityColor {
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

// System Health Response
class SystemHealth {
  final String gatewayStatus; // ONLINE, OFFLINE
  final String networkMode; // STA, AP
  final String? gatewayIp;
  final bool backendConnectivity;
  final int bufferedDataCount;
  final int uptimeSeconds;

  SystemHealth({
    required this.gatewayStatus,
    required this.networkMode,
    this.gatewayIp,
    required this.backendConnectivity,
    required this.bufferedDataCount,
    required this.uptimeSeconds,
  });

  factory SystemHealth.fromJson(Map<String, dynamic> json) {
    return SystemHealth(
      gatewayStatus: json['gateway_status'] as String? ?? json['gatewayStatus'] as String? ?? json['backend'] as String? ?? 'OFFLINE',
      networkMode: json['network_mode'] as String? ?? json['networkMode'] as String? ?? 'STA',
      gatewayIp: json['gateway_ip'] as String? ?? json['gatewayIp'] as String?,
      backendConnectivity: json['backend_connectivity'] as bool? ?? json['backendConnectivity'] as bool? ?? (json['backend'] == 'online'),
      bufferedDataCount: json['buffered_data_count'] as int? ?? json['bufferedDataCount'] as int? ?? json['buffer_count'] as int? ?? 0,
      uptimeSeconds: json['uptime_seconds'] as int? ?? json['uptimeSeconds'] as int? ?? json['system_uptime_seconds'] as int? ?? 0,
    );
  }

  bool get isGatewayOnline => gatewayStatus.toUpperCase() == 'ONLINE';
  Color get gatewayStatusColor => isGatewayOnline ? Colors.green : Colors.red;
  Color get backendStatusColor => backendConnectivity ? Colors.green : Colors.red;
}
