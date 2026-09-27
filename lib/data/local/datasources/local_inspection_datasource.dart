import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:nbro_mobile_application/core/database/local_database.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';

/// SQLite Data Source for Offline Inspection Storage
class LocalInspectionDataSource {
  final LocalDatabase _localDb = LocalDatabase.instance;

  /// Save or update an inspection and its defects atomically
  Future<void> saveInspection(
    Inspection inspection, {
    String? buildingPhotoLocalPath,
    String? buildingPhotoRemoteUrl,
  }) async {
    await _localDb.transaction((db) {
      // 1. Insert or Replace Inspection
      final stmt = db.prepare('''
        INSERT INTO inspections (
          local_id,
          server_id,
          building_ref,
          user_id,
          owner_name,
          site_address,
          contact_no,
          latitude,
          longitude,
          distance_from_row,
          age_of_structure,
          type_of_structure,
          present_condition,
          has_pipe_borne_water,
          water_source,
          has_electricity,
          electricity_source,
          has_sewage_waste,
          sewage_type,
          number_of_floors,
          wall_materials_json,
          door_materials_json,
          floor_materials_json,
          roof_materials_json,
          roof_covering,
          building_photo_local_path,
          building_photo_remote_url,
          remarks,
          sync_status,
          created_at,
          updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(local_id) DO UPDATE SET
          owner_name = excluded.owner_name,
          site_address = excluded.site_address,
          contact_no = excluded.contact_no,
          latitude = excluded.latitude,
          longitude = excluded.longitude,
          distance_from_row = excluded.distance_from_row,
          age_of_structure = excluded.age_of_structure,
          type_of_structure = excluded.type_of_structure,
          present_condition = excluded.present_condition,
          has_pipe_borne_water = excluded.has_pipe_borne_water,
          water_source = excluded.water_source,
          has_electricity = excluded.has_electricity,
          electricity_source = excluded.electricity_source,
          has_sewage_waste = excluded.has_sewage_waste,
          sewage_type = excluded.sewage_type,
          number_of_floors = excluded.number_of_floors,
          wall_materials_json = excluded.wall_materials_json,
          door_materials_json = excluded.door_materials_json,
          floor_materials_json = excluded.floor_materials_json,
          roof_materials_json = excluded.roof_materials_json,
          roof_covering = excluded.roof_covering,
          building_photo_local_path = COALESCE(excluded.building_photo_local_path, building_photo_local_path),
          building_photo_remote_url = COALESCE(excluded.building_photo_remote_url, building_photo_remote_url),
          remarks = excluded.remarks,
          sync_status = excluded.sync_status,
          updated_at = excluded.updated_at;
      ''');

      stmt.execute([
        inspection.id,
        inspection.id,
        inspection.id,
        inspection.createdBy ?? '',
        inspection.ownerName,
        inspection.siteAddress,
        inspection.contactNo,
        inspection.latitude,
        inspection.longitude,
        inspection.distanceFromRow,
        inspection.ageOfStructure,
        inspection.typeOfStructure,
        inspection.presentCondition,
        inspection.hasPipeBorneWater == true ? 1 : 0,
        inspection.waterSource,
        inspection.hasElectricity == true ? 1 : 0,
        inspection.electricitySource,
        inspection.hasSewageWaste == true ? 1 : 0,
        inspection.sewageType,
        inspection.numberOfFloors,
        inspection.wallMaterials != null ? jsonEncode(inspection.wallMaterials) : null,
        inspection.doorMaterials != null ? jsonEncode(inspection.doorMaterials) : null,
        inspection.floorMaterials != null ? jsonEncode(inspection.floorMaterials) : null,
        inspection.roofMaterials != null ? jsonEncode(inspection.roofMaterials) : null,
        inspection.roofCovering,
        buildingPhotoLocalPath,
        buildingPhotoRemoteUrl ?? inspection.buildingPhotoUrl,
        inspection.remarks,
        inspection.syncStatus.name.toUpperCase(),
        inspection.createdAt.toIso8601String(),
        DateTime.now().toIso8601String(),
      ]);
      stmt.dispose();

      // 2. Insert or Update Defects
      for (final defect in inspection.defects) {
        final defectStmt = db.prepare('''
          INSERT INTO defects (
            local_id,
            inspection_local_id,
            notation,
            category,
            floor_level,
            length_mm,
            width_mm,
            photo_local_path,
            photo_remote_url,
            upload_status,
            remarks,
            created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(local_id) DO UPDATE SET
            notation = excluded.notation,
            category = excluded.category,
            floor_level = excluded.floor_level,
            length_mm = excluded.length_mm,
            width_mm = excluded.width_mm,
            photo_local_path = COALESCE(excluded.photo_local_path, photo_local_path),
            photo_remote_url = COALESCE(excluded.photo_remote_url, photo_remote_url),
            remarks = excluded.remarks;
        ''');

        defectStmt.execute([
          defect.id,
          inspection.id,
          defect.notation.code,
          defect.category.name,
          defect.floorLevel,
          defect.lengthMm,
          defect.widthMm,
          defect.photoPath,
          defect.photoUrl,
          defect.photoUrl != null ? 'SYNCED' : 'PENDING',
          defect.remarks,
          defect.createdAt.toIso8601String(),
        ]);
        defectStmt.dispose();
      }

      // 3. Add to Sync Queue if PENDING or FAILED
      if (inspection.syncStatus == SyncStatus.pending || inspection.syncStatus == SyncStatus.error) {
        db.execute('''
          INSERT INTO sync_queue (entity_type, entity_id, operation, status, created_at)
          VALUES ('inspection', ?, 'CREATE', 'PENDING', ?)
        ''', [inspection.id, DateTime.now().toIso8601String()]);
      }
    });

    debugPrint('[LocalInspectionDataSource] ✓ Saved inspection ${inspection.id} to SQLite');
  }

  /// Get all local inspections with their defects
  Future<List<Inspection>> getAllInspections() async {
    final db = await _localDb.db;
    final ResultSet rows = db.select('''
      SELECT * FROM inspections ORDER BY created_at DESC;
    ''');

    final inspections = <Inspection>[];
    for (final row in rows) {
      final inspectionId = row['local_id'] as String;
      final defects = await getDefectsForInspection(inspectionId);
      inspections.add(_mapRowToInspection(row, defects));
    }
    return inspections;
  }

  /// Get single inspection by local_id or building_ref
  Future<Inspection?> getInspection(String id) async {
    final db = await _localDb.db;
    final ResultSet rows = db.select('''
      SELECT * FROM inspections WHERE local_id = ? OR building_ref = ? LIMIT 1;
    ''', [id, id]);

    if (rows.isEmpty) return null;
    final row = rows.first;
    final defects = await getDefectsForInspection(row['local_id'] as String);
    return _mapRowToInspection(row, defects);
  }

  /// Get defects for an inspection
  Future<List<Defect>> getDefectsForInspection(String inspectionLocalId) async {
    final db = await _localDb.db;
    final ResultSet rows = db.select('''
      SELECT * FROM defects WHERE inspection_local_id = ? ORDER BY created_at ASC;
    ''', [inspectionLocalId]);

    return rows.map((row) {
      return Defect(
        id: row['local_id'] as String,
        inspectionId: row['inspection_local_id'] as String,
        notation: DefectNotation.values.firstWhere(
          (e) => e.code == (row['notation'] as String),
          orElse: () => DefectNotation.c,
        ),
        category: DefectCategory.values.firstWhere(
          (e) => e.name == (row['category'] as String),
          orElse: () => DefectCategory.buildingFloor,
        ),
        floorLevel: row['floor_level'] as String?,
        lengthMm: (row['length_mm'] as num).toDouble(),
        widthMm: row['width_mm'] != null ? (row['width_mm'] as num).toDouble() : null,
        photoPath: row['photo_local_path'] as String?,
        photoUrl: row['photo_remote_url'] as String?,
        remarks: row['remarks'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  /// Update inspection sync status
  Future<void> updateInspectionSyncStatus(
    String localId,
    SyncStatus status, {
    String? serverId,
    String? syncError,
    String? buildingPhotoRemoteUrl,
  }) async {
    final db = await _localDb.db;
    db.execute('''
      UPDATE inspections SET
        sync_status = ?,
        server_id = COALESCE(?, server_id),
        sync_error = ?,
        building_photo_remote_url = COALESCE(?, building_photo_remote_url),
        synced_at = CASE WHEN ? = 'SYNCED' THEN ? ELSE synced_at END,
        updated_at = ?
      WHERE local_id = ?;
    ''', [
      status.name.toUpperCase(),
      serverId,
      syncError,
      buildingPhotoRemoteUrl,
      status.name.toUpperCase(),
      DateTime.now().toIso8601String(),
      DateTime.now().toIso8601String(),
      localId,
    ]);
  }

  /// Update defect photo remote URL and status
  Future<void> updateDefectPhotoRemoteUrl(
    String defectLocalId,
    String remoteUrl,
  ) async {
    final db = await _localDb.db;
    db.execute('''
      UPDATE defects SET
        photo_remote_url = ?,
        upload_status = 'SYNCED'
      WHERE local_id = ?;
    ''', [remoteUrl, defectLocalId]);
  }

  /// Find photo paths for SYNCED inspections older than 30 days
  Future<List<Map<String, String>>> getOldSyncedPhotoItems() async {
    final db = await _localDb.db;
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    
    final ResultSet siteRows = db.select('''
      SELECT building_photo_local_path, building_photo_remote_url 
      FROM inspections 
      WHERE sync_status = 'SYNCED' AND created_at < ? AND building_photo_local_path IS NOT NULL;
    ''', [cutoffDate]);

    final ResultSet defectRows = db.select('''
      SELECT photo_local_path, photo_remote_url 
      FROM defects 
      WHERE upload_status = 'SYNCED' AND created_at < ? AND photo_local_path IS NOT NULL;
    ''', [cutoffDate]);

    final items = <Map<String, String>>[];
    for (final row in siteRows) {
      if (row['building_photo_local_path'] != null && row['building_photo_remote_url'] != null) {
        items.add({
          'local_path': row['building_photo_local_path'] as String,
          'remote_url': row['building_photo_remote_url'] as String,
        });
      }
    }
    for (final row in defectRows) {
      if (row['photo_local_path'] != null && row['photo_remote_url'] != null) {
        items.add({
          'local_path': row['photo_local_path'] as String,
          'remote_url': row['photo_remote_url'] as String,
        });
      }
    }
    return items;
  }

  /// Get pending queue operations
  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    final db = await _localDb.db;
    final ResultSet rows = db.select('''
      SELECT * FROM sync_queue
      WHERE status IN ('PENDING', 'FAILED') AND attempt_count < 5
      ORDER BY id ASC;
    ''');

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// Update queue item status
  Future<void> updateQueueItemStatus(
    int queueId,
    String status, {
    String? error,
  }) async {
    final db = await _localDb.db;
    db.execute('''
      UPDATE sync_queue SET
        status = ?,
        attempt_count = attempt_count + 1,
        last_error = ?,
        last_attempt_at = ?
      WHERE id = ?;
    ''', [status, error, DateTime.now().toIso8601String(), queueId]);
  }

  /// Clear synced queue entries
  Future<void> clearSyncedQueue() async {
    final db = await _localDb.db;
    db.execute('''
      DELETE FROM sync_queue WHERE status = 'SYNCED';
    ''');
  }

  /// Delete an inspection locally
  Future<void> deleteInspection(String localId) async {
    final db = await _localDb.db;
    db.execute('DELETE FROM inspections WHERE local_id = ?;', [localId]);
  }

  // Helper mapper
  Inspection _mapRowToInspection(Row row, List<Defect> defects) {
    Map<String, bool>? parseJsonMap(dynamic val) {
      if (val == null || (val as String).isEmpty) return null;
      try {
        final decoded = jsonDecode(val) as Map;
        return decoded.map((k, v) => MapEntry(k.toString(), v == true));
      } catch (_) {
        return null;
      }
    }

    final statusStr = (row['sync_status'] as String?)?.toLowerCase() ?? 'pending';
    SyncStatus status = SyncStatus.pending;
    if (statusStr == 'synced') status = SyncStatus.synced;
    if (statusStr == 'syncing') status = SyncStatus.syncing;
    if (statusStr == 'error' || statusStr == 'failed') status = SyncStatus.error;

    return Inspection(
      id: (row['building_ref'] as String?) ?? (row['local_id'] as String),
      ownerName: row['owner_name'] as String,
      siteAddress: row['site_address'] as String,
      contactNo: row['contact_no'] as String?,
      latitude: row['latitude'] != null ? (row['latitude'] as num).toDouble() : null,
      longitude: row['longitude'] != null ? (row['longitude'] as num).toDouble() : null,
      distanceFromRow: row['distance_from_row'] != null ? (row['distance_from_row'] as num).toDouble() : null,
      ageOfStructure: row['age_of_structure'] as int?,
      typeOfStructure: row['type_of_structure'] as String?,
      presentCondition: row['present_condition'] as String?,
      hasPipeBorneWater: row['has_pipe_borne_water'] == 1,
      waterSource: row['water_source'] as String?,
      hasElectricity: row['has_electricity'] == 1,
      electricitySource: row['electricity_source'] as String?,
      hasSewageWaste: row['has_sewage_waste'] == 1,
      sewageType: row['sewage_type'] as String?,
      numberOfFloors: row['number_of_floors'] as String?,
      wallMaterials: parseJsonMap(row['wall_materials_json']),
      doorMaterials: parseJsonMap(row['door_materials_json']),
      floorMaterials: parseJsonMap(row['floor_materials_json']),
      roofMaterials: parseJsonMap(row['roof_materials_json']),
      roofCovering: row['roof_covering'] as String?,
      defects: defects,
      syncStatus: status,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: row['updated_at'] != null ? DateTime.parse(row['updated_at'] as String) : null,
      remarks: row['remarks'] as String?,
      createdBy: row['user_id'] as String?,
      buildingPhotoUrl: (row['building_photo_remote_url'] as String?) ?? (row['building_photo_local_path'] as String?),
    );
  }
}
