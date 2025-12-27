import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/cache_service.dart';
import 'services/notification_service.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for caching
  await CacheService.init();

  // Initialize notifications
  await NotificationService.initialize();

  runApp(
    const ProviderScope(
      child: GreenhouseDashboardApp(),
    ),
  );
}

class GreenhouseDashboardApp extends StatelessWidget {
  const GreenhouseDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Greenhouse Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor:
            const Color(0xFF050F0A), // Very dark jungle green
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E676), // Neon Green
          brightness: Brightness.dark,
          primary: const Color(0xFF00E676),
          secondary: const Color(0xFF69F0AE),
          tertiary: const Color(0xFF00B0FF), // Neon Blue for variety
          surface: const Color(0xFF0E221B),
          background: const Color(0xFF050F0A),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          color: const Color(0xFF0E221B), // Dark glassy surface
          margin: EdgeInsets.zero,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: GoogleFonts.outfit(
            // Switching to Outfit for a more tech feel
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: -1,
            color: Colors.white,
          ),
          headlineLarge: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
          headlineMedium: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
          titleLarge: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: Colors.white,
          ),
          titleMedium: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
          bodyLarge: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: Colors.white70,
            height: 1.5,
          ),
          bodyMedium: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Colors.white60,
            height: 1.5,
          ),
          labelLarge: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF00E676),
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF00E676),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  bool _isLoading = true;
  bool _showOnboarding = true;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    setState(() {
      _showOnboarding = !onboardingCompleted;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1B5E20),
        body: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );
    }

    return _showOnboarding ? const OnboardingScreen() : const MainNavigation();
  }
}
