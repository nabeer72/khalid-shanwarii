import 'package:flutter/foundation.dart';

class SyncService {
  // Singleton instance
  static final SyncService _instance = SyncService._internal();

  factory SyncService() {
    return _instance;
  }

  SyncService._internal();
  
  bool get isSyncing => false;
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier(false);
  
  String getLastSyncTime() {
    return 'Never';
  }

  Future<dynamic> syncPull({bool forceFull = false, bool saveTimestamp = true}) async {
    // Offline mode: No remote sync.
    return null;
  }

  Future<dynamic> syncPush() async {
    // Offline mode: No remote sync.
    return null;
  }

  void triggerDebouncedSync({int delayMs = 2000}) {
    // Offline mode: No remote sync.
  }

  Future<dynamic> searchOnline(String endpoint, String query) async {
    return [];
  }

  Future<void> logout() async {}

  Future<void> syncAll() async {}

  Future<bool> hasUnsyncedData() async {
    return false;
  }
}
