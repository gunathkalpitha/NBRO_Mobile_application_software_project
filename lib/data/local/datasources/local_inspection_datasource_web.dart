import 'package:flutter/foundation.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';

/// Web In-Memory Data Source for Browser Demonstrations (Zero C-FFI / SQLite Dependencies)
class LocalInspectionDataSource {
  final List<Inspection> _webCache = [
    Inspection(
      id: 'BR-COL-001',
      ownerName: 'Mr. Perera',
      siteAddress: 'Colombo 07, Sri Lanka',
      contactNo: '0771234567',
      latitude: 6.9271,
      longitude: 79.8612,
      distanceFromRow: 15.5,
      ageOfStructure: 15,
      typeOfStructure: 'House',
      presentCondition: 'Permanent',
      hasPipeBorneWater: true,
      waterSource: 'Main Supply',
      hasElectricity: true,
      electricitySource: 'Main Supply',
      hasSewageWaste: true,
      sewageType: 'Septic Tank',
      numberOfFloors: 'G+2',
      wallMaterials: {'Brick': true, 'Plastered': true},
      doorMaterials: {'Timber': true, 'Glass': true},
      floorMaterials: {'Tile': true},
      roofMaterials: {'Clay Tiles': true},
      roofCovering: 'Clay Tiles',
      buildingPhotoUrl: 'https://images.unsplash.com/photo-1518780664697-55e3ad937233',
      syncStatus: SyncStatus.synced,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      remarks: 'Web Demo Building Survey - Colombo Branch',
      createdBy: 'cc8eefc8-6473-43a7-8530-f5f9202f3581',
      defects: [
        Defect(
          id: 'DEF-001',
          inspectionId: 'BR-COL-001',
          notation: DefectNotation.c,
          category: DefectCategory.buildingFloor,
          floorLevel: 'Ground',
          lengthMm: 450,
          widthMm: 2.5,
          photoUrl: 'https://images.unsplash.com/photo-1590069261209-f8e9b8642343',
          remarks: 'Hairline plaster crack near living room window',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ],
    ),
  ];

  Future<void> saveInspection(
    Inspection inspection, {
    String? buildingPhotoLocalPath,
    String? buildingPhotoRemoteUrl,
  }) async {
    _webCache.removeWhere((i) => i.id == inspection.id);
    _webCache.insert(0, inspection);
    debugPrint('[LocalInspectionDataSourceWeb] ✓ Saved inspection ${inspection.id} to In-Memory Web Cache');
  }

  Future<List<Inspection>> getAllInspections() async {
    return List.from(_webCache);
  }

  Future<Inspection?> getInspection(String id) async {
    try {
      return _webCache.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<List<Defect>> getDefectsForInspection(String inspectionLocalId) async {
    final inspection = await getInspection(inspectionLocalId);
    return inspection?.defects ?? [];
  }

  Future<void> updateInspectionSyncStatus(
    String localId,
    SyncStatus status, {
    String? serverId,
    String? syncError,
    String? buildingPhotoRemoteUrl,
  }) async {
    final inspection = await getInspection(localId);
    if (inspection != null) {
      final index = _webCache.indexOf(inspection);
      _webCache[index] = inspection.copyWith(
        syncStatus: status,
        buildingPhotoUrl: buildingPhotoRemoteUrl ?? inspection.buildingPhotoUrl,
      );
    }
  }

  Future<void> updateDefectPhotoRemoteUrl(
    String defectLocalId,
    String remoteUrl,
  ) async {}

  Future<List<Map<String, String>>> getOldSyncedPhotoItems() async {
    return [];
  }

  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    return [];
  }

  Future<void> updateQueueItemStatus(
    int queueId,
    String status, {
    String? error,
  }) async {}

  Future<void> clearSyncedQueue() async {}

  Future<void> deleteInspection(String localId) async {
    _webCache.removeWhere((i) => i.id == localId);
  }
}
