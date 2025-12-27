import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/sensor_providers.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  static void startMonitoring(WidgetRef ref) {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      ref.read(connectivityProvider.notifier).state = hasConnection;
    });

    // Check initial connectivity
    _connectivity.checkConnectivity().then((results) {
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      ref.read(connectivityProvider.notifier).state = hasConnection;
    });
  }

  static void stopMonitoring() {
    _subscription?.cancel();
    _subscription = null;
  }
}

