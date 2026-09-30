import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lightweight Native System Tray Welcome Notification Service
class WelcomeNotificationService {
  static const _channel = MethodChannel('com.nbro.app/notifications');

  /// Trigger System Tray Status Bar Notification upon login (e.g. "Welcome to NBRO", "Logged in as [Name] • [Role]")
  static Future<void> triggerWelcomeNotification({
    required BuildContext context,
    required String userName,
    required String role,
  }) async {
    final title = 'Welcome to NBRO';
    final message = 'Logged in as $userName • $role';

    try {
      await _channel.invokeMethod('showNotification', {
        'title': title,
        'message': message,
      });
    } catch (e) {
      debugPrint('[WelcomeNotificationService] System tray notification note: $e');
    }
  }
}
