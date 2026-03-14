import 'dart:async';
import 'package:internet_connection_checker/internet_connection_checker.dart';

enum ConnectionStatus { online, offline, slow }

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._init();
  final InternetConnectionChecker _checker = InternetConnectionChecker.createInstance(
    checkInterval: const Duration(seconds: 5),
    checkTimeout: const Duration(seconds: 3),
  );

  ConnectivityService._init();

  Future<ConnectionStatus> getConnectionStatus() async {
    try {
      bool hasConnection = await _checker.hasConnection;
      if (!hasConnection) return ConnectionStatus.offline;

      // Check for "slow" connection by measuring latency to a reliable endpoint
      // If it takes more than 2 seconds, we consider it slow for the purpose of signup
      final stopwatch = Stopwatch()..start();
      await _checker.connectionStatus; // Ping-like check
      stopwatch.stop();

      if (stopwatch.elapsedMilliseconds > 2000) {
        return ConnectionStatus.slow;
      }

      return ConnectionStatus.online;
    } catch (_) {
      return ConnectionStatus.offline;
    }
  }

  Stream<ConnectionStatus> get onStatusChange => _checker.onStatusChange.map((status) {
        if (status == InternetConnectionStatus.connected) return ConnectionStatus.online;
        return ConnectionStatus.offline;
      });
}
