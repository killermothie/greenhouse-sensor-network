import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sensor_data.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/notification_service.dart';

// Latest Reading Provider
final latestReadingProvider = FutureProvider<LatestReading?>((ref) async {
  // Try cache first
  final cached = await CacheService.getCachedLatestReading();
  if (cached != null) {
    // Load from API in background
    ApiService.fetchLatestReading().then((reading) async {
      if (reading != null) {
        await CacheService.cacheLatestReading(reading);
        ref.invalidateSelf();
      }
    }).catchError((_) {});
    return cached;
  }
  
  // Load from API
  final reading = await ApiService.fetchLatestReading();
  if (reading != null) {
    await CacheService.cacheLatestReading(reading);
  }
  return reading;
});

// History Provider
final historyProvider = FutureProvider<List<HistoricalReading>>((ref) async {
  // Try cache first
  final cached = await CacheService.getCachedHistory();
  if (cached.isNotEmpty) {
    // Load from API in background
    ApiService.fetchHistory(hours: 24).then((history) async {
      if (history.isNotEmpty) {
        await CacheService.cacheHistory(history);
        ref.invalidateSelf();
      }
    }).catchError((_) {});
    return cached;
  }
  
  // Load from API
  final history = await ApiService.fetchHistory(hours: 24);
  if (history.isNotEmpty) {
    await CacheService.cacheHistory(history);
  }
  return history;
});

// System Status Provider
final systemStatusProvider = FutureProvider<SystemStatus?>((ref) async {
  // Try cache first
  final cached = await CacheService.getCachedSystemStatus();
  if (cached != null) {
    // Load from API in background
    ApiService.fetchSystemStatus().then((status) async {
      if (status != null) {
        // Fetch gateway network status to get IP
        final networkStatus = await ApiService.fetchGatewayNetworkStatus();
        if (networkStatus != null) {
          // Always use ESP32's IP address (not router gateway)
          String? gatewayIp;
          if (networkStatus.ip != '0.0.0.0' && networkStatus.ip.isNotEmpty) {
            gatewayIp = networkStatus.ip; // ESP32's IP (STA or AP mode)
          }
          
          // Create updated status with gateway IP
          final updatedStatus = SystemStatus(
            backend: status.backend,
            lastDataReceivedSeconds: status.lastDataReceivedSeconds,
            totalMessages: status.totalMessages,
            nodesActive: status.nodesActive,
            systemUptimeSeconds: status.systemUptimeSeconds,
            gatewayIp: gatewayIp,
          );
          await CacheService.cacheSystemStatus(updatedStatus);
        } else {
          await CacheService.cacheSystemStatus(status);
        }
        ref.invalidateSelf();
      }
    }).catchError((_) {});
    return cached;
  }
  
  // Load from API
  final status = await ApiService.fetchSystemStatus();
  if (status != null) {
    // If status came from gateway (backend is offline), it already has gateway IP and active nodes
    // Otherwise, fetch gateway network status to get IP
    String? gatewayIp = status.gatewayIp;
    if (gatewayIp == null || gatewayIp == '0.0.0.0') {
      final networkStatus = await ApiService.fetchGatewayNetworkStatus();
      if (networkStatus != null) {
        // Always use ESP32's IP address (not router gateway)
        if (networkStatus.ip != '0.0.0.0' && networkStatus.ip.isNotEmpty) {
          gatewayIp = networkStatus.ip; // ESP32's IP (STA or AP mode)
        }
      }
    }
    
    // Create updated status with gateway IP (preserve active nodes from gateway if available)
    final updatedStatus = SystemStatus(
      backend: status.backend,
      lastDataReceivedSeconds: status.lastDataReceivedSeconds,
      totalMessages: status.totalMessages,
      nodesActive: status.nodesActive, // This will be from gateway if fetched from gateway
      systemUptimeSeconds: status.systemUptimeSeconds,
      gatewayIp: gatewayIp,
    );
    await CacheService.cacheSystemStatus(updatedStatus);
    return updatedStatus;
  }
  return status;
});

// AI Insights Provider
final aiInsightsProvider = FutureProvider<AIInsights?>((ref) async {
  // Try cache first
  final cached = await CacheService.getCachedAIInsights();
  if (cached != null) {
    // Load from API in background
    ApiService.fetchAIInsights().then((insights) async {
      if (insights != null) {
        await CacheService.cacheAIInsights(insights);
        // Show notification for critical alerts
        if (insights.isCritical || insights.isWarning) {
          await NotificationService.showCriticalAlert(insights);
        }
        ref.invalidateSelf();
      }
    }).catchError((_) {});
    return cached;
  }
  
  // Load from API
  final insights = await ApiService.fetchAIInsights();
  if (insights != null) {
    await CacheService.cacheAIInsights(insights);
    // Show notification for critical alerts
    if (insights.isCritical || insights.isWarning) {
      await NotificationService.showCriticalAlert(insights);
    }
  }
  return insights;
});

// View Mode Provider (Raw vs AI) - using Notifier (Riverpod 3.x)
class ViewModeNotifier extends Notifier<bool> {
  @override
  bool build() => false; // false = AI, true = Raw
}

final viewModeProvider = NotifierProvider<ViewModeNotifier, bool>(ViewModeNotifier.new);

// Connectivity Provider - using Notifier (Riverpod 3.x) - for device network connectivity
class ConnectivityNotifier extends Notifier<bool> {
  @override
  bool build() => true;
}

final connectivityProvider = NotifierProvider<ConnectivityNotifier, bool>(ConnectivityNotifier.new);

// Node-specific AI Insights Provider - takes nodeId as parameter
final nodeInsightsProvider = FutureProvider.family<AIInsights?, String>((ref, nodeId) async {
  try {
    return await ApiService.fetchAIInsights(nodeId: nodeId);
  } catch (e) {
    return null;
  }
});

// AI Insights Latest Provider
final aiInsightsLatestProvider = FutureProvider<AIInsightsLatest?>((ref) async {
  try {
    return await ApiService.fetchAIInsightsLatest();
  } catch (e) {
    return null;
  }
});

// Node Status Provider
final nodesStatusProvider = FutureProvider<List<NodeStatus>>((ref) async {
  try {
    return await ApiService.fetchNodesStatus();
  } catch (e) {
    return [];
  }
});

// Recommendations Provider
final recommendationsProvider = FutureProvider<List<Recommendation>>((ref) async {
  try {
    return await ApiService.fetchRecommendations();
  } catch (e) {
    return [];
  }
});

// System Health Provider
final systemHealthProvider = FutureProvider<SystemHealth?>((ref) async {
  try {
    return await ApiService.fetchSystemHealth();
  } catch (e) {
    return null;
  }
});

// Gateway Status Provider
final gatewayStatusProvider = FutureProvider<GatewayStatus?>((ref) async {
  try {
    // Default gateway ID
    return await ApiService.fetchGatewayStatus('gateway-01');
  } catch (e) {
    return null;
  }
});
