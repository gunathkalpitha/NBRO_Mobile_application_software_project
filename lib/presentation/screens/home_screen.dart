import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_shell.dart';
import 'dashboard_screen.dart';
import 'inspections_screen.dart';
import 'analysis_screen.dart';
import 'reports_screen.dart';
import 'help_support_screen.dart';
import 'settings_screen.dart';
import 'admin_dashboard_screen.dart';
import '../state/inspection_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  NavItem _currentItem = NavItem.dashboard;
  bool _isAdmin = false;
  bool _isCheckingRole = true;

  @override
  void initState() {
    super.initState();
    debugPrint('[HomeScreen] initState called');
    _checkUserRole();
    // Dispatch load event immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[HomeScreen] PostFrameCallback - Dispatching LoadInspectionsEvent');
      context.read<InspectionBloc>().add(const LoadInspectionsEvent());
    });
  }

  Future<void> _checkUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final role = user.userMetadata?['role'] ?? 'officer';
        setState(() {
          _isAdmin = role == 'admin';
          _isCheckingRole = false;
        });
      } else {
        setState(() {
          _isCheckingRole = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking user role: $e');
      setState(() {
        _isCheckingRole = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingRole) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Show admin dashboard if user is admin
    if (_isAdmin) {
      return const AdminDashboardScreen();
    }

    // Show regular officer dashboard
    return AppShell(
      currentItem: _currentItem,
      onNavItemSelected: (item) {
        setState(() {
          _currentItem = item;
        });
      },
      child: _buildScreen(_currentItem),
    );
  }

  Widget _buildScreen(NavItem item) {
    switch (item) {
      case NavItem.dashboard:
        return DashboardScreen(
          onNavItemSelected: (item) {
            setState(() {
              _currentItem = item;
            });
          },
        );
      case NavItem.inspection:
        return const InspectionsScreen();
      case NavItem.analysis:
        return const AnalysisScreen();
      case NavItem.reports:
        return const ReportsScreen();
      case NavItem.help:
        return const HelpSupportScreen();
      case NavItem.settings:
        return const SettingsScreen();
    }
  }
}
