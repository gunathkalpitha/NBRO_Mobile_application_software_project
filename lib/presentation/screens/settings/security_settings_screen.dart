import 'package:flutter/material.dart';
import 'package:nbro_mobile_application/core/services/session_security_service.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _isLoading = true;
  bool _biometricEnabled = false;
  int _appLockTimeoutMinutes = 30;
  bool _staySignedInEnabled = true;
  int _staySignedInHours = 2;
  bool _fingerprintAvailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await SessionSecurityService.getSettings();
    final canUseFingerprint = await SessionSecurityService.canUseFingerprint();
    if (!mounted) return;

    setState(() {
      _biometricEnabled = settings.biometricEnabled;
      _appLockTimeoutMinutes = settings.appLockTimeoutMinutes;
      _staySignedInEnabled = settings.staySignedInEnabled;
      _staySignedInHours = settings.staySignedInHours;
      _fingerprintAvailable = canUseFingerprint;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Enable Fingerprint Unlock'),
              subtitle: Text(
                _fingerprintAvailable
                    ? 'Use fingerprint to unlock when app lock is triggered.'
                    : 'Fingerprint is not available on this device.',
              ),
              value: _fingerprintAvailable && _biometricEnabled,
              onChanged: !_fingerprintAvailable
                  ? null
                  : (value) async {
                      if (value) {
                        final verification =
                            await SessionSecurityService.verifyFingerprintForEnable();
                        if (!context.mounted) return;
                        if (!verification.success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${verification.message ?? 'Fingerprint verification failed.'} Fingerprint unlock was not enabled.',
                              ),
                            ),
                          );
                          setState(() => _biometricEnabled = false);
                          await SessionSecurityService.setBiometricEnabled(false);
                          return;
                        }
                      }

                      setState(() => _biometricEnabled = value);
                      await SessionSecurityService.setBiometricEnabled(value);

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            value
                                ? 'Fingerprint unlock enabled.'
                                : 'Fingerprint unlock disabled.',
                          ),
                        ),
                      );
                    },
              secondary: const Icon(Icons.fingerprint, color: NBROColors.primary),
            ),
          ),
          if (_fingerprintAvailable && _biometricEnabled) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_clock, color: NBROColors.primary),
                title: const Text('Lock App After'),
                subtitle: Text(_lockDelayText(_appLockTimeoutMinutes)),
                trailing: DropdownButton<int>(
                  value: _appLockTimeoutMinutes,
                  items: const [0, 30, 120]
                      .map((m) => DropdownMenuItem<int>(
                            value: m,
                            child: Text(_lockDelayText(m)),
                          ))
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() => _appLockTimeoutMinutes = value);
                    await SessionSecurityService.setAppLockTimeoutMinutes(value);
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Stay Signed In'),
              subtitle: const Text('Keep account logged in for a selected period.'),
              value: _staySignedInEnabled,
              onChanged: (value) async {
                setState(() => _staySignedInEnabled = value);
                await SessionSecurityService.setStaySignedInEnabled(value);
              },
              secondary: const Icon(Icons.lock_clock, color: NBROColors.primary),
            ),
          ),
          if (_staySignedInEnabled) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.timer_outlined, color: NBROColors.primary),
                title: const Text('Session Validity Period'),
                subtitle: Text('$_staySignedInHours hours'),
                trailing: DropdownButton<int>(
                  value: _staySignedInHours,
                  items: const [1, 2, 4, 8, 12, 24]
                      .map((h) => DropdownMenuItem<int>(
                            value: h,
                            child: Text('$h hours'),
                          ))
                      .toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    setState(() => _staySignedInHours = value);
                    await SessionSecurityService.setStaySignedInHours(value);
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NBROColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Recommended: enable Fingerprint Unlock and choose a lock delay that matches your field workflow.',
              style: TextStyle(color: NBROColors.darkGrey),
            ),
          ),
        ],
      ),
    );
  }

  static String _lockDelayText(int minutes) {
    if (minutes == 0) return 'Immediate';
    if (minutes == 30) return '30 minutes';
    if (minutes == 120) return '2 hours';
    return '$minutes minutes';
  }
}
