import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/inspection.dart';
import '../state/inspection_bloc.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/branding.dart';
import '../widgets/app_shell.dart';
import 'site_inspection_wizard.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Data is loaded from HomeScreen.initState()

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // Toggle the side nav (desktop/tablet)
            NavRailController.toggleVisibility();
          },
        ),
        title: const NBROBrand(
          title: 'Dashboard',
          showFullName: true,
          logoSize: 48,
        ),
        elevation: 0,
        actions: [
          BlocBuilder<InspectionBloc, InspectionState>(
            builder: (context, state) {
              return SyncStatusIndicator(
                onSyncPressed: () {
                  context
                      .read<InspectionBloc>()
                      .add(const SyncInspectionsEvent());
                },
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<InspectionBloc>().add(const LoadInspectionsEvent());
          await Future.delayed(const Duration(seconds: 2));
        },
        child: BlocBuilder<InspectionBloc, InspectionState>(
          builder: (context, state) {
            debugPrint('[DashboardScreen] BlocBuilder state: ${state.runtimeType}');
            
            // Show loading for both Initial and Loading states
            if (state is InspectionInitial || state is InspectionLoading) {
              debugPrint('[DashboardScreen] Showing loading indicator');
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state is InspectionError) {
              debugPrint('[DashboardScreen] Showing error: ${state.message}');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: NBROColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context
                            .read<InspectionBloc>()
                            .add(const LoadInspectionsEvent());
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is InspectionLoaded) {
              debugPrint('[DashboardScreen] Showing loaded data: ${state.inspections.length} inspections');
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stats Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(
                            label: 'Total',
                            value: state.inspections.length.toString(),
                            icon: Icons.location_on,
                          ),
                          _StatItem(
                            label: 'Pending',
                            value: state.pendingCount.toString(),
                            icon: Icons.sync_problem,
                          ),
                          _StatItem(
                            label: 'Synced',
                            value:
                                (state.inspections.length - state.pendingCount)
                                    .toString(),
                            icon: Icons.check_circle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recent Inspections
                  Text(
                    'Recent Inspections',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),

                  if (state.inspections.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: NBROColors.grey.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No inspections yet',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.inspections.length,
                      itemBuilder: (context, index) {
                        final inspection = state.inspections[index];
                        return _InspectionCard(inspection: inspection);
                      },
                    ),
                ],
              );
            }

            return const Center(
              child: Text('Unknown state'),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const SiteInspectionWizard(),
            ),
          );
        },
        tooltip: 'Start New Inspection',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: NBROColors.primary, size: 34),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: NBROColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: NBROColors.grey,
          ),
        ),
      ],
    );
  }
}

class _InspectionCard extends StatelessWidget {
  final Inspection inspection;

  const _InspectionCard({required this.inspection});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          Icons.location_on,
          color: NBROColors.primary,
        ),
        title: Text(
          inspection.siteAddress,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${inspection.defects.length} defect(s) recorded',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Created: ${inspection.createdAt.toString().split('.')[0]}',
              style: const TextStyle(fontSize: 11, color: NBROColors.grey),
            ),
          ],
        ),
        trailing: _SyncBadge(status: inspection.syncStatus),
        onTap: () {
        
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('View inspection details')),
          );
        },
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  final SyncStatus status;

  const _SyncBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == SyncStatus.synced
        ? NBROColors.success
        : status == SyncStatus.syncing
            ? NBROColors.warning
            : NBROColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
