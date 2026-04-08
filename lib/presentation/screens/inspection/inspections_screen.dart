import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';
import 'package:nbro_mobile_application/presentation/state/inspection_bloc.dart';
import 'package:nbro_mobile_application/presentation/widgets/app_shell.dart';
import 'inspection_detail_screen.dart';

class InspectionsScreen extends StatefulWidget {
  const InspectionsScreen({super.key});

  @override
  State<InspectionsScreen> createState() => _InspectionsScreenState();
}

class _InspectionsScreenState extends State<InspectionsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  String _selectedFilter = 'all';

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
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Inspections',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.white,
                    ),
                  ),
                  Text(
                    'Manage your site inspections',
                    style: TextStyle(
                      fontSize: 12,
                      color: NBROColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: BlocBuilder<InspectionBloc, InspectionState>(
        builder: (context, state) {
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
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
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
                  // Search and Filter Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Search Bar
                          TextField(
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search inspections...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: NBROColors.grey.withValues(alpha: 0.2),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: NBROColors.grey.withValues(alpha: 0.2),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: NBROColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterChip(
                                  label: 'All',
                                  isSelected: _selectedFilter == 'all',
                                  onTap: () {
                                    setState(() {
                                      _selectedFilter = 'all';
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: 'Synced',
                                  isSelected: _selectedFilter == 'synced',
                                  onTap: () {
                                    setState(() {
                                      _selectedFilter = 'synced';
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: 'Pending',
                                  isSelected: _selectedFilter == 'pending',
                                  onTap: () {
                                    setState(() {
                                      _selectedFilter = 'pending';
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Stats Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total: ${state.inspections.length}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: NBROColors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Synced: ${state.inspections.length - state.pendingCount}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: NBROColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Inspections List
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
                              'No inspections found',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: NBROColors.darkGrey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your search or filters',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: NBROColors.grey,
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
                            final filtered = _getFilteredInspections(
                              state.inspections,
                              _searchQuery,
                              _selectedFilter,
                            );

                            if (filtered.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(32),
                                child: Center(
                                  child: Text(
                                    'No results found',
                                    style: TextStyle(
                                      color: NBROColors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return TweenAnimationBuilder<double>(
                              duration: Duration(milliseconds: 300 + (index * 50)),
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
                              child: _InspectionListItem(
                                inspection: filtered[index],
                                onTap: () async {
                                  final result = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          InspectionDetailScreen(
                                            inspection: filtered[index],
                                          ),
                                    ),
                                  );
                                  // Refresh the list if inspection was edited
                                  if (result == true && mounted) {
                                    if (context.mounted) {
                                      context.read<InspectionBloc>().add(LoadInspectionsEvent());
                                    }
                                  }
                                },
                              ),
                            );
                          },
                          childCount: state.inspections.isEmpty
                              ? 1
                              : _getFilteredInspections(
                                  state.inspections,
                                  _searchQuery,
                                  _selectedFilter,
                                ).length,
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
    );
  }

  List<Inspection> _getFilteredInspections(
    List<Inspection> inspections,
    String query,
    String filter,
  ) {
    var filtered = inspections.where((inspection) {
      final matchesQuery = query.isEmpty ||
          inspection.siteAddress.toLowerCase().contains(query.toLowerCase()) ||
          inspection.ownerName.toLowerCase().contains(query.toLowerCase()) ||
          inspection.id.toLowerCase().contains(query.toLowerCase());

      final matchesFilter = filter == 'all' ||
          (filter == 'synced' && inspection.syncStatus == SyncStatus.synced) ||
          (filter == 'pending' && inspection.syncStatus != SyncStatus.synced);

      return matchesQuery && matchesFilter;
    }).toList();

    // Sort by creation date - newest first
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return filtered;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: NBROColors.light,
      selectedColor: NBROColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? NBROColors.white : NBROColors.darkGrey,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: isSelected
            ? NBROColors.primary
            : NBROColors.grey.withValues(alpha: 0.2),
      ),
    );
  }
}

class _InspectionListItem extends StatelessWidget {
  final Inspection inspection;
  final VoidCallback onTap;

  const _InspectionListItem({
    required this.inspection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final defectCount = inspection.defects.length;
    final dateFormatter = DateFormat('MMM dd, yyyy');
    final timeFormatter = DateFormat('hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Address and Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      size: 22,
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
                            fontSize: 15,
                            color: NBROColors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${inspection.id}',
                          style: TextStyle(
                            fontSize: 12,
                            color: NBROColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: inspection.syncStatus),
                ],
              ),

              const SizedBox(height: 12),

              // Owner and Date Info
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: NBROColors.light,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Owner',
                            style: TextStyle(
                              fontSize: 11,
                              color: NBROColors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            inspection.ownerName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: NBROColors.black,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: NBROColors.grey.withValues(alpha: 0.2),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Created',
                            style: TextStyle(
                              fontSize: 11,
                              color: NBROColors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            dateFormatter.format(inspection.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: NBROColors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      color: NBROColors.grey.withValues(alpha: 0.2),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Defects',
                            style: TextStyle(
                              fontSize: 11,
                              color: NBROColors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: defectCount > 0
                                  ? NBROColors.error.withValues(alpha: 0.1)
                                  : NBROColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              defectCount.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: defectCount > 0
                                    ? NBROColors.error
                                    : NBROColors.success,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (inspection.updatedAt != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.edit,
                      size: 14,
                      color: NBROColors.info,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Modified: ${dateFormatter.format(inspection.updatedAt!)} at ${timeFormatter.format(inspection.updatedAt!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: NBROColors.info,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final SyncStatus status;

  const _StatusBadge({required this.status});

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
