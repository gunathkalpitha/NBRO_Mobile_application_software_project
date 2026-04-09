import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionSecuritySettings {
  final bool biometricEnabled;
  final bool staySignedInEnabled;
  final int staySignedInHours;
  final int appLockTimeoutMinutes;

  const SessionSecuritySettings({
    required this.biometricEnabled,
    required this.staySignedInEnabled,
    required this.staySignedInHours,
    required this.appLockTimeoutMinutes,
  });
}

class BiometricVerificationResult {
  final bool success;
  final String? code;
  final String? message;

  const BiometricVerificationResult.success()
      : success = true,
        code = null,
        message = null;

  const BiometricVerificationResult.failure({this.code, this.message})
      : success = false;
}

class SessionSecurityService {
  static const _kBiometricEnabled = 'security.biometric_enabled';
  static const _kAppLockTimeoutMinutes = 'security.app_lock_timeout_minutes';
  static const _kStaySignedInEnabled = 'security.stay_signed_in_enabled';
  static const _kStaySignedInHours = 'security.stay_signed_in_hours';
  static const _kStaySignedInDaysLegacy = 'security.stay_signed_in_days';
  static const _kLastPasswordLoginAt = 'security.last_password_login_at';
  static const _kLastBackgroundAt = 'security.last_backgrounded_at';

  static final LocalAuthentication _localAuth = LocalAuthentication();
  static Future<bool>? _ongoingUnlockRequest;
  static DateTime? _lastSuccessfulUnlockAt;
  static bool _isBiometricPromptActive = false;
  static DateTime? _lastBiometricPromptFinishedAt;

  static bool get isBiometricPromptActive => _isBiometricPromptActive;

  static Future<SessionSecuritySettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyDays = prefs.getInt(_kStaySignedInDaysLegacy);
    final persistedHours = prefs.getInt(_kStaySignedInHours);
    final persistedAppLockMinutes = prefs.getInt(_kAppLockTimeoutMinutes);

    final resolvedHours = persistedHours ??
        (legacyDays != null ? legacyDays * 24 : 2);
    final resolvedAppLockMinutes = persistedAppLockMinutes ?? 30;

    return SessionSecuritySettings(
      biometricEnabled: prefs.getBool(_kBiometricEnabled) ?? false,
      staySignedInEnabled: prefs.getBool(_kStaySignedInEnabled) ?? true,
      staySignedInHours: resolvedHours,
      appLockTimeoutMinutes: resolvedAppLockMinutes,
    );
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricEnabled, enabled);
  }

  static Future<void> setAppLockTimeoutMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAppLockTimeoutMinutes, minutes);
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

  static Future<bool> canUseFingerprint() async {
    if (kIsWeb) return false;

    try {
      final canUse = await canUseBiometric();
      if (!canUse) return false;

      final available = await _localAuth.getAvailableBiometrics();
      // Some Android devices report enrolled fingerprint as strong/weak
      // instead of explicit fingerprint.
      return available.contains(BiometricType.fingerprint) ||
          available.contains(BiometricType.strong) ||
          available.contains(BiometricType.weak);
    } catch (_) {
      return false;
    }
  }

  static Future<BiometricVerificationResult> verifyFingerprintForEnable() async {
    if (kIsWeb) {
      return const BiometricVerificationResult.failure(
        code: 'web_unsupported',
        message: 'Fingerprint unlock is not available on web.',
      );
    }

    final canUse = await canUseBiometric();
    if (!canUse) {
      return const BiometricVerificationResult.failure(
        code: 'not_available',
        message: 'Biometric authentication is not available on this device.',
      );
    }

    return _authenticateBiometricWithRetries(
      localizedReason: 'Verify fingerprint to enable app unlock',
      maxAttempts: 1,
    );
  }

  static Future<bool> authenticateForUnlock() async {
    final ongoing = _ongoingUnlockRequest;
    if (ongoing != null) {
      return ongoing;
    }

    final request = _authenticateForUnlockInternal();
    _ongoingUnlockRequest = request;
    try {
      return await request;
    } finally {
      _ongoingUnlockRequest = null;
    }
  }

  static Future<bool> _authenticateForUnlockInternal() async {
    if (kIsWeb) return true;

    final settings = await getSettings();
    if (!settings.biometricEnabled) {
      return true;
    }

    final canUse = await canUseBiometric();
    if (!canUse) {
      return true;
    }

    final result = await _authenticateBiometricWithRetries(
      localizedReason: 'Authenticate to unlock NBRO Field Surveyor',
      maxAttempts: 1,
    );
    return result.success;
  }

  static Future<void> markAppBackgrounded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastBackgroundAt, DateTime.now().toIso8601String());
  }

  static Future<bool> shouldRequireAppLock() async {
    if (kIsWeb) return false;

    if (_isBiometricPromptActive || _isRecentBiometricUiTransition()) {
      return false;
    }

    if (_justUnlockedRecently()) {
      return false;
    }

    final settings = await getSettings();
    if (!settings.biometricEnabled) {
      return false;
    }

    final lastBackgrounded = await _getLastBackgroundedAt();
    if (lastBackgrounded == null) {
      return false;
    }

    // Do not lock again for the same background event once user already unlocked.
    final lastUnlocked = _lastSuccessfulUnlockAt;
    if (lastUnlocked != null && !lastBackgrounded.isAfter(lastUnlocked)) {
      return false;
    }

    // If user selected "Immediate", require unlock whenever app re-enters foreground.
    if (settings.appLockTimeoutMinutes == 0) {
      return true;
    }

    final unlockAt = lastBackgrounded.add(
      Duration(minutes: settings.appLockTimeoutMinutes),
    );
    return DateTime.now().isAfter(unlockAt);
  }

  static Future<bool> shouldRequireAppLockOnLaunch() async {
    if (kIsWeb) return false;

    if (_isBiometricPromptActive || _isRecentBiometricUiTransition()) {
      return false;
    }

    if (_justUnlockedRecently()) {
      return false;
    }

    final settings = await getSettings();
    return settings.biometricEnabled;
  }

  static String _mapBiometricErrorMessage(String? code) {
    switch (code) {
      case 'notEnrolled':
      case 'NotEnrolled':
        return 'No fingerprint is enrolled on this device.';
      case 'lockout':
      case 'LockedOut':
      case 'permanentlyLockedOut':
      case 'PermanentlyLockedOut':
        return 'Fingerprint is temporarily locked on the device. Try again later or unlock the phone first.';
      case 'notAvailable':
      case 'NotAvailable':
        return 'Fingerprint authentication is blocked by device settings or policy.';
      case 'noBiometricHardware':
      case 'NoBiometricHardware':
        return 'This device does not support fingerprint authentication.';
      case 'passcodeNotSet':
      case 'PasscodeNotSet':
        return 'Set a screen lock on the device first, then add fingerprint.';
      case 'canceled':
      case 'Canceled':
        return 'Fingerprint prompt was canceled.';
      default:
        return 'Fingerprint verification failed.';
    }
  }

  static Future<BiometricVerificationResult> _authenticateBiometricWithRetries({
    required String localizedReason,
    required int maxAttempts,
  }) async {
    BiometricVerificationResult lastResult = const BiometricVerificationResult.failure(
      code: 'unknown_error',
      message: 'Fingerprint verification failed.',
    );

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        _isBiometricPromptActive = true;
        final authenticated = await _localAuth.authenticate(
          localizedReason: localizedReason,
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
        _isBiometricPromptActive = false;
        _lastBiometricPromptFinishedAt = DateTime.now();

        if (authenticated) {
          _lastSuccessfulUnlockAt = DateTime.now();
          return const BiometricVerificationResult.success();
        }

        lastResult = const BiometricVerificationResult.failure(
          code: 'canceled_or_failed',
          message: 'Fingerprint verification failed or was canceled.',
        );
      } on PlatformException catch (e) {
        _isBiometricPromptActive = false;
        _lastBiometricPromptFinishedAt = DateTime.now();
        final mappedMessage = _mapBiometricErrorMessage(e.code);
        lastResult = BiometricVerificationResult.failure(
          code: e.code,
          message: mappedMessage,
        );

        if (!_shouldRetryBiometricError(e.code)) {
          return lastResult;
        }
      } catch (_) {
        _isBiometricPromptActive = false;
        _lastBiometricPromptFinishedAt = DateTime.now();
        lastResult = const BiometricVerificationResult.failure(
          code: 'unknown_error',
          message: 'Fingerprint verification failed.',
        );
      }
    }

    return lastResult;
  }

  static bool _shouldRetryBiometricError(String? code) {
    switch (code) {
      case 'notEnrolled':
      case 'NotEnrolled':
      case 'notAvailable':
      case 'NotAvailable':
      case 'noBiometricHardware':
      case 'NoBiometricHardware':
      case 'passcodeNotSet':
      case 'PasscodeNotSet':
        return false;
      default:
        return true;
    }
  }

  static bool _justUnlockedRecently() {
    final last = _lastSuccessfulUnlockAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < const Duration(seconds: 3);
  }

  static bool _isRecentBiometricUiTransition() {
    final last = _lastBiometricPromptFinishedAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < const Duration(seconds: 2);
  }

  static Future<DateTime?> _getLastBackgroundedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLastBackgroundAt);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }
}