import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/inspection.dart';
import '../../domain/models/notice.dart';
import '../state/inspection_bloc.dart';
//import '../widgets/sync_status_indicator.dart';
import '../widgets/branding.dart';
import '../widgets/app_shell.dart';
import 'site_inspection_wizard.dart';
import 'inspection_detail_screen.dart';
import 'inspection_map_screen.dart';
import 'notice_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(NavItem)? onNavItemSelected;
  
  const DashboardScreen({super.key, this.onNavItemSelected});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
              title: const NBROBrand(
                title: 'Dashboard',
                showFullName: true,
                logoSize: 60,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              titleSpacing: 4,
              actions: [
                // Online/Offline indicator
                Tooltip(
                  message: 'Online',
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.cloud_done,
                      color: NBROColors.success,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Notification Bell
                Tooltip(
                  message: 'Notifications',
                  child: IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: NBROColors.white),
                    iconSize: 24,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.info_outline, color: NBROColors.white),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text('Notifications feature coming soon!'),
                              ),
                            ],
                          ),
                          backgroundColor: NBROColors.info,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<InspectionBloc>().add(const LoadInspectionsEvent());
          // Instant refresh - no artificial delay
        },
        child: BlocBuilder<InspectionBloc, InspectionState>(
          builder: (context, state) {
            debugPrint('[DashboardScreen] BlocBuilder state: ${state.runtimeType}');
            
            if (state is InspectionInitial || state is InspectionLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(NBROColors.primary),
                ),
              );
            }

            if (state is InspectionError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: NBROColors.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: NBROColors.error,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Something went wrong',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: NBROColors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: NBROColors.grey,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () {
                          context
                              .read<InspectionBloc>()
                              .add(const LoadInspectionsEvent());
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is InspectionLoaded) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Welcome Header with Greeting
                    SliverToBoxAdapter(
                      child: _WelcomeSection(),
                    ),

                    // Notice Bar
                    SliverToBoxAdapter(
                      child: _NoticeBar(),
                    ),

                    // Stats Cards
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ModernStatCard(
                                label: 'Total Sites',
                                value: state.inspections.length.toString(),
                                icon: Icons.location_on,
                                color: NBROColors.primary,
                                gradient: const LinearGradient(
                                  colors: [NBROColors.primary, NBROColors.primaryLight],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => InspectionMapScreen(
                                        inspections: state.inspections,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ModernStatCard(
                                label: 'Pending',
                                value: state.pendingCount.toString(),
                                icon: Icons.pending_actions,
                                color: NBROColors.primary,
                                gradient: LinearGradient(
                                  colors: [
                                    NBROColors.primary.withValues(alpha: 0.9),
                                    NBROColors.primaryLight.withValues(alpha: 0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ModernStatCard(
                                label: 'Synced',
                                value: (state.inspections.length - state.pendingCount)
                                    .toString(),
                                icon: Icons.check_circle,
                                color: NBROColors.primary,
                                gradient: LinearGradient(
                                  colors: [
                                    NBROColors.primary.withValues(alpha: 0.85),
                                    NBROColors.primaryLight.withValues(alpha: 0.75),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                    // Section Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Inspections',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: NBROColors.black,
                              ),
                            ),
                            if (state.inspections.isNotEmpty)
                              TextButton.icon(
                                onPressed: () {
                                  widget.onNavItemSelected?.call(NavItem.inspection);
                                },
                                icon: const Icon(Icons.view_list, size: 18),
                                label: const Text('View All'),
                                style: TextButton.styleFrom(
                                  foregroundColor: NBROColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    // Inspections List or Empty State
                    if (state.inspections.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: NBROColors.grey.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  size: 80,
                                  color: NBROColors.grey.withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No inspections yet',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: NBROColors.darkGrey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start by creating your first inspection',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: NBROColors.grey,
                                ),
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const SiteInspectionWizard(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('New Inspection'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return TweenAnimationBuilder<double>(
                                duration: Duration(milliseconds: 300 + (index * 100)),
                                tween: Tween(begin: 0.0, end: 1.0),
                                builder: (context, value, child) {
                                  return Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: Opacity(
                                      opacity: value,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _EnhancedInspectionCard(
                                  inspection: state.inspections[index],
                                ),
                              );
                            },
                            childCount: state.inspections.length > 5 ? 5 : state.inspections.length,
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              );
            }

            return const Center(
              child: Text('Unknown state'),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const SiteInspectionWizard(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Inspection'),
        elevation: 4,
      ),
    );
  }
}

class _ModernStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Gradient gradient;
  final VoidCallback? onTap;

  const _ModernStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
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
          Icon(icon, color: NBROColors.white, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: NBROColors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: NBROColors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _EnhancedInspectionCard extends StatelessWidget {
  final Inspection inspection;

  const _EnhancedInspectionCard({required this.inspection});

  @override
  Widget build(BuildContext context) {
    final defectCount = inspection.defects.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: NBROColors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => InspectionDetailScreen(
                inspection: inspection,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NBROColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: NBROColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inspection.siteAddress,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: NBROColors.black,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          inspection.ownerName,
                          style: TextStyle(
                            fontSize: 13,
                            color: NBROColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ModernSyncBadge(status: inspection.syncStatus),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NBROColors.light,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: NBROColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.warning_amber,
                              size: 16,
                              color: NBROColors.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$defectCount ${defectCount == 1 ? 'Defect' : 'Defects'}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: NBROColors.darkGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: NBROColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: NBROColors.info,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(inspection.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: NBROColors.info,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _ModernSyncBadge extends StatelessWidget {
  final SyncStatus status;

  const _ModernSyncBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == SyncStatus.synced
        ? NBROColors.success
        : status == SyncStatus.syncing
            ? NBROColors.warning
            : NBROColors.error;

    final icon = status == SyncStatus.synced
        ? Icons.check_circle
        : status == SyncStatus.syncing
            ? Icons.sync
            : Icons.cloud_off;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Welcome Section Widget with Time-based Greeting
class _WelcomeSection extends StatelessWidget {
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    String userName = 'Guest';
    
    if (user != null) {
      userName = user.userMetadata?['full_name'] ?? 
                 user.userMetadata?['name'] ?? 
                 user.email?.split('@').first ?? 
                 'User';
    }

    return Container(
      margin: const EdgeInsets.all(16),
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
        boxShadow: [
          BoxShadow(
            color: NBROColors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: NBROColors.grey.withValues(alpha: 0.8),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome back, $userName!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: NBROColors.primary,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage your site inspections',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NBROColors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            )
    );
  }
}

// Notice Bar Widget
class _NoticeBar extends StatefulWidget {
  @override
  State<_NoticeBar> createState() => _NoticeBarState();
}

class _NoticeBarState extends State<_NoticeBar> {
  bool _isExpanded = false;

 
  final Notice _latestNotice = Notice(
    id: '1',
    title: 'Welcome to NBRO Mobile',
    message: 'Welcome to the NBRO Mobile Inspection Application! This platform helps you manage site inspections efficiently. If you need any assistance, please contact support.',
    publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
    publishedBy: 'Admin',
    priority: NoticePriority.normal,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NBROColors.accent.withValues(alpha: 0.1),
            NBROColors.warning.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: NBROColors.accent.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: NBROColors.accent.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: NBROColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.campaign,
                        color: NBROColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _latestNotice.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: NBROColors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'By ${_latestNotice.publishedBy} • ${_formatDate(_latestNotice.publishedAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: NBROColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: NBROColors.accent,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        _latestNotice.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: NBROColors.darkGrey,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: NBROColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.priority_high,
                                  size: 14,
                                  color: NBROColors.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _latestNotice.priority.displayName.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: NBROColors.accent,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const NoticeScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('View All'),
                            style: TextButton.styleFrom(
                              foregroundColor: NBROColors.accent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}
