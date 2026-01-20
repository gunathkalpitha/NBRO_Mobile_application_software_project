import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/inspection.dart';
import '../../data/repositories/inspection_repository.dart';

/// InspectionEvent - Events for Inspection BLoC
abstract class InspectionEvent {
  const InspectionEvent();
}

class LoadInspectionsEvent extends InspectionEvent {
  const LoadInspectionsEvent();
}

class CreateInspectionEvent extends InspectionEvent {
  final Inspection inspection;

  const CreateInspectionEvent({
    required this.inspection,
  });
}

class UpdateInspectionEvent extends InspectionEvent {
  final Inspection inspection;

  const UpdateInspectionEvent(this.inspection);
}

class AddDefectEvent extends InspectionEvent {
  final String inspectionId;
  final Defect defect;

  const AddDefectEvent({
    required this.inspectionId,
    required this.defect,
  });
}

class SyncInspectionsEvent extends InspectionEvent {
  const SyncInspectionsEvent();
}

/// InspectionState - States for Inspection BLoC
abstract class InspectionState {
  const InspectionState();
}

class InspectionInitial extends InspectionState {
  const InspectionInitial();
}

class InspectionLoading extends InspectionState {
  const InspectionLoading();
}

class InspectionLoaded extends InspectionState {
  final List<Inspection> inspections;
  final SyncStatus overallSyncStatus;
  final int pendingCount;

  const InspectionLoaded({
    required this.inspections,
    this.overallSyncStatus = SyncStatus.pending,
    this.pendingCount = 0,
  });
}

class InspectionError extends InspectionState {
  final String message;

  const InspectionError(this.message);
}

class InspectionSyncing extends InspectionState {
  final int syncdCount;
  final int totalCount;

  const InspectionSyncing({
    required this.syncdCount,
    required this.totalCount,
  });
}

/// InspectionBloc - Business Logic Component
class InspectionBloc extends Bloc<InspectionEvent, InspectionState> {
  final InspectionRepository _repository;
  final List<Inspection> _inspections = [];

  InspectionBloc({InspectionRepository? repository})
      : _repository = repository ?? InspectionRepository(),
        super(const InspectionInitial()) {
    on<LoadInspectionsEvent>(_onLoadInspections);
    on<CreateInspectionEvent>(_onCreateInspection);
    on<UpdateInspectionEvent>(_onUpdateInspection);
    on<AddDefectEvent>(_onAddDefect);
    on<SyncInspectionsEvent>(_onSyncInspections);
  }

  /// Get inspection count (for debugging)
  int get inspectionCount => _inspections.length;

  Future<void> _onLoadInspections(
    LoadInspectionsEvent event,
    Emitter<InspectionState> emit,
  ) async {
    try {
      debugPrint('[InspectionBloc] Loading inspections from database...');
      
      // Load from Supabase
      final inspections = await _repository.getInspections();
      _inspections.clear();
      _inspections.addAll(inspections);
      
      final pendingCount = _inspections.where((i) => i.syncStatus == SyncStatus.pending).length;
      
      debugPrint('[InspectionBloc] Loaded ${_inspections.length} inspections. Pending: $pendingCount');
      
      emit(
        InspectionLoaded(
          inspections: List.unmodifiable(_inspections),
          pendingCount: pendingCount,
        ),
      );
    } catch (e) {
      debugPrint('[InspectionBloc] Error loading inspections: $e');
      emit(InspectionError('Failed to load inspections: $e'));
    }
  }

  Future<void> _onCreateInspection(
    CreateInspectionEvent event,
    Emitter<InspectionState> emit,
  ) async {
    try {
      final newInspection = event.inspection;

      debugPrint('[InspectionBloc] Inspection created: ${newInspection.id}');
      debugPrint('[InspectionBloc] Attempting to save to database...');
      debugPrint('[InspectionBloc] Defects count: ${newInspection.defects.length}');
      
      // Save to Supabase
      await _repository.createInspection(newInspection);
      
      debugPrint('[InspectionBloc] ✅ Inspection saved successfully to database');
      _inspections.add(newInspection);
      
      debugPrint('[InspectionBloc] Inspection created and saved: ${newInspection.id}');
      
      // Emit updated state
      final pendingCount = _inspections.where((i) => i.syncStatus == SyncStatus.pending).length;
      emit(
        InspectionLoaded(
          inspections: List.unmodifiable(_inspections),
          pendingCount: pendingCount,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('[InspectionBloc] ❌ ERROR creating inspection: $e');
      debugPrint('[InspectionBloc] Stack trace: $stackTrace');
      emit(InspectionError('Failed to create inspection: $e'));
    }
  }

  Future<void> _onUpdateInspection(
    UpdateInspectionEvent event,
    Emitter<InspectionState> emit,
  ) async {
    try {
      final index = _inspections.indexWhere((i) => i.id == event.inspection.id);
      if (index >= 0) {
        _inspections[index] = event.inspection;
        debugPrint('[InspectionBloc] Inspection updated: ${event.inspection.id}');
      }
      
      final pendingCount = _inspections.where((i) => i.syncStatus == SyncStatus.pending).length;
      emit(
        InspectionLoaded(
          inspections: List.unmodifiable(_inspections),
          pendingCount: pendingCount,
        ),
      );
    } catch (e) {
      emit(InspectionError('Failed to update inspection: $e'));
    }
  }

  Future<void> _onAddDefect(
    AddDefectEvent event,
    Emitter<InspectionState> emit,
  ) async {
    try {
      final index = _inspections.indexWhere((i) => i.id == event.inspectionId);
      if (index >= 0) {
        final inspection = _inspections[index];
        final updatedDefects = [...inspection.defects, event.defect];
        _inspections[index] = inspection.copyWith(defects: updatedDefects);
        debugPrint('[InspectionBloc] Defect added to inspection: ${event.inspectionId}');
      }
      
      final pendingCount = _inspections.where((i) => i.syncStatus == SyncStatus.pending).length;
      emit(
        InspectionLoaded(
          inspections: List.unmodifiable(_inspections),
          pendingCount: pendingCount,
        ),
      );
    } catch (e) {
      emit(InspectionError('Failed to add defect: $e'));
    }
  }

  Future<void> _onSyncInspections(
    SyncInspectionsEvent event,
    Emitter<InspectionState> emit,
  ) async {
    try {
      final pendingInspections = _inspections.where((i) => i.syncStatus == SyncStatus.pending).toList();
      
      for (int i = 0; i < pendingInspections.length; i++) {
        emit(InspectionSyncing(syncdCount: i, totalCount: pendingInspections.length));
        
       
        debugPrint('[InspectionBloc] Syncing inspection ${i + 1}/${pendingInspections.length}');
        await Future.delayed(const Duration(seconds: 1)); // Simulate sync
        
        final index = _inspections.indexWhere((x) => x.id == pendingInspections[i].id);
        if (index >= 0) {
          _inspections[index] = _inspections[index].copyWith(syncStatus: SyncStatus.synced);
        }
      }

      final pendingCount = _inspections.where((i) => i.syncStatus == SyncStatus.pending).length;
      emit(
        InspectionLoaded(
          inspections: List.unmodifiable(_inspections),
          overallSyncStatus: pendingCount == 0 ? SyncStatus.synced : SyncStatus.pending,
          pendingCount: pendingCount,
        ),
      );
    } catch (e) {
      emit(InspectionError('Failed to sync inspections: $e'));
    }
  }
}
