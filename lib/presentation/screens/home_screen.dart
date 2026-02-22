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
import 'admin_dashboard_main.dart';
import 'admin/officers_screen.dart';
import 'admin/inspections_management_screen.dart';
import 'admin/admin_notices_screen.dart';
import '../state/inspection_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  NavItem _currentItem = NavItem.dashboard;
  AdminNavItem _currentAdminItem = AdminNavItem.dashboard;
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
      return WillPopScope(
        onWillPop: _handleBackNavigation,
        child: AdminAppShell(
          currentItem: _currentAdminItem,
          onNavItemSelected: (item) {
            setState(() {
              _currentAdminItem = item;
            });
          },
          child: _buildAdminScreen(_currentAdminItem),
        ),
      );
    }

    // Show regular officer dashboard
    return WillPopScope(
      onWillPop: _handleBackNavigation,
      child: AppShell(
        currentItem: _currentItem,
        onNavItemSelected: (item) {
          setState(() {
            _currentItem = item;
          });
        },
        child: _buildScreen(_currentItem),
      ),
    );
  }

  Future<bool> _handleBackNavigation() async {
    if (NavRailController.isVisible.value) {
      NavRailController.hide();
      return false;
    }

    if (_isAdmin) {
      if (_currentAdminItem != AdminNavItem.dashboard) {
        setState(() {
          _currentAdminItem = AdminNavItem.dashboard;
        });
        return false;
      }
      return true;
    }

    if (_currentItem != NavItem.dashboard) {
      setState(() {
        _currentItem = NavItem.dashboard;
      });
      return false;
    }

    return true;
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

  Widget _buildAdminScreen(AdminNavItem item) {
    switch (item) {
      case AdminNavItem.dashboard:
        return AdminDashboardMain(
          onNavItemSelected: (adminItem) {
            setState(() {
              _currentAdminItem = adminItem;
            });
          },
        );
      case AdminNavItem.officers:
        return const AdminOfficersScreen(embedded: true);
      case AdminNavItem.inspections:
        return const AdminInspectionsManagementScreen(embedded: true);
      case AdminNavItem.notices:
        return const AdminNoticesScreen(embedded: true);
    }
  }
}
