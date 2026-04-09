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
  bool _staySignedInEnabled = true;
  int _staySignedInHours = 2;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await SessionSecurityService.getSettings();
    final canUseBiometric = await SessionSecurityService.canUseBiometric();
    if (!mounted) return;

    setState(() {
      _biometricEnabled = settings.biometricEnabled;
      _staySignedInEnabled = settings.staySignedInEnabled;
      _staySignedInHours = settings.staySignedInHours;
      _biometricAvailable = canUseBiometric;
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
              title: const Text('Enable Biometric Unlock'),
              subtitle: Text(
                _biometricAvailable
                    ? 'Use fingerprint/face to unlock app session.'
                    : 'Biometric is not available on this device.',
              ),
              value: _biometricAvailable && _biometricEnabled,
              onChanged: !_biometricAvailable
                  ? null
                  : (value) async {
                      setState(() => _biometricEnabled = value);
                      await SessionSecurityService.setBiometricEnabled(value);
                    },
              secondary: const Icon(Icons.fingerprint, color: NBROColors.primary),
            ),
          ),
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
              'Recommended: keep Stay Signed In enabled and use Biometric Unlock for faster and secure access.',
              style: TextStyle(color: NBROColors.darkGrey),
            ),
          ),
        ],
      ),
    );
  }
}
