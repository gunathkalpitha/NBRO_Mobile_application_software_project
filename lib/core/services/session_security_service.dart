import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionSecuritySettings {
  final bool biometricEnabled;
  final bool staySignedInEnabled;
  final int staySignedInHours;

  const SessionSecuritySettings({
    required this.biometricEnabled,
    required this.staySignedInEnabled,
    required this.staySignedInHours,
  });
}

class SessionSecurityService {
  static const _kBiometricEnabled = 'security.biometric_enabled';
  static const _kStaySignedInEnabled = 'security.stay_signed_in_enabled';
  static const _kStaySignedInHours = 'security.stay_signed_in_hours';
  static const _kStaySignedInDaysLegacy = 'security.stay_signed_in_days';
  static const _kLastPasswordLoginAt = 'security.last_password_login_at';

  static final LocalAuthentication _localAuth = LocalAuthentication();

  static Future<SessionSecuritySettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyDays = prefs.getInt(_kStaySignedInDaysLegacy);
    final persistedHours = prefs.getInt(_kStaySignedInHours);

    final resolvedHours = persistedHours ??
        (legacyDays != null ? legacyDays * 24 : 2);

    return SessionSecuritySettings(
      biometricEnabled: prefs.getBool(_kBiometricEnabled) ?? false,
      staySignedInEnabled: prefs.getBool(_kStaySignedInEnabled) ?? true,
      staySignedInHours: resolvedHours,
    );
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricEnabled, enabled);
  }

  static Future<void> setStaySignedInEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStaySignedInEnabled, enabled);
  }

  static Future<void> setStaySignedInHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStaySignedInHours, hours);
  }

  static Future<void> recordPasswordLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastPasswordLoginAt, DateTime.now().toIso8601String());
  }

  static Future<bool> isSessionWithinAllowedPeriod() async {
    final settings = await getSettings();
    if (!settings.staySignedInEnabled) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLastPasswordLoginAt);
    if (raw == null || raw.isEmpty) {
      return true;
    }

    final lastLogin = DateTime.tryParse(raw);
    if (lastLogin == null) {
      return true;
    }

    final limit = lastLogin.add(Duration(hours: settings.staySignedInHours));
    return DateTime.now().isBefore(limit);
  }

  static Future<bool> canUseBiometric() async {
    if (kIsWeb) return false;

    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticateForUnlock() async {
    if (kIsWeb) return true;

    final settings = await getSettings();
    if (!settings.biometricEnabled) {
      return true;
    }

    final canUse = await canUseBiometric();
    if (!canUse) {
      return true;
    }

    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock NBRO Field Surveyor',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}