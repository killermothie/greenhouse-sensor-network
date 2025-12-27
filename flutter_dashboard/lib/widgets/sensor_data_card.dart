import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/sensor_data.dart' show LatestReading, AIInsightsLatest, NodeStatus, Recommendation, SystemHealth;
import '../providers/sensor_providers.dart';

class SensorDataCard extends ConsumerWidget {
  final LatestReading reading;

  const SensorDataCard({super.key, required this.reading});

  String _formatRecency(int totalSeconds) {
    if (totalSeconds < 60) {
      return '${totalSeconds}s ago';
    } else if (totalSeconds < 3600) {
      final m = totalSeconds ~/ 60;
      final s = totalSeconds % 60;
      return '${m}m ${s}s ago';
    } else {
      final h = totalSeconds ~/ 3600;
      final m = (totalSeconds % 3600) ~/ 60;
      return '${h}h ${m}m ago';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm:ss');
    final theme = Theme.of(context);
    final aiInsightsLatest = ref.watch(aiInsightsLatestProvider);
    final nodesStatus = ref.watch(nodesStatusProvider);
    final recommendations = ref.watch(recommendationsProvider);
    final systemHealth = ref.watch(systemHealthProvider);

    return Card(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.05),
              Colors.white.withOpacity(0.02),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.sensors,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Latest Sensor Data',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reading.nodeId,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, color: Colors.white10),
              const SizedBox(height: 20),
              // Main metrics in a grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Temperature',
                      '${reading.temperature.toStringAsFixed(1)}°C',
                      Icons.thermostat,
                      _getTemperatureColor(reading.temperature),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Humidity',
                      '${reading.humidity.toStringAsFixed(1)}%',
                      Icons.water_drop,
                      Colors.blueAccent, // Brighter blue for dark mode
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Soil Moisture',
                      '${reading.soilMoisture.toStringAsFixed(1)}%',
                      Icons.eco,
                      _getMoistureColor(reading.soilMoisture),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (reading.batteryLevel != null)
                    Expanded(
                      child: _buildMetricCard(
                        context,
                        'Battery',
                        '${reading.batteryLevel}%',
                        Icons.battery_charging_full,
                        _getBatteryColor(reading.batteryLevel!),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // Additional info
              if (reading.rssi != null) ...[
                _buildDataRow(
                  context,
                  'Signal Strength',
                  '${reading.rssi} dBm',
                  icon: Icons.signal_wifi_4_bar,
                  valueColor: _getRSSIColor(reading.rssi!),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(height: 1, color: Colors.white10),
              const SizedBox(height: 20),
              
              // AI Insights Latest Section
              _buildSectionHeader(context, 'AI Insights', Icons.psychology, theme.colorScheme.primary),
              const SizedBox(height: 12),
              aiInsightsLatest.when(
                data: (insights) => insights != null
                    ? _buildAIInsightsLatestSection(context, insights)
                    : _buildEmptySection(context, 'No AI insights available'),
                loading: () => _buildLoadingSection(context),
                error: (_, __) => _buildEmptySection(context, 'Error loading AI insights'),
              ),
              
              const SizedBox(height: 20),
              const Divider(height: 1, color: Colors.white10),
              const SizedBox(height: 20),
              
              // Node Status Section
              _buildSectionHeader(context, 'Node Insights', Icons.device_hub, Colors.blueAccent),
              const SizedBox(height: 12),
              nodesStatus.when(
                data: (nodes) => nodes.isNotEmpty
                    ? _buildNodeStatusSection(context, nodes)
                    : _buildEmptySection(context, 'No node data available'),
                loading: () => _buildLoadingSection(context),
                error: (_, __) => _buildEmptySection(context, 'Error loading node status'),
              ),
              
              const SizedBox(height: 20),
              const Divider(height: 1, color: Colors.white10),
              const SizedBox(height: 20),
              
              // Recommendations Section
              _buildSectionHeader(context, 'Recommendations', Icons.lightbulb_outline, Colors.amber),
              const SizedBox(height: 12),
              recommendations.when(
                data: (recs) => recs.isNotEmpty
                    ? _buildRecommendationsSection(context, recs)
                    : _buildEmptySection(context, 'No recommendations available'),
                loading: () => _buildLoadingSection(context),
                error: (_, __) => _buildEmptySection(context, 'Error loading recommendations'),
              ),
              
              const SizedBox(height: 20),
              const Divider(height: 1, color: Colors.white10),
              const SizedBox(height: 20),
              
              // System Health Section
              _buildSectionHeader(context, 'System Health', Icons.health_and_safety, Colors.green),
              const SizedBox(height: 12),
              systemHealth.when(
                data: (health) => health != null
                    ? _buildSystemHealthSection(context, health)
                    : _buildEmptySection(context, 'No system health data available'),
                loading: () => _buildLoadingSection(context),
                error: (_, __) => _buildEmptySection(context, 'Error loading system health'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
  
  Widget _buildAIInsightsLatestSection(BuildContext context, AIInsightsLatest insights) {
    final riskColor = insights.riskColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: riskColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: riskColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      insights.riskLevel == 'HIGH'
                          ? Icons.error
                          : insights.riskLevel == 'MEDIUM'
                              ? Icons.warning
                              : Icons.check_circle,
                      color: riskColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      insights.riskLevel,
                      style: TextStyle(
                        color: riskColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Health: ${insights.healthScore}/100',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insights.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildNodeStatusSection(BuildContext context, List<NodeStatus> nodes) {
    return Column(
      children: nodes.map((node) {
        final isOfflineTooLong = node.isOfflineTooLong;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOfflineTooLong ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.05),
              width: isOfflineTooLong ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: node.isOnline ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      node.nodeId,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    node.isOnline ? 'Online' : 'Offline',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: node.isOnline ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (node.rssi != null)
                _buildNodeInfoRow(context, 'RSSI', '${node.rssi} dBm', _getRSSIColor(node.rssi!)),
              if (node.rssi != null) const SizedBox(height: 8),
              if (node.batteryPercentage != null)
                _buildNodeInfoRow(context, 'Battery', '${node.batteryPercentage}%', _getBatteryColor(node.batteryPercentage!)),
              if (node.batteryPercentage != null) const SizedBox(height: 8),
              if (node.lastSeen != null)
                _buildNodeInfoRow(
                  context,
                  'Last Seen',
                  '${node.minutesSinceLastSeen}m ago',
                  node.isOfflineTooLong ? Colors.red : Colors.white70,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNodeInfoRow(BuildContext context, String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white60,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationsSection(BuildContext context, List<Recommendation> recommendations) {
    return Column(
      children: recommendations.map((rec) {
        final priorityColor = rec.priorityColor;
        final isHighPriority = rec.priority == 'HIGH';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: priorityColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: priorityColor.withOpacity(0.3),
              width: isHighPriority ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isHighPriority)
                Icon(
                  Icons.warning,
                  color: priorityColor,
                  size: 20,
                ),
              if (isHighPriority) const SizedBox(width: 12),
              Container(
                margin: EdgeInsets.only(top: isHighPriority ? 0 : 6),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: priorityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rec.priority,
                        style: TextStyle(
                          color: priorityColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildSystemHealthSection(BuildContext context, SystemHealth health) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildHealthRowWithIndicator(
            context,
            'Gateway Status',
            health.gatewayStatus,
            health.gatewayStatusColor,
          ),
          const SizedBox(height: 12),
          _buildHealthRow(context, 'Network Mode', health.networkMode, Colors.blue),
          const SizedBox(height: 12),
          if (health.gatewayIp != null)
            _buildHealthRow(context, 'Gateway IP', health.gatewayIp!, Colors.white70),
          if (health.gatewayIp != null) const SizedBox(height: 12),
          _buildHealthRowWithIndicator(
            context,
            'Backend Connectivity',
            health.backendConnectivity ? 'Connected' : 'Disconnected',
            health.backendStatusColor,
          ),
          const SizedBox(height: 12),
          _buildHealthRow(
            context,
            'Uptime',
            _formatUptime(health.uptimeSeconds),
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRowWithIndicator(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: valueColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildHealthRow(BuildContext context, String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptySection(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white38,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
  
  String _formatUptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) return '${seconds ~/ 3600}h';
    return '${seconds ~/ 86400}d';
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(
    BuildContext context,
    String label,
    String value, {
    IconData icon = Icons.info,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.white60),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor ?? Theme.of(context).colorScheme.primary,
              ),
        ),
      ],
    );
  }

  Color _getTemperatureColor(double temp) {
    if (temp > 35) return Colors.red;
    if (temp > 28) return Colors.orange;
    if (temp < 18) return Colors.blue;
    return Colors.green;
  }

  Color _getMoistureColor(double moisture) {
    if (moisture < 30) return Colors.red;
    if (moisture < 40) return Colors.orange;
    return Colors.green;
  }

  Color _getBatteryColor(int battery) {
    if (battery < 20) return Colors.red;
    if (battery < 50) return Colors.orange;
    return Colors.green;
  }

  Color _getRSSIColor(int rssi) {
    if (rssi > -50) return Colors.green;
    if (rssi > -70) return Colors.orange;
    return Colors.red;
  }
}
