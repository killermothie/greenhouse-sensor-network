import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart' show LatestReading, HistoricalReading, SystemStatus, AIInsights, GatewayStatus, NetworkStatus, AIInsightsLatest, NodeStatus, Recommendation, SystemHealth;

/// Backend connection state enum
enum BackendConnectionState {
  online,      // Backend is reachable
  offline,      // No network connection
  gatewayOnly,  // Can reach gateway but not backend
}

class ApiService {
  static const String baseUrl = 'http://192.168.8.253:8000';
  static const Duration timeout = Duration(seconds: 5);
  static const Duration connectTimeout = Duration(seconds: 3);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(milliseconds: 500);
  
  // Gateway direct connection (for AP mode)
  static const List<String> gatewayIPs = [
    '192.168.4.1',    // Common ESP32 AP mode IP
    '192.168.1.1',    // Common router/gateway IP
    '192.168.0.1',    // Alternative common gateway IP
    '10.0.0.1',       // Alternative network range
  ];
  static String? _cachedGatewayIP;
  
  // Track connection state with stabilization
  static BackendConnectionState _connectionState = BackendConnectionState.offline;
  static DateTime? _lastSuccessfulConnection;
  static DateTime? _lastFailedConnection;
  static const Duration _stateStabilizationWindow = Duration(seconds: 3);
  static int _consecutiveFailures = 0;
  static const int _maxFailuresBeforeOffline = 3;
  
  static BackendConnectionState get connectionState {
    final now = DateTime.now();
    
    // If we had a successful connection recently (within stabilization window), stay online
    if (_lastSuccessfulConnection != null && 
        now.difference(_lastSuccessfulConnection!) < _stateStabilizationWindow) {
      return BackendConnectionState.online;
    }
    
    // Only show offline if we've had multiple consecutive failures
    // and it's been longer than the stabilization window since last success
    if (_consecutiveFailures >= _maxFailuresBeforeOffline) {
      if (_lastSuccessfulConnection == null || 
          now.difference(_lastSuccessfulConnection!) > _stateStabilizationWindow) {
        return BackendConnectionState.offline;
      }
    }
    
    return _connectionState;
  }
  
  /// Check if gateway is reachable directly
  static Future<bool> _checkGatewayReachable() async {
    try {
      final gatewayIP = await _detectGatewayIP();
      if (gatewayIP == null) return false;
      
      final testUrl = 'http://$gatewayIP/status';
      final response = await http.get(Uri.parse(testUrl)).timeout(
        const Duration(seconds: 2),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Perform HTTP request with retry logic and timeout handling
  static Future<http.Response?> _requestWithRetry(
    Future<http.Response> Function() requestFn, {
    int retries = maxRetries,
  }) async {
    bool requestSucceeded = false;
    
    for (int attempt = 0; attempt < retries; attempt++) {
      try {
        final response = await requestFn()
            .timeout(timeout, onTimeout: () {
          throw TimeoutException('Request timeout after ${timeout.inSeconds}s');
        });
        
        // Update connection state based on response
        if (response.statusCode == 200 || response.statusCode == 201) {
          _connectionState = BackendConnectionState.online;
          _lastSuccessfulConnection = DateTime.now();
          _consecutiveFailures = 0; // Reset failure count on success
          requestSucceeded = true;
        } else if (response.statusCode >= 400 && response.statusCode < 500) {
          // Client error - backend is reachable but request is invalid
          _connectionState = BackendConnectionState.online;
          _lastSuccessfulConnection = DateTime.now();
          _consecutiveFailures = 0; // Reset failure count on success
          requestSucceeded = true;
        }
        
        return response;
      } on TimeoutException catch (e) {
        // Don't update state during retries, only after all attempts fail
        if (attempt == retries - 1 && !requestSucceeded) {
          _lastFailedConnection = DateTime.now();
          _consecutiveFailures++;
          // Check if gateway is reachable (gateway-only mode)
          final gatewayReachable = await _checkGatewayReachable();
          if (gatewayReachable) {
            _connectionState = BackendConnectionState.gatewayOnly;
          } else if (_consecutiveFailures >= _maxFailuresBeforeOffline &&
              (_lastSuccessfulConnection == null || 
               DateTime.now().difference(_lastSuccessfulConnection!) > _stateStabilizationWindow)) {
            _connectionState = BackendConnectionState.offline;
          }
          return null;
        }
        // Wait before retry (non-blocking)
        await Future.delayed(retryDelay);
      } on SocketException catch (e) {
        // Don't update state during retries
        if (attempt == retries - 1 && !requestSucceeded) {
          _lastFailedConnection = DateTime.now();
          _consecutiveFailures++;
          // Check if gateway is reachable (gateway-only mode)
          final gatewayReachable = await _checkGatewayReachable();
          if (gatewayReachable) {
            _connectionState = BackendConnectionState.gatewayOnly;
          } else if (_consecutiveFailures >= _maxFailuresBeforeOffline &&
              (_lastSuccessfulConnection == null || 
               DateTime.now().difference(_lastSuccessfulConnection!) > _stateStabilizationWindow)) {
            _connectionState = BackendConnectionState.offline;
          }
          return null;
        }
        await Future.delayed(retryDelay);
      } catch (e) {
        // Don't update state during retries
        if (attempt == retries - 1 && !requestSucceeded) {
          _lastFailedConnection = DateTime.now();
          _consecutiveFailures++;
          // Check if gateway is reachable (gateway-only mode)
          final gatewayReachable = await _checkGatewayReachable();
          if (gatewayReachable) {
            _connectionState = BackendConnectionState.gatewayOnly;
          } else if (_consecutiveFailures >= _maxFailuresBeforeOffline &&
              (_lastSuccessfulConnection == null || 
               DateTime.now().difference(_lastSuccessfulConnection!) > _stateStabilizationWindow)) {
            _connectionState = BackendConnectionState.offline;
          }
          return null;
        }
        await Future.delayed(retryDelay);
      }
    }
    return null;
  }

  /// Fetch latest reading directly from gateway (for AP mode)
  static Future<LatestReading?> _fetchLatestReadingFromGateway() async {
    try {
      final gatewayIP = await _detectGatewayIP();
      if (gatewayIP == null) return null;
      
      final url = 'http://$gatewayIP/sensors/latest';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        // Map gateway response to LatestReading format
        return LatestReading(
          nodeId: jsonData['nodeId'] as String? ?? 'unknown',
          temperature: (jsonData['temperature'] as num?)?.toDouble() ?? 0.0,
          humidity: (jsonData['humidity'] as num?)?.toDouble() ?? 0.0,
          soilMoisture: (jsonData['soilMoisture'] as num?)?.toDouble() ?? 0.0,
          batteryLevel: jsonData['batteryLevel'] as int?,
          rssi: jsonData['rssi'] as int?,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            jsonData['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
          ),
          ageSeconds: jsonData['age_seconds'] as int? ?? 0,
        );
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch the latest sensor reading
  static Future<LatestReading?> fetchLatestReading() async {
    try {
      final response = await _requestWithRetry(() async {
        return await http.get(
          Uri.parse('$baseUrl/api/sensors/latest'),
          headers: {'Content-Type': 'application/json'},
        );
      });

      if (response == null) {
        // Try gateway direct connection if backend fails
        return await _fetchLatestReadingFromGateway();
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return LatestReading.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        // Try gateway direct connection
        return await _fetchLatestReadingFromGateway();
      }
      
      // Try gateway direct connection as fallback
      return await _fetchLatestReadingFromGateway();
    } catch (e) {
      // Try gateway direct connection as fallback
      return await _fetchLatestReadingFromGateway();
    }
  }

  /// Fetch system status directly from gateway (for AP mode)
  static Future<SystemStatus?> _fetchSystemStatusFromGateway() async {
    try {
      final gatewayIP = await _detectGatewayIP();
      if (gatewayIP == null) {
        print('Cannot fetch from gateway: IP not detected');
        return null;
      }
      
      // Fetch gateway status and nodes info
      final statusUrl = 'http://$gatewayIP/status';
      final nodesUrl = 'http://$gatewayIP/nodes';
      
      print('Fetching gateway status from: $statusUrl');
      print('Fetching nodes info from: $nodesUrl');
      
      final statusResponse = await http.get(
        Uri.parse(statusUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      final nodesResponse = await http.get(
        Uri.parse(nodesUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      if (statusResponse.statusCode == 200) {
        final statusData = json.decode(statusResponse.body) as Map<String, dynamic>;
        final nodesData = nodesResponse.statusCode == 200
            ? json.decode(nodesResponse.body) as Map<String, dynamic>
            : <String, dynamic>{};
        
        final activeNodes = nodesData['active_nodes'] as int? ?? 0;
        print('Gateway active nodes: $activeNodes');
        print('Gateway nodes data: $nodesData');
        
        // Get network mode and IP from status data
        final networkMode = statusData['network_mode'] as String? ?? 'UNKNOWN';
        String? gatewayIp = gatewayIP; // Default to detected IP
        
        // Try to get actual IP from network status endpoint
        try {
          final networkUrl = 'http://$gatewayIP/api/system/network';
          final networkResponse = await http.get(
            Uri.parse(networkUrl),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 2));
          
          if (networkResponse.statusCode == 200) {
            final networkData = json.decode(networkResponse.body) as Map<String, dynamic>;
            final ip = networkData['ip'] as String? ?? '';
            if (ip.isNotEmpty && ip != '0.0.0.0') {
              gatewayIp = ip;
            }
          }
        } catch (e) {
          // Use detected IP if network endpoint fails
          print('Could not fetch network details: $e');
        }
        
        // Map gateway response to SystemStatus format
        return SystemStatus(
          backend: 'offline',
          lastDataReceivedSeconds: null,
          totalMessages: 0,
          nodesActive: activeNodes,
          systemUptimeSeconds: (statusData['uptime_ms'] as int? ?? 0) ~/ 1000,
          gatewayIp: gatewayIp,
        );
      } else {
        print('Gateway status response code: ${statusResponse.statusCode}');
      }
      
      return null;
    } catch (e) {
      print('Error fetching from gateway: $e');
      return null;
    }
  }

  /// Fetch system status
  static Future<SystemStatus?> fetchSystemStatus() async {
    try {
      final response = await _requestWithRetry(() async {
        return await http.get(
          Uri.parse('$baseUrl/api/sensors/status'),
          headers: {'Content-Type': 'application/json'},
        );
      });

      if (response == null) {
        // Try gateway direct connection if backend fails
        return await _fetchSystemStatusFromGateway();
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return SystemStatus.fromJson(jsonData);
      }
      
      // Try gateway direct connection as fallback
      return await _fetchSystemStatusFromGateway();
    } catch (e) {
      // Try gateway direct connection as fallback
      return await _fetchSystemStatusFromGateway();
    }
  }

  /// Fetch AI insights
  static Future<AIInsights?> fetchAIInsights({String? nodeId}) async {
    try {
      final uri = nodeId != null
          ? Uri.parse('$baseUrl/api/ai/insights?node_id=$nodeId')
          : Uri.parse('$baseUrl/api/ai/insights');
      
      final response = await _requestWithRetry(() async {
        return await http.get(
          uri,
          headers: {'Content-Type': 'application/json'},
        );
      });

      if (response == null) return null;

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return AIInsights.fromJson(jsonData);
      }
      return null;
    } catch (e) {
      // Don't immediately set offline on catch - let _requestWithRetry handle it
      return null;
    }
  }

  /// Fetch gateway status directly from gateway (for AP mode)
  static Future<GatewayStatus?> _fetchGatewayStatusFromGateway(String gatewayId) async {
    try {
      final gatewayIP = await _detectGatewayIP();
      if (gatewayIP == null) return null;
      
      // Fetch status and nodes from gateway
      final statusUrl = 'http://$gatewayIP/status';
      final nodesUrl = 'http://$gatewayIP/nodes';
      
      final statusResponse = await http.get(
        Uri.parse(statusUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      final nodesResponse = await http.get(
        Uri.parse(nodesUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      if (statusResponse.statusCode == 200) {
        final statusData = json.decode(statusResponse.body) as Map<String, dynamic>;
        final nodesData = nodesResponse.statusCode == 200
            ? json.decode(nodesResponse.body) as Map<String, dynamic>
            : <String, dynamic>{};
        
        // Map gateway response to GatewayStatus format
        return GatewayStatus(
          gatewayId: gatewayId,
          name: 'Gateway $gatewayId',
          isOnline: statusData['backend_reachable'] as bool? ?? false,
          lastSeen: DateTime.now(),
          lastSeenSecondsAgo: 0,
          createdAt: DateTime.now(),
          activeNodeCount: nodesData['active_nodes'] as int?,
          networkMode: statusData['network_mode'] as String?,
        );
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch gateway status
  static Future<GatewayStatus?> fetchGatewayStatus(String gatewayId) async {
    try {
      final response = await _requestWithRetry(() async {
        return await http.get(
          Uri.parse('$baseUrl/api/gateway/status?gateway_id=$gatewayId'),
          headers: {'Content-Type': 'application/json'},
        );
      });

      if (response == null) {
        // Try gateway direct connection if backend fails
        return await _fetchGatewayStatusFromGateway(gatewayId);
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return GatewayStatus.fromJson(jsonData);
      }
      
      // Try gateway direct connection as fallback
      return await _fetchGatewayStatusFromGateway(gatewayId);
    } catch (e) {
      // Try gateway direct connection as fallback
      return await _fetchGatewayStatusFromGateway(gatewayId);
    }
  }

  /// Fetch historical data with optional node_id filter
  static Future<List<HistoricalReading>> fetchHistory({
    int hours = 24,
    String? nodeId,
    String? gatewayId,
  }) async {
    try {
      final queryParams = <String, String>{'hours': hours.toString()};
      if (nodeId != null) queryParams['node_id'] = nodeId;
      if (gatewayId != null) queryParams['gateway_id'] = gatewayId;
      
      final uri = Uri.parse('$baseUrl/api/sensors/history').replace(queryParameters: queryParams);
      
      final response = await _requestWithRetry(() async {
        return await http.get(
          uri,
          headers: {'Content-Type': 'application/json'},
        );
      });

      if (response == null) return [];

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final readings = jsonData['readings'] as List<dynamic>;
        return readings
            .map((e) => HistoricalReading.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      // Don't immediately set offline on catch - let _requestWithRetry handle it
      return [];
    }
  }

  /// Fetch historical data for a specific date
  /// Returns readings from the start of the date to the end of the date
  static Future<List<HistoricalReading>> fetchHistoryForDate(DateTime date) async {
    try {
      // Calculate hours from now to the start of the selected date
      final now = DateTime.now();
      final startOfDate = DateTime(date.year, date.month, date.day);
      final endOfDate = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      // If the date is in the future, return empty
      if (startOfDate.isAfter(now)) {
        return [];
      }
      
      // Calculate hours from now to the end of the selected date
      // We'll fetch enough hours to cover the entire day
      final hoursFromNow = now.difference(startOfDate).inHours;
      final hoursToFetch = hoursFromNow < 24 ? 24 : hoursFromNow + 1;
      
      // Fetch history and filter by date
      final allReadings = await fetchHistory(hours: hoursToFetch);
      
      // Filter readings to only include those from the selected date
      return allReadings.where((reading) {
        final readingDate = DateTime(
          reading.timestamp.year,
          reading.timestamp.month,
          reading.timestamp.day,
        );
        return readingDate.year == date.year &&
               readingDate.month == date.month &&
               readingDate.day == date.day;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Test if an IP is the gateway by checking /status endpoint
  static Future<bool> _testGatewayIP(String ip) async {
    try {
      final testUrl = 'http://$ip/status';
      final response = await http.get(Uri.parse(testUrl)).timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode == 200) {
        // Verify it's actually our gateway by checking response
        try {
          final jsonData = json.decode(response.body) as Map<String, dynamic>;
          // Check if response has gateway-like fields (network_mode, uptime_ms, etc.)
          if (jsonData.containsKey('network_mode') || jsonData.containsKey('uptime_ms')) {
            return true;
          }
        } catch (e) {
          // If JSON parsing fails, still consider it valid if status is 200
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Detect gateway IP by trying common AP IPs
  static Future<String?> _detectGatewayIP() async {
    // Try cached IP first
    if (_cachedGatewayIP != null) {
      if (await _testGatewayIP(_cachedGatewayIP!)) {
        print('Using cached gateway IP: $_cachedGatewayIP');
        return _cachedGatewayIP;
      } else {
        print('Cached gateway IP failed: $_cachedGatewayIP');
        _cachedGatewayIP = null;
      }
    }
    
    // Try to extract IP from baseUrl (might be on same network)
    try {
      final baseUri = Uri.parse(baseUrl);
      final baseIp = baseUri.host;
      if (baseIp.isNotEmpty && baseIp != 'localhost' && baseIp != '127.0.0.1') {
        print('Trying backend IP as potential gateway: $baseIp');
        if (await _testGatewayIP(baseIp)) {
          _cachedGatewayIP = baseIp;
          print('Gateway IP detected from backend URL: $baseIp');
          return baseIp;
        }
      }
    } catch (e) {
      print('Failed to test backend IP: $e');
    }
    
    // Try common gateway IPs (AP mode typically uses 192.168.4.1)
    print('Scanning for gateway IP...');
    for (final ip in gatewayIPs) {
      print('Trying gateway IP: $ip');
      if (await _testGatewayIP(ip)) {
        _cachedGatewayIP = ip;
        print('Gateway IP detected: $ip');
        return ip;
      }
    }
    
    // Also try to get IP from network status if available (via backend proxy)
    try {
      final networkStatus = await fetchGatewayNetworkStatus();
      if (networkStatus != null && networkStatus.ip != '0.0.0.0') {
        print('Trying IP from network status: ${networkStatus.ip}');
        if (await _testGatewayIP(networkStatus.ip)) {
          _cachedGatewayIP = networkStatus.ip;
          print('Gateway IP detected from network status: ${networkStatus.ip}');
          return networkStatus.ip;
        }
      }
    } catch (e) {
      print('Failed to get gateway IP from network status: $e');
    }
    
    print('Gateway IP detection failed - no gateway found after trying all IPs');
    return null;
  }

  /// Fetch network status from ESP32 gateway directly (for AP mode)
  static Future<NetworkStatus?> fetchGatewayNetworkStatusDirect() async {
    try {
      final gatewayIP = await _detectGatewayIP();
      if (gatewayIP == null) return null;
      
      final url = 'http://$gatewayIP/api/system/network';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return NetworkStatus.fromJson(jsonData);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch network status from ESP32 gateway via backend proxy
  /// Uses backend proxy to avoid emulator network limitations
  static Future<NetworkStatus?> fetchGatewayNetworkStatus() async {
    try {
      // First try direct connection (for AP mode)
      final directStatus = await fetchGatewayNetworkStatusDirect();
      if (directStatus != null) {
        return directStatus;
      }
      
      // Fallback to backend proxy
      final baseUri = Uri.parse(baseUrl);
      final baseIp = baseUri.host;
      
      final queryParams = <String, String>{};
      if (baseIp.isNotEmpty) {
        queryParams['gateway_ip'] = baseIp;
      }
      queryParams['gateway_id'] = 'gateway-01';
      
      final proxyUrl = Uri.parse(baseUrl).replace(
        path: '/api/sensors/network',
        queryParameters: queryParams,
      );
      
      final response = await _requestWithRetry(() async {
        return await http.get(
          proxyUrl,
          headers: {'Content-Type': 'application/json'},
        );
      });
      
      if (response != null && response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final networkStatus = NetworkStatus.fromJson(jsonData);
        
        if (networkStatus.mode == 'OFFLINE' || networkStatus.ip == '0.0.0.0') {
          return null;
        }
        
        return networkStatus;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch AI Insights Latest
  static Future<AIInsightsLatest?> fetchAIInsightsLatest() async {
    try {
      // Try the requested endpoint first, fallback to existing endpoint
      var uri = Uri.parse('$baseUrl/api/ai/insights/latest');
      var response = await _requestWithRetry(() async {
        return await http.get(uri, headers: {'Content-Type': 'application/json'});
      });

      // If that endpoint doesn't exist, use the existing insights endpoint
      if (response == null || response.statusCode == 404) {
        uri = Uri.parse('$baseUrl/api/ai/insights?minutes=5');
        response = await _requestWithRetry(() async {
          return await http.get(uri, headers: {'Content-Type': 'application/json'});
        });
      }

      if (response == null || response.statusCode != 200) return null;

      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      
      // Transform existing response to match new format if needed
      if (jsonData.containsKey('overall_risk_level')) {
        // Transform TrendInsightsResponse
        final riskLevel = jsonData['overall_risk_level'] as String? ?? 'LOW';
        final summary = jsonData['summary'] as String? ?? '';
        // Calculate health score based on risk level
        final healthScore = riskLevel == 'HIGH' ? 30 : riskLevel == 'MEDIUM' ? 60 : 90;
        
        return AIInsightsLatest(
          healthScore: healthScore,
          riskLevel: riskLevel,
          summary: summary,
        );
      } else {
        return AIInsightsLatest.fromJson(jsonData);
      }
    } catch (e) {
      return null;
    }
  }

  /// Fetch node status directly from gateway (for AP mode)
  static Future<List<NodeStatus>> _fetchNodesStatusFromGateway() async {
    try {
      final gatewayIP = await _detectGatewayIP();
      if (gatewayIP == null) return [];
      
      // Fetch latest sensor reading from gateway
      final latestUrl = 'http://$gatewayIP/sensors/latest';
      final response = await http.get(
        Uri.parse(latestUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        
        // Skip gateway node
        final nodeId = jsonData['nodeId'] as String? ?? '';
        if (nodeId.startsWith('gateway-') || nodeId == 'gateway-01') {
          return [];
        }
        
        // Create NodeStatus from latest reading
        final timestamp = jsonData['timestamp'] as int? ?? 0;
        final ageSeconds = jsonData['age_seconds'] as int? ?? 999999;
        final isOnline = ageSeconds < 300; // Online if data is less than 5 minutes old
        
        return [
          NodeStatus(
            nodeId: nodeId,
            isOnline: isOnline,
            rssi: jsonData['rssi'] as int?,
            batteryPercentage: jsonData['batteryLevel'] as int?,
            lastSeen: timestamp > 0 
                ? DateTime.fromMillisecondsSinceEpoch(timestamp)
                : DateTime.now().subtract(Duration(seconds: ageSeconds)),
          ),
        ];
      }
      
      return [];
    } catch (e) {
      print('Error fetching nodes from gateway: $e');
      return [];
    }
  }

  /// Fetch Node Status
  static Future<List<NodeStatus>> fetchNodesStatus() async {
    try {
      var uri = Uri.parse('$baseUrl/api/nodes/status');
      var response = await _requestWithRetry(() async {
        return await http.get(uri, headers: {'Content-Type': 'application/json'});
      });

      // If endpoint doesn't exist or backend fails, try gateway direct connection
      if (response == null || response.statusCode == 404) {
        // Try gateway direct connection first
        final gatewayNodes = await _fetchNodesStatusFromGateway();
        if (gatewayNodes.isNotEmpty) {
          return gatewayNodes;
        }
        
        // Fallback: derive from system status and latest readings
        final latestReading = await fetchLatestReading();
        if (latestReading != null) {
          // Skip gateway node
          if (latestReading.nodeId.startsWith('gateway-') || latestReading.nodeId == 'gateway-01') {
            return [];
          }
          
          return [
            NodeStatus(
              nodeId: latestReading.nodeId,
              isOnline: latestReading.ageSeconds < 300,
              rssi: latestReading.rssi,
              batteryPercentage: latestReading.batteryLevel,
              lastSeen: latestReading.timestamp,
            ),
          ];
        }
        return [];
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData is List) {
          return (jsonData as List<dynamic>)
              .map((e) => NodeStatus.fromJson(e as Map<String, dynamic>))
              .toList();
        } else if (jsonData is Map && jsonData.containsKey('nodes')) {
          return (jsonData['nodes'] as List<dynamic>)
              .map((e) => NodeStatus.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      
      // Try gateway direct connection as fallback
      return await _fetchNodesStatusFromGateway();
    } catch (e) {
      // Try gateway direct connection as fallback
      return await _fetchNodesStatusFromGateway();
    }
  }

  /// Fetch Recommendations
  static Future<List<Recommendation>> fetchRecommendations() async {
    try {
      var uri = Uri.parse('$baseUrl/api/ai/recommendations');
      var response = await _requestWithRetry(() async {
        return await http.get(uri, headers: {'Content-Type': 'application/json'});
      });

      // If endpoint doesn't exist, extract from AI insights
      if (response == null || response.statusCode == 404) {
        final insights = await fetchAIInsights();
        if (insights != null && insights.recommendations.isNotEmpty) {
          // Determine priority based on status
          final priority = insights.isCritical ? 'HIGH' : insights.isWarning ? 'MEDIUM' : 'LOW';
          return insights.recommendations
              .map((rec) => Recommendation(text: rec, priority: priority))
              .toList();
        }
        return [];
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData is List) {
          return (jsonData as List<dynamic>)
              .map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
              .toList();
        } else if (jsonData is Map && jsonData.containsKey('recommendations')) {
          return (jsonData['recommendations'] as List<dynamic>)
              .map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Fetch System Health
  static Future<SystemHealth?> fetchSystemHealth() async {
    try {
      var uri = Uri.parse('$baseUrl/api/system/health');
      var response = await _requestWithRetry(() async {
        return await http.get(uri, headers: {'Content-Type': 'application/json'});
      });

      // If endpoint doesn't exist, combine system status and network status
      if (response == null || response.statusCode == 404) {
        final systemStatus = await fetchSystemStatus();
        final networkStatus = await fetchGatewayNetworkStatus();
        
        if (systemStatus != null) {
          return SystemHealth(
            gatewayStatus: systemStatus.isOnline ? 'ONLINE' : 'OFFLINE',
            networkMode: networkStatus?.mode ?? 'STA',
            gatewayIp: networkStatus?.ip ?? systemStatus.gatewayIp,
            backendConnectivity: systemStatus.isOnline,
            bufferedDataCount: 0, // Not available from system status
            uptimeSeconds: systemStatus.systemUptimeSeconds,
          );
        }
        return null;
      }

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        return SystemHealth.fromJson(jsonData);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
