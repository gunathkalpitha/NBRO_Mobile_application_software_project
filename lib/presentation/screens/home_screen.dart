import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/app_shell.dart';
import 'dashboard_screen.dart';
import 'analysis_screen.dart';
import 'settings_screen.dart';
import '../state/inspection_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  NavItem _currentItem = NavItem.dashboard;

  @override
  void initState() {
    super.initState();
    debugPrint('[HomeScreen] initState called');
    // Dispatch load event immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[HomeScreen] PostFrameCallback - Dispatching LoadInspectionsEvent');
      context.read<InspectionBloc>().add(const LoadInspectionsEvent());
    });
  }

  @override
  Widget build(BuildContext context) {
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
        return const DashboardScreen();
      case NavItem.inspection:
        return const DashboardScreen(); // Inspection is part of dashboard
      case NavItem.analysis:
        return const AnalysisScreen();
      case NavItem.settings:
        return const SettingsScreen();
    }
  }
}
