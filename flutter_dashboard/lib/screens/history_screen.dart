import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sensor_data.dart';
import '../services/api_service.dart';
import '../widgets/history_chart.dart';
import '../widgets/metric_tabs.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  final DateTime selectedDate;

  const HistoryScreen({
    super.key,
    required this.selectedDate,
  });

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  int _selectedMetricIndex = 0;

  Future<List<HistoricalReading>> _fetchHistoryForDate() async {
    return await ApiService.fetchHistoryForDate(widget.selectedDate);
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${weekdays[date.weekday - 1]}, ${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E221B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              _formatDate(widget.selectedDate),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<HistoricalReading>>(
        future: _fetchHistoryForDate(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF8BC34A),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading history',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {});
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final readings = snapshot.data ?? [];

          if (readings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No data available for this date',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No sensor readings were recorded on ${_formatDate(widget.selectedDate)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Group readings by node
          final Map<String, List<HistoricalReading>> readingsByNode = {};
          for (var reading in readings) {
            if (!readingsByNode.containsKey(reading.nodeId)) {
              readingsByNode[reading.nodeId] = [];
            }
            readingsByNode[reading.nodeId]!.add(reading);
          }

          // Sort readings by timestamp
          for (var nodeReadings in readingsByNode.values) {
            nodeReadings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          }

          final metrics = ['temperature', 'humidity', 'soil_moisture'];
          final colors = [
            Colors.red.shade400,
            Colors.blue.shade400,
            Colors.green.shade400,
          ];
          final metric = metrics[_selectedMetricIndex];
          final color = colors[_selectedMetricIndex];

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            color: Theme.of(context).colorScheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3329),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem(
                              'Total Readings',
                              '${readings.length}',
                              Icons.sensors,
                              Colors.blue,
                            ),
                            _buildSummaryItem(
                              'Nodes',
                              '${readingsByNode.length}',
                              Icons.device_hub,
                              Colors.green,
                            ),
                            _buildSummaryItem(
                              'Time Range',
                              '${_formatTimeRange(readings)}',
                              Icons.access_time,
                              Colors.orange,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Metric Tabs
                  MetricTabs(
                    selectedIndex: _selectedMetricIndex,
                    onTabChanged: (index) {
                      setState(() {
                        _selectedMetricIndex = index;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Charts for each node
                  ...readingsByNode.entries.map((entry) {
                    final nodeId = entry.key;
                    final nodeReadings = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            'Node: $nodeId',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        HistoryChart(
                          readings: nodeReadings,
                          metric: metric,
                          color: color,
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }).toList(),

                  // Detailed readings list
                  const SizedBox(height: 8),
                  const Text(
                    'Detailed Readings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...readings.take(50).map((reading) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A3329),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                reading.nodeId,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _formatTime(reading.timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildReadingValue('Temp', '${reading.temperature.toStringAsFixed(1)}°C', Colors.red),
                              _buildReadingValue('Humidity', '${reading.humidity.toStringAsFixed(1)}%', Colors.blue),
                              _buildReadingValue('Soil', '${reading.soilMoisture.toStringAsFixed(1)}%', Colors.green),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  Widget _buildReadingValue(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatTimeRange(List<HistoricalReading> readings) {
    if (readings.isEmpty) return 'N/A';
    final sorted = List<HistoricalReading>.from(readings)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final first = sorted.first.timestamp;
    final last = sorted.last.timestamp;
    return '${_formatTime(first)} - ${_formatTime(last)}';
  }
}

