import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Network & Internet Reachability Monitoring Service (Native Mobile/Desktop)
class ConnectivityService {
  static ConnectivityService? _instance;
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  Timer? _pollingTimer;
  bool _isOnline = false;

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

  /// Verifies actual network connectivity with dual OS socket lookup & HTTP fallback
  Future<bool> checkActualConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _updateOnlineStatus(true);
        return true;
      }
    } catch (_) {}

    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 6));

      final online = response.statusCode >= 200 && response.statusCode < 500;
      _updateOnlineStatus(online);
      return online;
    } catch (_) {
      _updateOnlineStatus(false);
      return false;
    }
  }

  void _updateOnlineStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      _connectivityController.add(online);
      debugPrint('[ConnectivityServiceNative] Network status changed: online = $online');
    }
  }

  void dispose() {
    _pollingTimer?.cancel();
    _connectivityController.close();
  }
}
