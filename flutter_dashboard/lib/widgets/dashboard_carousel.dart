import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sensor_data.dart' show LatestReading;
import '../providers/sensor_providers.dart';
import 'carousel_cards/latest_sensor_data_card.dart';
import 'carousel_cards/ai_insights_carousel_card.dart';
import 'carousel_cards/node_insights_carousel_card.dart';
import 'carousel_cards/system_health_carousel_card.dart';
import 'carousel_cards/recommendations_carousel_card.dart';

class DashboardCarousel extends ConsumerStatefulWidget {
  final LatestReading reading;

  const DashboardCarousel({super.key, required this.reading});

  @override
  ConsumerState<DashboardCarousel> createState() => _DashboardCarouselState();
}

class _DashboardCarouselState extends ConsumerState<DashboardCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  static const int _totalPages = 5;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.95);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 500, // Fixed height for consistency
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _totalPages,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildPage(index),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildPageIndicator(),
      ],
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return LatestSensorDataCard(reading: widget.reading);
      case 1:
        return const AIInsightsCarouselCard();
      case 2:
        return const NodeInsightsCarouselCard();
      case 3:
        return const SystemHealthCarouselCard();
      case 4:
        return const RecommendationsCarouselCard();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _totalPages,
        (index) => _buildDot(index),
      ),
    );
  }

  Widget _buildDot(int index) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8.0,
      width: isActive ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4.0),
      ),
    );
  }
}

