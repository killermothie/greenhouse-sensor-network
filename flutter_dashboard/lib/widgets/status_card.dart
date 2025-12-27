import 'package:flutter/material.dart';
import '../models/sensor_data.dart';
import '../services/api_service.dart' show BackendConnectionState;

class StatusCard extends StatelessWidget {
  final SystemStatus status;
  final BackendConnectionState connectionState;
  final GatewayStatus? gatewayStatus;

  const StatusCard({
    super.key,
    required this.status,
    required this.connectionState,
    this.gatewayStatus,
  });

  String _formatUptime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

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

  String _getConnectionStateText() {
    switch (connectionState) {
      case BackendConnectionState.online:
        return 'ONLINE';
      case BackendConnectionState.offline:
        return 'OFFLINE';
      case BackendConnectionState.gatewayOnly:
        return 'GATEWAY-ONLY';
    }
  }

  Color _getConnectionStateColor() {
    switch (connectionState) {
      case BackendConnectionState.online:
        return Colors.green;
      case BackendConnectionState.offline:
        return Colors.red;
      case BackendConnectionState.gatewayOnly:
        return Colors.orange;
    }
  }

  IconData _getConnectionStateIcon() {
    switch (connectionState) {
      case BackendConnectionState.online:
        return Icons.cloud_done;
      case BackendConnectionState.offline:
        return Icons.cloud_off;
      case BackendConnectionState.gatewayOnly:
        return Icons.router;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = connectionState == BackendConnectionState.offline;
    final connectionColor = _getConnectionStateColor();
    final connectionIcon = _getConnectionStateIcon();
    final connectionText = _getConnectionStateText();
    final theme = Theme.of(context);

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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: connectionColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: connectionColor.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.monitor_heart,
                          color: connectionColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'System Status',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  // Connection State Banner (Top Right)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: connectionColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: connectionColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(connectionIcon, color: connectionColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          connectionText,
                          style: TextStyle(
                            color: connectionColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
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
              // Stats Grid
              _buildStatusRow(
                context,
                'Network Mode',
                connectionState == BackendConnectionState.online
                    ? 'STA'
                    : 'AP',
                connectionState == BackendConnectionState.gatewayOnly
                    ? Icons.wifi_tethering
                    : Icons.wifi,
                valueColor: connectionState == BackendConnectionState.online
                    ? Colors.greenAccent
                    : (connectionState == BackendConnectionState.gatewayOnly
                        ? Colors.orangeAccent
                        : Colors.redAccent),
              ),
              const SizedBox(height: 12),
              _buildStatusRow(
                context,
                'Active Nodes',
                gatewayStatus?.activeNodeCount != null
                    ? '${gatewayStatus!.activeNodeCount}'
                    : '${status.nodesActive}',
                Icons.device_hub,
                valueColor: Colors.blueAccent,
              ),
              const SizedBox(height: 12),
              _buildStatusRow(
                context,
                'Uptime',
                _formatUptime(status.systemUptimeSeconds),
                Icons.timer,
              ),
              const SizedBox(height: 12),
              _buildStatusRow(
                context,
                'Gateway IP',
                (status.gatewayIp != null && status.gatewayIp!.isNotEmpty && status.gatewayIp != '0.0.0.0')
                    ? status.gatewayIp!
                    : 'Not connected',
                Icons.router,
                valueColor: (status.gatewayIp != null && status.gatewayIp!.isNotEmpty && status.gatewayIp != '0.0.0.0')
                    ? Colors.greenAccent
                    : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
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

  Widget _buildStatusRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
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
}
