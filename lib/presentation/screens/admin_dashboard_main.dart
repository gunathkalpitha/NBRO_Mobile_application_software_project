import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../../data/repositories/inspection_repository.dart';
import '../../domain/models/inspection.dart';
import 'admin/officers_screen.dart';
import 'admin/inspections_management_screen.dart';
import 'admin/admin_notices_screen.dart';
import 'inspection_map_screen.dart';

class AdminDashboardMain extends StatefulWidget {
  final void Function(AdminNavItem)? onNavItemSelected;

  const AdminDashboardMain({super.key, this.onNavItemSelected});

  @override
  State<AdminDashboardMain> createState() => _AdminDashboardMainState();
}

class _AdminDashboardMainState extends State<AdminDashboardMain> {
  int _totalOfficers = 0;
  int _totalInspections = 0;
  int _pendingInspections = 0;
  int _totalSites = 0;
  bool _isLoading = true;
  final InspectionRepository _inspectionRepository = InspectionRepository();

  @override
  void initState() {
    super.initState();
    _loadAdminStats();
  }

  Future<void> _loadAdminStats() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final supabase = Supabase.instance.client;
      
      // Get total active officers count
      final officersResponse = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'officer')
          .eq('is_active', true);
      _totalOfficers = (officersResponse as List).length;

      // Get total inspections count
      final inspectionsResponse = await supabase
          .from('inspections')
          .select('id, sync_status');
      
      _totalInspections = (inspectionsResponse as List).length;
      _pendingInspections = (inspectionsResponse as List)
          .where((i) => i['sync_status'] == 'pending')
          .length;

        final sitesResponse = await supabase
          .from('sites')
          .select('id');
        _totalSites = (sitesResponse as List).length;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading admin stats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NBROColors.light,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [NBROColors.primary, NBROColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: NBROColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AppBar(
              toolbarHeight: 80,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leadingWidth: 48,
              leading: IconButton(
                icon: const Icon(Icons.menu, color: NBROColors.white),
                iconSize: 24,
                padding: EdgeInsets.zero,
                onPressed: () {
                  NavRailController.toggleVisibility();
                },
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NBROColors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.asset(
                      'assets/icons/pasted-image.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.business,
                          color: NBROColors.primary,
                          size: 40,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isVerySmall = constraints.maxWidth < 250;
                            return Text(
                              isVerySmall ? 'NBRO' : 'National Building Research Organization',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: NBROColors.white,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Admin Dashboard',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: NBROColors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              titleSpacing: 4,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(NBROColors.primary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAdminStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    _buildWelcomeSection(),
                    const SizedBox(height: 24),

                    // Stats Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = (constraints.maxWidth - 12) / 2;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: itemWidth,
                              child: _buildStatCard(
                                'Total Active Officers',
                                _totalOfficers.toString(),
                                Icons.people,
                                NBROColors.primary,
                                isCompact: true,
                                description: 'Active officers',
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: _buildStatCard(
                                'Total Inspections',
                                _totalInspections.toString(),
                                Icons.assignment,
                                NBROColors.primaryDark,
                                isCompact: true,
                                description: 'All officers inspections',
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: _buildStatCard(
                                'Completed',
                                (_totalInspections - _pendingInspections)
                                    .toString(),
                                Icons.check_circle,
                                NBROColors.primaryLight,
                                isCompact: true,
                                description: 'Synced inspections',
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: _buildStatCard(
                                'Total Sites on Map',
                                _totalSites.toString(),
                                Icons.map,
                                NBROColors.primary,
                                isCompact: true,
                                onTap: _openSitesMap,
                                description: 'Tap to view on map',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Quick Actions Section
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: NBROColors.black,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Action Cards
                    _buildActionCard(
                      'Manage Officers',
                      'Add, view, or remove officers',
                      Icons.manage_accounts,
                      NBROColors.primary,
                      () {
                        if (widget.onNavItemSelected != null) {
                          widget.onNavItemSelected!(AdminNavItem.officers);
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminOfficersScreen(),
                          ),
                        ).then((_) {
                          // Refresh stats when returning from officers screen
                          _loadAdminStats();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildActionCard(
                      'View All Inspections',
                      'See all inspections by officer',
                      Icons.assignment,
                      NBROColors.info,
                      () {
                        if (widget.onNavItemSelected != null) {
                          widget.onNavItemSelected!(AdminNavItem.inspections);
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminInspectionsManagementScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildActionCard(
                      'Manage Notices',
                      'Send to all, individual, or selected officers',
                      Icons.campaign,
                      NBROColors.primary,
                      () {
                        if (widget.onNavItemSelected != null) {
                          widget.onNavItemSelected!(AdminNavItem.notices);
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminNoticesScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatTime() {
    final now = DateTime.now();
    return DateFormat('hh:mm a').format(now).toUpperCase();
  }

  String _formatDate() {
    final now = DateTime.now();
    return DateFormat('EEEE yyyy.MM.dd').format(now);
  }

  Future<void> _openSitesMap() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(NBROColors.primary),
                ),
                SizedBox(height: 12),
                Text('Loading sites...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final List<Inspection> inspections =
          await _inspectionRepository.getInspections();
      if (!mounted) return;
      Navigator.of(context).pop();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InspectionMapScreen(
            inspections: inspections,
            onViewDetails: (context, inspection) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminInspectionsManagementScreen(
                    initialInspectionId: inspection.id,
                  ),
                ),
              );
            },
          ),
        ),
      );
      _loadAdminStats();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load sites map: $e'),
          backgroundColor: NBROColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildWelcomeSection() {
    final user = Supabase.instance.client.auth.currentUser;
    String adminName = 'Admin';
    
    if (user != null) {
      adminName = user.userMetadata?['full_name'] ?? 
                 user.userMetadata?['name'] ?? 
                 user.email?.split('@').first ?? 
                 'Admin';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NBROColors.primary.withValues(alpha: 0.08),
            NBROColors.primaryLight.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: NBROColors.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NBROColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  size: 48,
                  color: NBROColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 14,
                        color: NBROColors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: NBROColors.primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Administrator',
                      style: TextStyle(
                        fontSize: 9,
                        color: NBROColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: NBROColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatTime(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: NBROColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: NBROColors.grey.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
    bool isCompact = false,
    String? description,
  }) {
    final padding = isCompact ? 12.0 : 16.0;
    final iconSize = isCompact ? 24.0 : 32.0;
    final valueSize = isCompact ? 20.0 : 28.0;
    final labelSize = isCompact ? 11.0 : 13.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: NBROColors.white, size: iconSize),
              SizedBox(height: isCompact ? 8 : 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.bold,
                  color: NBROColors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: labelSize,
                  color: NBROColors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: isCompact ? 9 : 11,
                    color: NBROColors.white.withValues(alpha: 0.75),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: NBROColors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: NBROColors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: NBROColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: NBROColors.grey.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
