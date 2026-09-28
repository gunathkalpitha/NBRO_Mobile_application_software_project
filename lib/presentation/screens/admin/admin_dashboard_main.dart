import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nbro_mobile_application/core/services/welcome_notification_service.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'package:nbro_mobile_application/presentation/widgets/app_shell.dart';
import 'package:nbro_mobile_application/presentation/widgets/sync_status_badge.dart';
import 'package:nbro_mobile_application/data/repositories/inspection_repository.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';
import 'package:nbro_mobile_application/domain/models/notice.dart';
import 'officers_screen.dart';
import 'inspections_management_screen.dart';
import 'admin_notices_screen.dart';
import '../inspection/inspection_map_screen.dart';
import 'reports_screen_admin.dart';
import 'analysis_screen_admin.dart';
import 'auditlog.dart';
import 'Task_manager.dart';

class AdminDashboardMain extends StatefulWidget {
  final void Function(AdminNavItem)? onNavItemSelected;

  const AdminDashboardMain({super.key, this.onNavItemSelected});

  @override
  State<AdminDashboardMain> createState() => _AdminDashboardMainState();
}

class _AdminDashboardMainState extends State<AdminDashboardMain> {
  int _totalOfficers = 0;
  int _pendingInspections = 0;
  int _totalSites = 0;
  bool _isLoading = true;
  Notice? _latestNotice;
  final InspectionRepository _inspectionRepository = InspectionRepository();

  static final Notice _defaultNotice = Notice(
    id: 'default_admin_notice',
    title: 'NBRO Administrative Control System',
    message:
        'Manage officer credentials, inspect field survey submissions, publish announcements, and review real-time site analytics.',
    publishedAt: DateTime.now(),
    publishedBy: 'System',
    priority: NoticePriority.normal,
    isRead: true,
  );

  @override
  void initState() {
    super.initState();
    _loadAdminStats();
    _loadNoticeSummary();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerWelcomeNotification();
    });
  }

  void _triggerWelcomeNotification() {
    final user = Supabase.instance.client.auth.currentUser;
    final adminName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.email?.split('@').first ??
        'Admin';

    WelcomeNotificationService.triggerWelcomeNotification(
      context: context,
      userName: adminName,
      role: 'Administrator',
    );
  }

  Future<void> _loadAdminStats() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final supabase = Supabase.instance.client;
      
      final officersResponse = await supabase
          .from('profile')
          .select('id')
          .eq('role', 'officer')
          .eq('is_active', true);
      _totalOfficers = officersResponse.length;

      final sitesForStatus = await supabase
          .from('site')
          .select('site_id, sync_status');

      _pendingInspections = sitesForStatus
          .where((i) => i['sync_status'] == 'pending')
          .length;

      final sitesResponse = await supabase
          .from('site')
          .select('site_id');
      _totalSites = sitesResponse.length;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading admin stats: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNoticeSummary() async {
    try {
      final noticesResponse = await Supabase.instance.client
          .from('notices')
          .select('id, title, message, priority, published_at, published_by_name')
          .order('published_at', ascending: false)
          .limit(1);

      if (noticesResponse.isNotEmpty) {
        final json = noticesResponse.first;
        setState(() {
          _latestNotice = Notice(
            id: json['id'] as String,
            title: json['title'] as String,
            message: json['message'] as String,
            publishedAt: DateTime.parse(json['published_at'] as String),
            publishedBy: json['published_by_name'] as String? ?? 'Admin',
            priority: NoticePriority.values.firstWhere(
              (e) => e.name == (json['priority'] as String? ?? 'normal'),
              orElse: () => NoticePriority.normal,
            ),
            isRead: true,
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading notice summary: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF121212)
          : const Color(0xFFF4F6F9),
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
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
        ),
        titleSpacing: 0,
        leadingWidth: 44,
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
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: NBROColors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/icons/pasted-image.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.business,
                      color: NBROColors.primary,
                      size: 32,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'NBRO Admin Portal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'National Building Research Org.',
                    style: TextStyle(
                      fontSize: 11,
                      color: NBROColors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Compact Cloud Status Icon Badge
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: SyncStatusBadge(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(NBROColors.primary),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await _loadAdminStats();
                await _loadNoticeSummary();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Official Hero Banner Card
                    _buildOfficialHeroBanner(context),

                    // 2. Playing Notice Ticker Banner
                    _buildNoticeTickerBar(context),

                    // 3. Thin Horizontal Statistics Bar
                    _buildThinHorizontalStatsBar(context),

                    const SizedBox(height: 16),

                    // 4. Action Grid Cards Section (2 Columns)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Administrative Services',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 1.25,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            children: [
                              // Box 1: Inspections (View All)
                              _AdminActionCard(
                                title: 'Inspections\n(View All)',
                                tag: 'ALL SITES',
                                icon: Icons.fact_check_outlined,
                                bgAsset: 'assets/images/bg_inspections.jpg',
                                accentColor: const Color(0xFFF4F6F9),
                                onTap: () {
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

                              // Box 2: Manage Officers
                              _AdminActionCard(
                                title: 'Manage Officers',
                                tag: 'OFFICERS',
                                icon: Icons.people_alt_outlined,
                                bgAsset: 'assets/images/bg_officers.jpg',
                                accentColor: const Color(0xFFF4F6F9),
                                onTap: () {
                                  if (widget.onNavItemSelected != null) {
                                    widget.onNavItemSelected!(AdminNavItem.officers);
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AdminOfficersScreen(),
                                    ),
                                  ).then((_) => _loadAdminStats());
                                },
                              ),

                              // Box 3: Site on Map
                              _AdminActionCard(
                                title: 'Sites on Map',
                                tag: 'GOOGLE MAP',
                                icon: Icons.map_outlined,
                                bgAsset: 'assets/images/bg_map.jpg',
                                accentColor: const Color(0xFFF4F6F9),
                                onTap: _openSitesMap,
                              ),

                              // Box 4: Notice
                              _AdminActionCard(
                                title: 'Notices',
                                tag: 'PUBLISH',
                                icon: Icons.campaign_outlined,
                                bgAsset: 'assets/images/bg_notice.jpg',
                                accentColor: const Color(0xFFF4F6F9),
                                onTap: () {
                                  if (widget.onNavItemSelected != null) {
                                    widget.onNavItemSelected!(AdminNavItem.notices);
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AdminNoticesScreen(),
                                    ),
                                  ).then((_) => _loadNoticeSummary());
                                },
                              ),

                              // Box 5: Report
                              _AdminActionCard(
                                title: 'Reports',
                                tag: 'PDF EXPORT',
                                icon: Icons.assessment_outlined,
                                bgAsset: 'assets/images/bg_reports.jpg',
                                accentColor: const Color(0xFFF4F6F9),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ReportsScreen(),
                                    ),
                                  );
                                },
                              ),
                              // Box 7: Audit log
                              _AdminActionCard(
                                title: 'Auditlog',
                                tag: 'REVIEW',
                                icon: Icons.audiotrack_outlined,
                                bgAsset: 'assets/images/auditlog.jpg',
                                accentColor: const Color(0xFFF4F6F9),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AuditlogScreen(),
                                    ),
                                  );
                                },
                              ),
                              // Box 6: Analytic
                              _AdminActionCard(
                                title: 'Analytics',
                                tag: 'CHARTS',
                                icon: Icons.analytics_outlined,
                                bgAsset: 'assets/images/bg_analytics.jpg',
                                accentColor: const Color(0xFFF4F6F9),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AnalysisScreen(),
                                    ),
                                  );
                                },
                              ),
                             // Box 8: Task manager
                              _AdminActionCard(
                                title: 'Task Manager',
                                tag: 'ASSIGN',
                                icon: Icons.next_plan_outlined,
                                bgAsset: 'assets/images/task_manager.jpg',
                                accentColor: const Color(0xFFF4F6F9),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const Task_managerScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Official Hero Banner Card
  Widget _buildOfficialHeroBanner(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final adminName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.email?.split('@').first ??
        'Administrator';

    final now = DateTime.now();
    final dateStr = DateFormat('EEEE yyyy.MM.dd').format(now);
    final timeStr = DateFormat('hh:mm a').format(now).toUpperCase();

    return Container(
      margin: const EdgeInsets.all(14),
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background Image Asset
            Positioned.fill(
              child: Image.asset(
                'assets/images/admin_banner.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/images/dashboard_banner_admin.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Dark Gradient Overlay for Contrast
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.45),
                    ],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'NBRO ADMIN CONTROL',
                        style: TextStyle(
                          color: Color(0xFFF4F6F9),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          '$timeStr | $dateStr',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $adminName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'National Building Research Organization Pre-Crack Survey Management',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Yellow/Amber Playing Ticker Notice Bar
  Widget _buildNoticeTickerBar(BuildContext context) {
    final notice = _latestNotice ?? _defaultNotice;

    return GestureDetector(
      onTap: () {
        if (widget.onNavItemSelected != null) {
          widget.onNavItemSelected!(AdminNavItem.notices);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AdminNoticesScreen()),
        ).then((_) => _loadNoticeSummary());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD54F), // Vibrant Amber Yellow
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.shade700.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.black, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: _MarqueeText(
                text: '📢 ${notice.title} : ${notice.message}',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.open_in_new, color: Colors.black54, size: 16),
          ],
        ),
      ),
    );
  }

  // Thin Official Horizontal Statistics Bar
  Widget _buildThinHorizontalStatsBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatText('Total Sites', '$_totalSites', NBROColors.primary),
          Container(width: 1, height: 20, color: Colors.grey.shade300),
          _buildStatText('Active Officers', '$_totalOfficers', NBROColors.primaryDark),
          Container(width: 1, height: 20, color: Colors.grey.shade300),
          _buildStatText('Pending Sync', '$_pendingInspections', Colors.amber.shade900),
        ],
      ),
    );
  }

  Widget _buildStatText(String label, String value, Color color) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
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
}

// 2-Column Action Grid Card with Background Image, Dark Overlay & High-Contrast Labels
class _AdminActionCard extends StatelessWidget {
  final String title;
  final String tag;
  final IconData icon;
  final String bgAsset;
  final Color accentColor;
  final VoidCallback onTap;

  const _AdminActionCard({
    required this.title,
    required this.tag,
    required this.icon,
    required this.bgAsset,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Background Image Asset
              Positioned.fill(
                child: Image.asset(
                  bgAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E262C), Color(0xFF2D3748)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Dark Semi-Transparent Gradient Overlay for Dark Mode & High Contrast
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.50),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),

              // Card Content (Badge, Icon & Bold Text Label)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag / Badge Label
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        // Action Accent Icon
                        Icon(
                          icon,
                          color: accentColor,
                          size: 26,
                        ),
                      ],
                    ),

                    // Card Title Label
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Continuous Right-to-Left Scrolling Marquee Ticker for Notice Panel
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({
    required this.text,
    required this.style,
  });

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) break;
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          final durationSeconds = (maxScroll / 22).clamp(4.0, 25.0);
          await _scrollController.animateTo(
            maxScroll,
            duration: Duration(seconds: durationSeconds.toInt()),
            curve: Curves.linear,
          );
          await Future.delayed(const Duration(milliseconds: 1000));
          if (!mounted) break;
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
      ),
    );
  }
}
