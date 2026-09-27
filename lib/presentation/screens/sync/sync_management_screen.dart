import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nbro_mobile_application/core/network/connectivity_service.dart';
import 'package:nbro_mobile_application/core/sync/sync_service.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'package:nbro_mobile_application/data/local/datasources/local_inspection_datasource.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';

/// Sync Management & Offline Operations Control Screen
class SyncManagementScreen extends StatefulWidget {
  const SyncManagementScreen({super.key});

  @override
  State<SyncManagementScreen> createState() => _SyncManagementScreenState();
}

class _SyncManagementScreenState extends State<SyncManagementScreen> {
  final LocalInspectionDataSource _localDb = LocalInspectionDataSource();
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final SyncService _syncService = SyncService.instance;

  List<Inspection> _inspections = [];
  List<Map<String, dynamic>> _pendingQueue = [];
  bool _isLoading = true;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadData();

    _connectivity.onConnectivityChanged.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });

    _syncService.isSyncingNotifier.addListener(_onSyncStateChanged);
  }

  @override
  void dispose() {
    _syncService.isSyncingNotifier.removeListener(_onSyncStateChanged);
    super.dispose();
  }

  void _onSyncStateChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final isOnline = await _connectivity.checkActualConnectivity();
    final inspections = await _localDb.getAllInspections();
    final pendingQueue = await _localDb.getPendingQueue();

    if (mounted) {
      setState(() {
        _isOnline = isOnline;
        _inspections = inspections;
        _pendingQueue = pendingQueue;
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerManualSync() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot sync: Device is offline or Supabase is unreachable.'),
          backgroundColor: NBROColors.warning,
        ),
      );
      return;
    }

    await _syncService.triggerSync();
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Offline Sync Manager'),
          backgroundColor: NBROColors.primary,
          foregroundColor: NBROColors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: NBROColors.primary),
        ),
      );
    }

    final pendingInspections = _inspections.where((e) => e.syncStatus == SyncStatus.pending).toList();
    final syncedInspections = _inspections.where((e) => e.syncStatus == SyncStatus.synced).toList();
    final failedInspections = _inspections.where((e) => e.syncStatus == SyncStatus.error).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Offline Sync Manager'),
        backgroundColor: NBROColors.primary,
        foregroundColor: NBROColors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Header Card
              _buildSummaryHeader(),
              const SizedBox(height: 20),

              // Pending / Sync Queue Section
              Text(
                'Sync Queue (${_pendingQueue.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: NBROColors.black),
              ),
              const SizedBox(height: 10),
              if (pendingInspections.isEmpty && failedInspections.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: NBROColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.check_circle_outline, color: NBROColors.success, size: 40),
                      SizedBox(height: 8),
                      Text('All local inspections are synchronized!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('No pending items waiting for upload.', style: TextStyle(color: NBROColors.grey, fontSize: 12)),
                    ],
                  ),
                )
              else ...[
                ...pendingInspections.map((e) => _buildInspectionTile(e)),
                ...failedInspections.map((e) => _buildInspectionTile(e)),
              ],

              const SizedBox(height: 24),
              // Synced Inspections History
              Text(
                'Synchronized Locally Cached (${syncedInspections.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: NBROColors.black),
              ),
              const SizedBox(height: 10),
              if (syncedInspections.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No synchronized local records found.', style: TextStyle(color: NBROColors.grey)),
                )
              else
                ...syncedInspections.map((e) => _buildInspectionTile(e)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NBROColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isOnline ? Colors.green.shade50 : Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isOnline ? Icons.wifi : Icons.wifi_off,
                      color: _isOnline ? NBROColors.success : NBROColors.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOnline ? 'Online & Reachable' : 'Offline / Disconnected',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _isOnline ? NBROColors.success : NBROColors.error,
                        ),
                      ),
                      const Text('Supabase Cloud Connection', style: TextStyle(fontSize: 11, color: NBROColors.grey)),
                    ],
                  ),
                ],
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _syncService.isSyncingNotifier,
                builder: (context, isSyncing, _) {
                  return ElevatedButton.icon(
                    onPressed: (isSyncing || !_isOnline) ? null : _triggerManualSync,
                    icon: isSyncing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync, size: 18),
                    label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NBROColors.primary,
                      foregroundColor: NBROColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Pending', '${_pendingQueue.length}', Colors.amber.shade800),
              _buildStatItem('Local Total', '${_inspections.length}', NBROColors.primary),
              _buildStatItem('Synced', '${_inspections.where((e) => e.syncStatus == SyncStatus.synced).length}', NBROColors.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: NBROColors.grey)),
      ],
    );
  }

  Widget _buildInspectionTile(Inspection inspection) {
    Color badgeBg;
    Color badgeFg;
    String statusText;

    switch (inspection.syncStatus) {
      case SyncStatus.synced:
        badgeBg = Colors.green.shade50;
        badgeFg = Colors.green.shade800;
        statusText = '✓ Synced';
        break;
      case SyncStatus.syncing:
        badgeBg = Colors.blue.shade50;
        badgeFg = Colors.blue.shade800;
        statusText = '⟳ Syncing...';
        break;
      case SyncStatus.pending:
        badgeBg = Colors.amber.shade50;
        badgeFg = Colors.amber.shade900;
        statusText = '☁ Waiting for sync';
        break;
      case SyncStatus.error:
        badgeBg = Colors.red.shade50;
        badgeFg = Colors.red.shade800;
        statusText = '⚠ Sync Error';
        break;
    }

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(inspection.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NBROColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                inspection.id,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: NBROColors.primary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
                child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeFg)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(inspection.ownerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(inspection.siteAddress, style: const TextStyle(fontSize: 12, color: NBROColors.grey)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateStr, style: const TextStyle(fontSize: 11, color: NBROColors.grey)),
              Text('${inspection.defects.length} defects captured', style: const TextStyle(fontSize: 11, color: NBROColors.primary, fontWeight: FontWeight.w600)),
            ],
          ),
          if (inspection.syncStatus == SyncStatus.error) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
              child: const Text(
                'Upload interrupted. Tap "Sync Now" above to retry.',
                style: TextStyle(fontSize: 11, color: NBROColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
