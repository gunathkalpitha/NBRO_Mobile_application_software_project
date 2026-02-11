import 'package:flutter/material.dart';
import 'admin_dashboard_main.dart';

/// Legacy redirect to the new admin dashboard
/// This file is kept for backward compatibility
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminDashboardMain();
  }
}
