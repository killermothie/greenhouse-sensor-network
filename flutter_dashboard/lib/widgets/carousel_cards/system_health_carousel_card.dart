import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/sensor_data.dart' show SystemHealth;
import '../../providers/sensor_providers.dart';

class SystemHealthCarouselCard extends ConsumerWidget {
  const SystemHealthCarouselCard({super.key});

  String _formatUptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) return '${seconds ~/ 3600}h';
    return '${seconds ~/ 86400}d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final systemHealth = ref.watch(systemHealthProvider);

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
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.health_and_safety,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'System Health',
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
                child: systemHealth.when(
                  data: (health) => health != null
                      ? SingleChildScrollView(child: _buildHealthContent(context, health))
                      : _buildEmptyState(context, 'No system health data available'),
                  loading: () => _buildLoadingState(context),
                  error: (_, __) => _buildEmptyState(context, 'Error loading system health'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthContent(BuildContext context, SystemHealth health) {
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

  Widget _buildHealthRow(
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
}

