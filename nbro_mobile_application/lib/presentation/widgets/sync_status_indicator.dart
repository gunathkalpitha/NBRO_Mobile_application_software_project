import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../state/inspection_bloc.dart';

class SyncStatusIndicator extends StatelessWidget {
  final VoidCallback onSyncPressed;

  const SyncStatusIndicator({
    super.key,
    required this.onSyncPressed,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InspectionBloc, InspectionState>(
      builder: (context, state) {
        if (state is InspectionLoaded) {
          final pendingCount = state.pendingCount;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (pendingCount > 0)
                  Tooltip(
                    message: '$pendingCount pending inspections - Tap to sync',
                    child: IconButton(
                      icon: const Icon(Icons.sync),
                      onPressed: onSyncPressed,
                    ),
                  )
                else
                  Tooltip(
                    message: 'All synced',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: NBROColors.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 16,
                            color: NBROColors.success,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Synced',
                            style: TextStyle(
                              fontSize: 12,
                              color: NBROColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        if (state is InspectionSyncing) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: state.syncdCount / state.totalCount,
                  strokeWidth: 2,
                ),
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
