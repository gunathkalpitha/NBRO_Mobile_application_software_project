import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nbro_mobile_application/core/services/notice_read_state_service.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'package:nbro_mobile_application/domain/models/notice.dart';
import 'package:nbro_mobile_application/presentation/state/inspection_bloc.dart';
import 'package:nbro_mobile_application/presentation/widgets/app_shell.dart';
import 'package:nbro_mobile_application/presentation/widgets/sync_status_badge.dart';
import 'package:nbro_mobile_application/data/services/draft_storage_service.dart';
import '../inspection/site_inspection_wizard.dart';
import '../inspection/inspections_screen.dart';
import '../inspection/inspection_map_screen.dart';
import 'analysis_screen.dart';
import 'reports_screen.dart';
import 'notice_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(NavItem)? onNavItemSelected;

  const DashboardScreen({super.key, this.onNavItemSelected});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Notice? _latestNotice;
  int _unreadNoticeCount = 0;
  final DraftStorageService _draftService = DraftStorageService();
  List<Map<String, dynamic>> _drafts = [];

  static final Notice _defaultNotice = Notice(
    id: 'default_notice',
    title: 'Welcome to NBRO Mobile Inspection Portal',
    message:
        'Official Network of National Building Research Organization. Complete site surveys, defect mapping, and sync reports seamlessly.',
    publishedAt: DateTime.now(),
    publishedBy: 'Admin',
    priority: NoticePriority.normal,
    isRead: true,
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _loadNoticeSummary();
    _loadDrafts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
            const SizedBox(width: 1),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'NBRO Mobile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'National Building Research Organization',
                    style: TextStyle(
                      fontSize: 10.5,
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
              padding: EdgeInsets.symmetric(horizontal: 0),
              child: SyncStatusBadge(),
            ),
          ),
          const SizedBox(width: 1),
          // Notification Bell
          Tooltip(
            message: 'Notifications',
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: NBROColors.white),
                  iconSize: 24,
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const NoticeScreen(),
                      ),
                    );
                    _loadNoticeSummary();
                  },
                ),
                if (_unreadNoticeCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: NBROColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<InspectionBloc>().add(const LoadInspectionsEvent());
          await _loadNoticeSummary();
          await _loadDrafts();
        },
        child: BlocBuilder<InspectionBloc, InspectionState>(
          builder: (context, state) {
            if (state is InspectionInitial || state is InspectionLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(NBROColors.primary),
                ),
              );
            }

            int totalSites = 0;
            int pendingCount = 0;

            if (state is InspectionLoaded) {
              totalSites = state.inspections.length;
              pendingCount = state.pendingCount;
            }

            final syncedCount = totalSites - pendingCount;

            return FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Official Hero Banner Card
                    _buildOfficialHeroBanner(context),

                    // 2. Animated / Ticker Notice Banner
                    _buildNoticeTickerBar(context),

                    // 3. Thin Horizontal Statistics Bar
                    _buildThinHorizontalStatsBar(
                      context,
                      totalSites: totalSites,
                      pendingCount: pendingCount,
                      syncedCount: syncedCount,
                    ),

                    // 4. Saved Drafts Section (BEVENT SITE COUNT BAR AND QUICK SERVICES)
                    if (_drafts.isNotEmpty) _buildDraftsSection(context),

                    const SizedBox(height: 16),

                    // 5. Action Grid Cards Section (Quick Services)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quick Services',
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
                              // Box 1: New Inspection
                              _DashboardActionCard(
                                title: 'New Inspection',
                                tag: 'CREATE',
                                icon: Icons.assignment_add,
                                bgAsset: 'assets/images/bg_new_inspection.jpg',
                                accentColor: const Color(0xFFF4F6F9),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SiteInspectionWizard(),
                                    ),
                                  );
                                  _loadDrafts();
                                },
                              ),

                              // Box 2: Inspections (View All)
                              _DashboardActionCard(
                                title: 'Inspections\n(View All)',
                                tag: 'RECENT (5)',
                                icon: Icons.fact_check_outlined,
                                bgAsset: 'assets/images/bg_inspections.jpg',
                                accentColor: const Color(0xFFF4F6F9),
                                onTap: () {
                                  if (widget.onNavItemSelected != null) {
                                    widget.onNavItemSelected!(NavItem.inspection);
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const InspectionsScreen(
                                        initialTabIndex: 0, // Default to Recent (Last 5) tab
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Box 3: Total Sites (Google Maps)
                              _DashboardActionCard(
                                title: 'Total Sites',
                                tag: 'GOOGLE MAP',
                                icon: Icons.map_outlined,
                                bgAsset: 'assets/images/bg_map.jpg',
                                accentColor: const Color(0xFFF4F6F9),
                                onTap: () {
                                  if (state is InspectionLoaded) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => InspectionMapScreen(
                                          inspections: state.inspections,
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),

                              // Box 4: Analytics
                              _DashboardActionCard(
                                title: 'Analytics',
                                tag: 'CHARTS',
                                icon: Icons.analytics_outlined,
                                bgAsset: 'assets/images/bg_analytics.jpg',
                                accentColor: const Color(0xFFF4F6F9),
                                onTap: () {
                                  if (widget.onNavItemSelected != null) {
                                    widget.onNavItemSelected!(NavItem.analysis);
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AnalysisScreen(),
                                    ),
                                  );
                                },
                              ),

                              // Box 5: Reports
                              _DashboardActionCard(
                                title: 'Reports',
                                tag: 'PDF EXPORT',
                                icon: Icons.assessment_outlined,
                                bgAsset: 'assets/images/bg_reports.jpg',
                                accentColor: const Color(0xFFF4F6F9),
                                onTap: () {
                                  if (widget.onNavItemSelected != null) {
                                    widget.onNavItemSelected!(NavItem.reports);
                                    return;
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ReportsScreen(),
                                    ),
                                  );
                                },
                              ),

                              // Box 6: Notice
                              _DashboardActionCard(
                                title: 'Notices',
                                tag: 'BULLETINS',
                                icon: Icons.campaign_outlined,
                                bgAsset: 'assets/images/bg_notice.jpg',
                                accentColor: const Color(0xFFF4F6F9),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const NoticeScreen(),
                                    ),
                                  );
                                  _loadNoticeSummary();
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
            );
          },
        ),
      ),
    );
  }

  // Official Hero Banner Card with time, greeting & background image
  Widget _buildOfficialHeroBanner(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.email?.split('@').first ??
        'Government Officer';

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
            // Background Official Image
            Positioned.fill(
              child: Image.asset(
                'assets/images/dashboard_banner.jpg',
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
              ),
            ),
            // Dark Overlay for Contrast
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.4),
                    ],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
              ),
            ),
            // Banner Text & Live Time
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
                        'NBRO OFFICIAL PORTAL',
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
                        'Welcome, $userName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'National Building Research Organization Pre-Crack Survey Portal',
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
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NoticeScreen()),
        );
        await _loadNoticeSummary();
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
                text: ' ${notice.title} : ${notice.message}',
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
  Widget _buildThinHorizontalStatsBar(
    BuildContext context, {
    required int totalSites,
    required int pendingCount,
    required int syncedCount,
  }) {
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
          _buildStatText('Total Sites', '$totalSites', NBROColors.primary),
          Container(width: 1, height: 20, color: Colors.grey.shade300),
          _buildStatText('Pending Sync', '$pendingCount', Colors.amber.shade900),
          Container(width: 1, height: 20, color: Colors.grey.shade300),
          _buildStatText('Synced Cloud', '$syncedCount', NBROColors.success),
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

  // Saved Drafts Section between site count bar and quick services
  Widget _buildDraftsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: NBROColors.info, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Saved Drafts',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: NBROColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_drafts.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: NBROColors.info,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._drafts.map((draft) => _buildDraftCard(context, draft)),
        ],
      ),
    );
  }

  Widget _buildDraftCard(BuildContext context, Map<String, dynamic> draft) {
    final savedAt = DateTime.parse(draft['saved_at'] as String);
    final ownerName = draft['owner_name'] as String? ?? 'Untitled Inspection';
    final address = draft['address'] as String? ?? 'No address provided';
    final currentStep = draft['current_step'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NBROColors.info.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SiteInspectionWizard(
                  draftId: draft['draft_id'],
                  draftData: draft,
                ),
              ),
            );
            _loadDrafts();
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: NBROColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_note,
                    color: NBROColors.info,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ownerName.isEmpty ? 'Untitled Inspection' : ownerName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: NBROColors.info.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Step ${currentStep + 1}/5',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: NBROColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        address,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd, hh:mm a').format(savedAt),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const Spacer(),
                          const Text(
                            'Tap to resume ➔',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: NBROColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: NBROColors.error,
                  onPressed: () => _deleteDraft(draft['draft_id']),
                  tooltip: 'Delete Draft',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadNoticeSummary() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final noticesResponse = await Supabase.instance.client
          .from('notices')
          .select('id, title, message, priority, published_at, published_by_name, target_type')
          .order('published_at', ascending: false);

      final recipientsResponse = await Supabase.instance.client
          .from('notice_recipients')
          .select('notice_id, is_read')
          .eq('officer_id', user.id);

      final recipientMap = <String, bool>{};
      for (final row in (recipientsResponse as List)) {
        final noticeId = row['notice_id'] as String?;
        if (noticeId != null) {
          recipientMap[noticeId] = row['is_read'] as bool? ?? false;
        }
      }

      final localReadIds = await NoticeReadStateService.getLocalReadNoticeIds();

      final visibleNotices = <Notice>[];
      for (final row in (noticesResponse as List)) {
        final json = row as Map<String, dynamic>;
        final noticeId = json['id'] as String;
        final targetType = (json['target_type'] as String?) ?? 'all';
        final isVisible = targetType == 'all' || recipientMap.containsKey(noticeId);
        if (!isVisible) continue;

        final isRead = (recipientMap[noticeId] == true) || localReadIds.contains(noticeId);

        visibleNotices.add(
          Notice(
            id: noticeId,
            title: json['title'] as String,
            message: json['message'] as String,
            publishedAt: DateTime.parse(json['published_at'] as String),
            publishedBy: json['published_by_name'] as String? ?? 'Admin',
            priority: NoticePriority.values.firstWhere(
              (e) => e.name == (json['priority'] as String? ?? 'normal'),
              orElse: () => NoticePriority.normal,
            ),
            isRead: isRead,
          ),
        );
      }

      if (!mounted) return;
      final unreadNotices = visibleNotices.where((n) => !n.isRead).toList();
      setState(() {
        _latestNotice = unreadNotices.isNotEmpty ? unreadNotices.first : _defaultNotice;
        _unreadNoticeCount = unreadNotices.length;
      });
    } catch (e) {
      debugPrint('Error loading notice summary: $e');
    }
  }

  Future<void> _loadDrafts() async {
    final drafts = await _draftService.getAllDrafts();
    if (mounted) {
      setState(() {
        _drafts = drafts;
      });
    }
  }

  Future<void> _deleteDraft(String draftId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_outlined, color: NBROColors.error),
            SizedBox(width: 12),
            Text('Delete Draft?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this draft? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: NBROColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _draftService.deleteDraft(draftId);
      await _loadDrafts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft deleted'),
            backgroundColor: NBROColors.success,
          ),
        );
      }
    }
  }
}

// 2-Column Action Grid Card with Background Image, Dark Overlay & High-Contrast Labels
class _DashboardActionCard extends StatelessWidget {
  final String title;
  final String tag;
  final IconData icon;
  final String bgAsset;
  final Color accentColor;
  final VoidCallback onTap;

  const _DashboardActionCard({
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
