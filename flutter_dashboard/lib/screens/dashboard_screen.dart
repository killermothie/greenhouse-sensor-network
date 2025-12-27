import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sensor_providers.dart';
import '../widgets/dashboard_carousel.dart';
import '../widgets/status_card.dart';
import '../widgets/ai_insights_card.dart';
import '../widgets/history_chart.dart';
import '../widgets/metric_tabs.dart';
import '../models/sensor_data.dart';
import '../services/connectivity_service.dart';
import '../services/api_service.dart' show ApiService, BackendConnectionState;
import 'history_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _refreshTimer;
  int _selectedMetricIndex = 0;
  DateTime _selectedDate = DateTime.now();
  final GlobalKey _dateKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshAll();
    });
    // Start connectivity monitoring
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConnectivityService.startMonitoring(ref);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    ConnectivityService.stopMonitoring();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    // weekday is 1-7 (Monday-Sunday), so subtract 1 for array index
    return '${weekdays[date.weekday - 1]}, ${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  void _showDateMenu(BuildContext context) {
    final RenderBox? renderBox = _dateKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    final List<DateTime> last7Days = List.generate(7, (index) {
      return DateTime.now().subtract(Duration(days: index));
    });

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 8,
        MediaQuery.of(context).size.width - offset.dx - size.width,
        MediaQuery.of(context).size.height - offset.dy - size.height - 8,
      ),
      color: const Color(0xFF1A3329),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      items: last7Days.map((date) {
        final isSelected = date.year == _selectedDate.year &&
            date.month == _selectedDate.month &&
            date.day == _selectedDate.day;
        return PopupMenuItem<DateTime>(
          value: date,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                if (isSelected)
                  const Icon(
                    Icons.check,
                    color: Color(0xFF8BC34A),
                    size: 18,
                  )
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? const Color(0xFF8BC34A) : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    ).then((selectedDate) {
      if (selectedDate != null) {
        // Navigate to history screen for the selected date
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => HistoryScreen(selectedDate: selectedDate),
          ),
        );
      }
    });
  }

  Future<void> _refreshAll() async {
    // Invalidate all providers to trigger refresh
    ref.invalidate(latestReadingProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(systemStatusProvider);
    ref.invalidate(aiInsightsProvider);
    // Invalidate new providers for enhanced insights
    ref.invalidate(aiInsightsLatestProvider);
    ref.invalidate(nodesStatusProvider);
    ref.invalidate(recommendationsProvider);
    ref.invalidate(systemHealthProvider);
    ref.invalidate(gatewayStatusProvider);
  }

  Future<void> _handleRefresh() async {
    await _refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final latestReading = ref.watch(latestReadingProvider);
    final history = ref.watch(historyProvider);
    final systemStatus = ref.watch(systemStatusProvider);
    final aiInsights = ref.watch(aiInsightsProvider);
    final viewMode = ref.watch(viewModeProvider);
    final isOnline = ref.watch(connectivityProvider);
    final connectionState = ApiService.connectionState;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(220),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0E221B),
                const Color(0xFF0E221B),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                children: [
                  const SizedBox(height: 16),
                  // Header with greeting
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Hello, ',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Farmers',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8BC34A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _showDateMenu(context),
                            child: Row(
                              key: _dateKey,
                              children: [
                                Text(
                                  _formatDate(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Notification icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Search bar
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3329),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF00E676)),
                        suffixIcon: Icon(Icons.mic, color: Colors.white.withOpacity(0.5)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Theme.of(context).colorScheme.primary,
          child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20.0, 0, 20.0, 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              // Section Title
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 4.0, 0, 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Overview',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 24.0),
                      child: systemStatus.when(
                        data: (status) {
                          // Use gateway active node count if available, otherwise use system status
                          return ref.watch(gatewayStatusProvider).when(
                            data: (gatewayStatus) {
                              final activeNodeCount = gatewayStatus?.activeNodeCount ?? status?.nodesActive ?? 0;
                              return Text(
                                '$activeNodeCount ${activeNodeCount == 1 ? 'Active node' : 'Active nodes'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              );
                            },
                            loading: () => Text(
                              status != null
                                  ? '${status.nodesActive} ${status.nodesActive == 1 ? 'Active node' : 'Active nodes'}'
                                  : '0 Active nodes',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            error: (_, __) => Text(
                              status != null
                                  ? '${status.nodesActive} ${status.nodesActive == 1 ? 'Active node' : 'Active nodes'}'
                                  : '0 Active nodes',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          );
                        },
                        loading: () => Text(
                          'Loading...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        error: (_, __) {
                          // Try to get from gateway even if system status fails
                          return ref.watch(gatewayStatusProvider).when(
                            data: (gatewayStatus) {
                              final activeNodeCount = gatewayStatus?.activeNodeCount ?? 0;
                              return Text(
                                '$activeNodeCount ${activeNodeCount == 1 ? 'Active node' : 'Active nodes'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              );
                            },
                            loading: () => Text(
                              '0 Active nodes',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            error: (_, __) => Text(
                              '0 Active nodes',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Gateway Status Card
              systemStatus.when(
                data: (status) => status != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Match the carousel card width: 95% of available width
                            final cardWidth = constraints.maxWidth * 0.95;
                            return SizedBox(
                              width: cardWidth,
                              child: ref.watch(gatewayStatusProvider).when(
                                data: (gatewayStatus) => StatusCard(
                                  status: status,
                                  connectionState: connectionState,
                                  gatewayStatus: gatewayStatus,
                                ),
                                loading: () => StatusCard(
                                  status: status,
                                  connectionState: connectionState,
                                ),
                                error: (_, __) => StatusCard(
                                  status: status,
                                  connectionState: connectionState,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),

              // View Mode: AI or Raw
              if (!viewMode) ...[
                // AI Insights Card (Prominent)
                aiInsights.when(
                  data: (insights) => insights != null
                      ? AIInsightsCard(insights: insights)
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),
              ],

              // Latest Sensor Data Carousel
              latestReading.when(
                data: (reading) => reading != null
                    ? DashboardCarousel(reading: reading)
                    : Card(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.sensors_off,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No sensor data available',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: Colors.red.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Error loading data',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Showing cached data if available',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Historical Charts
              history.when(
                data: (readings) {
                  if (readings.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final metrics = ['temperature', 'humidity', 'soil_moisture'];
                  final colors = [
                    Colors.red.shade400,
                    Colors.blue.shade400,
                    Colors.green.shade400,
                  ];
                  final metric = metrics[_selectedMetricIndex];
                  final color = colors[_selectedMetricIndex];

                  return Column(
                    children: [
                      MetricTabs(
                        selectedIndex: _selectedMetricIndex,
                        onTabChanged: (index) {
                          setState(() {
                            _selectedMetricIndex = index;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      HistoryChart(
                        readings: readings,
                        metric: metric,
                        color: color,
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Show AI Insights at bottom if in Raw mode
              if (viewMode) ...[
                const SizedBox(height: 20),
                aiInsights.when(
                  data: (insights) => insights != null
                      ? AIInsightsCard(insights: insights)
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionIndicator(BackendConnectionState state) {
    late IconData icon;
    late Color color;
    late String tooltip;
    
    switch (state) {
      case BackendConnectionState.online:
        icon = Icons.cloud_done;
        color = Colors.green.shade600;
        tooltip = 'Backend Online';
        break;
      case BackendConnectionState.offline:
        icon = Icons.cloud_off;
        color = Colors.red.shade400;
        tooltip = 'Backend Offline';
        break;
      case BackendConnectionState.gatewayOnly:
        icon = Icons.router;
        color = Colors.orange.shade600;
        tooltip = 'Gateway Only (No Backend)';
        break;
    }
    
    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}
