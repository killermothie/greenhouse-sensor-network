import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sensor_data.dart' show NodeStatus;
import '../../providers/sensor_providers.dart';

class NodeInsightsCarouselCard extends ConsumerWidget {
  const NodeInsightsCarouselCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final nodesStatus = ref.watch(nodesStatusProvider);

    return Card(
      elevation: 2,
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
                      color: Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.device_hub,
                      color: Colors.blueAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Node Insights',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, color: Colors.white10),
              const SizedBox(height: 20),
              Expanded(
                child: nodesStatus.when(
                  data: (nodes) => nodes.isNotEmpty
                      ? _buildNodesList(context, nodes)
                      : _buildEmptyState(context, 'No node data available'),
                  loading: () => _buildLoadingState(context),
                  error: (_, __) => _buildEmptyState(context, 'Error loading node status'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNodesList(BuildContext context, List<NodeStatus> nodes) {
    return ListView.builder(
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
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
      },
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

  Widget _buildEmptyState(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
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

  Widget _buildLoadingState(BuildContext context) {
    return const SizedBox.shrink();
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

