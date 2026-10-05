import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Network & Internet Reachability Monitoring Service (Web)
class ConnectivityService {
  static ConnectivityService? _instance;
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  Timer? _pollingTimer;
  bool _isOnline = true;

  ConnectivityService._() {
    _startPolling();
  }

  static ConnectivityService get instance {
    _instance ??= ConnectivityService._();
    return _instance!;
  }

  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkActualConnectivity();
    });
    checkActualConnectivity();
  }

  Future<bool> checkActualConnectivity() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));

      final online = response.statusCode >= 200 && response.statusCode < 500;
      _updateOnlineStatus(online);
      return online;
    } catch (_) {
      _updateOnlineStatus(true);
      return true;
    }
  }

  void _updateOnlineStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      _connectivityController.add(online);
      debugPrint('[ConnectivityServiceWeb] Network status changed: online = $online');
    }
  }

  void dispose() {
    _pollingTimer?.cancel();
    _connectivityController.close();
  }
}
