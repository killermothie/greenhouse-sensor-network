import 'package:hive_flutter/hive_flutter.dart';
import '../models/sensor_data.dart';

class CacheService {
  static const String _latestReadingBox = 'latest_reading';
  static const String _aiInsightsBox = 'ai_insights';
  static const String _systemStatusBox = 'system_status';
  static const String _historyBox = 'history';
  static const String _lastSyncKey = 'last_sync';

  static Future<void> init() async {
    await Hive.initFlutter();
  }

  // Latest Reading Cache
  static Future<void> cacheLatestReading(LatestReading reading) async {
    final box = await Hive.openBox(_latestReadingBox);
    await box.put('latest', reading.toJson());
    await box.put(_lastSyncKey, DateTime.now().toIso8601String());
  }

  static Future<LatestReading?> getCachedLatestReading() async {
    final box = await Hive.openBox(_latestReadingBox);
    final data = box.get('latest');
    if (data == null) return null;
    return LatestReading.fromJson(Map<String, dynamic>.from(data));
  }

  // AI Insights Cache
  static Future<void> cacheAIInsights(AIInsights insights) async {
    final box = await Hive.openBox(_aiInsightsBox);
    await box.put('insights', insights.toJson());
  }

  static Future<AIInsights?> getCachedAIInsights() async {
    final box = await Hive.openBox(_aiInsightsBox);
    final data = box.get('insights');
    if (data == null) return null;
    return AIInsights.fromJson(Map<String, dynamic>.from(data));
  }

  // System Status Cache
  static Future<void> cacheSystemStatus(SystemStatus status) async {
    final box = await Hive.openBox(_systemStatusBox);
    await box.put('status', status.toJson());
  }

  static Future<SystemStatus?> getCachedSystemStatus() async {
    final box = await Hive.openBox(_systemStatusBox);
    final data = box.get('status');
    if (data == null) return null;
    return SystemStatus.fromJson(Map<String, dynamic>.from(data));
  }

  // History Cache
  static Future<void> cacheHistory(List<HistoricalReading> readings) async {
    final box = await Hive.openBox(_historyBox);
    final data = readings.map((r) => r.toJson()).toList();
    await box.put('history', data);
  }

  static Future<List<HistoricalReading>> getCachedHistory() async {
    final box = await Hive.openBox(_historyBox);
    final data = box.get('history');
    if (data == null) return [];
    return (data as List)
        .map((e) => HistoricalReading.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // Last Sync Time
  static Future<DateTime?> getLastSyncTime() async {
    final box = await Hive.openBox(_latestReadingBox);
    final timeStr = box.get(_lastSyncKey);
    if (timeStr == null) return null;
    return DateTime.parse(timeStr);
  }
}

