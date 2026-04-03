import 'dart:async';
import 'dart:io';
import 'package:internet_connection_checker/internet_connection_checker.dart';

enum ConnectionStatus { online, offline, slow }

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._init();
  final InternetConnectionChecker _checker = InternetConnectionChecker.createInstance(
    checkInterval: const Duration(seconds: 20),
    checkTimeout: const Duration(seconds: 20),
  );

  ConnectivityService._init();

  Future<ConnectionStatus> getConnectionStatus() async {
    try {
      // Direct reachability check with 20s timeout
      bool hasConnection = await _checker.hasConnection.timeout(const Duration(seconds: 20));
      if (!hasConnection) return ConnectionStatus.offline;

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
