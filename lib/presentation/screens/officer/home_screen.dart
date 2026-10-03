import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nbro_mobile_application/core/services/profile_completion_service.dart';
import 'package:nbro_mobile_application/core/services/profile_state_service.dart';
import 'package:nbro_mobile_application/presentation/widgets/app_shell.dart';
import 'dashboard_screen.dart';
import '../inspection/inspections_screen.dart';
import 'analysis_screen.dart';
import 'reports_screen.dart';
import 'help_support_screen.dart';
import '../settings/settings_screen.dart';
import '../admin/admin_dashboard_main.dart';
import '../admin/officers_screen.dart';
import '../admin/inspections_management_screen.dart';
import '../admin/admin_notices_screen.dart';
import 'package:nbro_mobile_application/presentation/state/inspection_bloc.dart';
import 'package:nbro_mobile_application/core/sync/sync_service.dart';

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
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    debugPrint('[HomeScreen] initState called');
    _checkUserRole();
    // Dispatch load event immediately & trigger offline sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[HomeScreen] PostFrameCallback - Dispatching LoadInspectionsEvent & SyncService');
      context.read<InspectionBloc>().add(const LoadInspectionsEvent());
      SyncService.instance.triggerSync();
    });
  }

  Future<void> _checkUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final client = Supabase.instance.client;

        String role = '';
        // 1. Query profile table in DB first for exact role
        try {
          final profile = await client
              .from('profile')
              .select('role, is_active')
              .eq('id', user.id)
              .maybeSingle();

          if (profile != null && (profile['is_active'] as bool? ?? true)) {
            role = (profile['role'] as String?)?.toLowerCase() ?? '';
          }
        } catch (e) {
          debugPrint('[HomeScreen] DB profile role lookup: $e');
        }

        // 2. Fallback to user metadata
        if (role.isEmpty) {
          role = (user.userMetadata?['role'] as String?)?.toLowerCase() ?? '';
        }

        final userEmail = user.email?.toLowerCase() ?? '';
        bool isAdmin = role.contains('admin') ||
            userEmail == 'mainadminnbro@gmail.com' ||
            userEmail == 'admin@gmail.com' ||
            userEmail.startsWith('admin.');

        // 3. Fallback: ask DB helper if current user is admin.
        if (!isAdmin) {
          try {
            final rpcResult = await client.rpc('is_admin');
            isAdmin = rpcResult == true;
          } catch (e) {
            debugPrint('[HomeScreen] Failed is_admin() lookup: $e');
          }
        }

        setState(() {
          _isAdmin = isAdmin;
          _isCheckingRole = false;
        });
        await ProfileCompletionService.refresh();
        await ProfileStateService.refresh();
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
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBackNavigation();
        },
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
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

  void _handleBackNavigation() {
    // 1. If side navigation menu is open, close it first
    if (NavRailController.isVisible.value) {
      NavRailController.hide();
      return;
    }

    // 2. If on secondary tab for Admin, switch back to Admin Dashboard tab
    if (_isAdmin) {
      if (_currentAdminItem != AdminNavItem.dashboard) {
        setState(() {
          _currentAdminItem = AdminNavItem.dashboard;
        });
        return;
      }
    } else {
      // If on secondary tab for Officer (Inspections, Analytics, Reports, Help, Settings), switch back to Officer Dashboard tab
      if (_currentItem != NavItem.dashboard) {
        setState(() {
          _currentItem = NavItem.dashboard;
        });
        return;
      }
    }

    // 3. Already on Main Dashboard: Double Press Back to Exit App
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.exit_to_app, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Press back again to exit app', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          backgroundColor: const Color(0xFF263238),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Exit app cleanly on second back press within 2 seconds
    SystemNavigator.pop();
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
      case AdminNavItem.settings:
        return const SettingsScreen(isAdminMode: true);
    }
  }
}
