import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/branding.dart';
import '../widgets/app_shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoSync = true;
  bool _notifications = true;
  bool _locationTracking = false;
  String _syncInterval = 'Every 15 minutes';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => NavRailController.toggleVisibility(),
        ),
        title: const NBROBrand(title: 'Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Account Section
            _buildSectionHeader('Account'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.person, color: NBROColors.primary),
                title: const Text('Profile'),
                subtitle: const Text('View and edit your profile'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile feature coming soon')),
                  );
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.security, color: NBROColors.primary),
                title: const Text('Security'),
                subtitle: const Text('Change password and security settings'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Security settings coming soon')),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Sync Settings Section
            _buildSectionHeader('Sync & Storage'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.cloud_sync, color: NBROColors.primary),
                    title: const Text('Auto Sync'),
                    subtitle: const Text('Automatically sync inspections'),
                    value: _autoSync,
                    onChanged: (value) {
                      setState(() => _autoSync = value);
                    },
                  ),
                  if (_autoSync)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sync Interval',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButton<String>(
                            value: _syncInterval,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'Every 15 minutes',
                                child: Text('Every 15 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 'Every 30 minutes',
                                child: Text('Every 30 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 'Every hour',
                                child: Text('Every hour'),
                              ),
                              DropdownMenuItem(
                                value: 'Manual',
                                child: Text('Manual'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _syncInterval = value);
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.storage, color: NBROColors.primary),
                title: const Text('Storage Usage'),
                subtitle: const Text('2.3 GB of 10 GB used'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Storage management coming soon')),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Notification Settings Section
            _buildSectionHeader('Notifications & Location'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications, color: NBROColors.primary),
                    title: const Text('Notifications'),
                    subtitle: const Text('Receive app notifications'),
                    value: _notifications,
                    onChanged: (value) {
                      setState(() => _notifications = value);
                    },
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.location_on, color: NBROColors.primary),
                    title: const Text('Location Tracking'),
                    subtitle: const Text('Track location during inspections'),
                    value: _locationTracking,
                    onChanged: (value) {
                      setState(() => _locationTracking = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // App Settings Section
            _buildSectionHeader('App'),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.language, color: NBROColors.primary),
                title: const Text('Language'),
                subtitle: const Text('English'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Language settings coming soon')),
                  );
                },
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.info, color: NBROColors.primary),
                title: const Text('About'),
                subtitle: const Text('Version 1.0.0'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  _showAboutDialog();
                },
              ),
            ),
            const SizedBox(height: 16),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showLogoutDialog();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NBROColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: NBROColors.primary,
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('NBRO Field Surveyor'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version 1.0.0'),
            SizedBox(height: 8),
            Text('A comprehensive field surveying application for structural inspections.'),
            SizedBox(height: 16),
            Text('© 2024 NBRO. All rights reserved.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
