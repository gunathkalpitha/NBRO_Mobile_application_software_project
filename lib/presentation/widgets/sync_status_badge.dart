import 'package:flutter/material.dart';
import 'package:nbro_mobile_application/core/network/connectivity_service.dart';
import 'package:nbro_mobile_application/core/sync/sync_service.dart';
import 'package:nbro_mobile_application/data/local/datasources/local_inspection_datasource.dart';
import 'package:nbro_mobile_application/presentation/screens/sync/sync_management_screen.dart';

/// Compact Cloud Status Icon Badge for App Bar Header
class SyncStatusBadge extends StatefulWidget {
  const SyncStatusBadge({super.key});

  @override
  State<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends State<SyncStatusBadge> {
  final LocalInspectionDataSource _localDb = LocalInspectionDataSource();
  int _pendingCount = 0;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();

    ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });

    SyncService.instance.isSyncingNotifier.addListener(_onSyncNotifier);
  }

  @override
  void dispose() {
    SyncService.instance.isSyncingNotifier.removeListener(_onSyncNotifier);
    super.dispose();
  }

  void _onSyncNotifier() {
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final pendingQueue = await _localDb.getPendingQueue();
    final isOnline = ConnectivityService.instance.isOnline;
    if (mounted) {
      setState(() {
        _pendingCount = pendingQueue.length;
        _isOnline = isOnline;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SyncService.instance.isSyncingNotifier,
      builder: (context, isSyncing, _) {
        Color iconColor;
        Color badgeBg;
        IconData iconData;
        String tooltipMessage;

        if (isSyncing) {
          iconColor = Colors.lightBlueAccent;
          badgeBg = Colors.white.withValues(alpha: 0.15);
          iconData = Icons.cloud_sync_rounded;
          tooltipMessage = 'Synchronizing with Supabase...';
        } else if (_pendingCount > 0) {
          iconColor = Colors.amberAccent;
          badgeBg = Colors.amber.shade900.withValues(alpha: 0.3);
          iconData = Icons.cloud_upload_rounded;
          tooltipMessage = '$_pendingCount inspection(s) waiting for sync';
        } else if (!_isOnline) {
          iconColor = Colors.redAccent.shade100;
          badgeBg = Colors.red.shade900.withValues(alpha: 0.3);
          iconData = Icons.cloud_off_rounded;
          tooltipMessage = 'Offline Mode - Saved locally';
        } else {
          iconColor = Colors.greenAccent.shade200;
          badgeBg = Colors.green.shade900.withValues(alpha: 0.3);
          iconData = Icons.cloud_done_rounded;
          tooltipMessage = 'Online - All data synchronized';
        }

        return Tooltip(
          message: tooltipMessage,
          child: InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SyncManagementScreen()),
              );
              _checkStatus();
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: badgeBg,
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (isSyncing)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      ),
                    )
                  else
                    Icon(iconData, size: 22, color: iconColor),

                  if (_pendingCount > 0 && !isSyncing)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '$_pendingCount',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
