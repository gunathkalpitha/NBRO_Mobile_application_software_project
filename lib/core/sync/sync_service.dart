import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nbro_mobile_application/core/network/connectivity_service.dart';
import 'package:nbro_mobile_application/core/storage/image_storage_service.dart';
import 'package:nbro_mobile_application/data/local/datasources/local_inspection_datasource.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';

/// Single-Threaded Background Synchronization Manager
class SyncService {
  static SyncService? _instance;
  final LocalInspectionDataSource _localDataSource = LocalInspectionDataSource();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isSyncing = false;
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  Timer? _periodicSyncTimer;

  SyncService._() {
    // Auto-sync when connectivity transitions to online
    ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        debugPrint('[SyncService] 🌐 Network online detected. Triggering auto-sync...');
        triggerSync();
      }
    });

    // Fallback periodic sync timer every 30 seconds
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      triggerSync();
    });
  }

  void dispose() {
    _periodicSyncTimer?.cancel();
  }

  static SyncService get instance {
    _instance ??= SyncService._();
    return _instance!;
  }

  bool get isSyncing => _isSyncing;

  /// Trigger background synchronization if network is reachable
  Future<void> triggerSync() async {
    if (_isSyncing) {
      debugPrint('[SyncService] ℹ Sync already in progress. Skipping trigger.');
      return;
    }

    final isOnline = await ConnectivityService.instance.checkActualConnectivity();
    if (!isOnline) {
      debugPrint('[SyncService] ℹ Offline or Supabase unreachable. Skipping sync.');
      return;
    }

    _isSyncing = true;
    isSyncingNotifier.value = true;

    try {
      debugPrint('[SyncService] 🔄 Starting offline-first sync process...');
      final pendingQueue = await _localDataSource.getPendingQueue();

      if (pendingQueue.isEmpty) {
        debugPrint('[SyncService] ✓ Sync queue is empty.');
        return;
      }

      for (final item in pendingQueue) {
        final queueId = item['id'] as int;
        final entityId = item['entity_id'] as String;

        try {
          await _localDataSource.updateQueueItemStatus(queueId, 'SYNCING');
          await _syncInspection(entityId);
          await _localDataSource.updateQueueItemStatus(queueId, 'SYNCED');
        } catch (e) {
          debugPrint('[SyncService] ❌ Failed to sync queue item $queueId ($entityId): $e');
          await _localDataSource.updateQueueItemStatus(
            queueId,
            'FAILED',
            error: e.toString(),
          );
          await _localDataSource.updateInspectionSyncStatus(
            entityId,
            SyncStatus.error,
            syncError: e.toString(),
          );
        }
      }

      await _localDataSource.clearSyncedQueue();

      // Clean up local photo files for synced inspections older than 30 days
      final oldPhotos = await _localDataSource.getOldSyncedPhotoItems();
      if (oldPhotos.isNotEmpty) {
        await ImageStorageService.instance.cleanupOldSyncedPhotos(oldPhotos);
      }

      debugPrint('[SyncService] ✓ Offline sync cycle completed.');
    } catch (e) {
      debugPrint('[SyncService] ❌ Sync cycle error: $e');
    } finally {
      _isSyncing = false;
      isSyncingNotifier.value = false;
    }
  }

  /// Synchronize a single inspection record and its assets
  Future<void> _syncInspection(String localId) async {
    final inspection = await _localDataSource.getInspection(localId);
    if (inspection == null) {
      debugPrint('[SyncService] ⚠️ Inspection $localId not found in local database.');
      return;
    }

    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User is not authenticated');
    }

    await _localDataSource.updateInspectionSyncStatus(localId, SyncStatus.syncing);

    // 1. Upload Front View Building Photo if local
    String? buildingPhotoRemoteUrl = inspection.buildingPhotoUrl;
    if (buildingPhotoRemoteUrl != null && !buildingPhotoRemoteUrl.startsWith('http')) {
      final file = File(buildingPhotoRemoteUrl);
      if (await file.exists()) {
        final storagePath = '${currentUser.id}/${inspection.id}/building_front.jpg';
        final uploadedUrl = await _uploadFileToStorage(
          file: file,
          storagePath: storagePath,
          candidateBuckets: ['site-images', 'defect-images', 'inspections'],
        );
        if (uploadedUrl != null) {
          buildingPhotoRemoteUrl = uploadedUrl;
        }
      }
    }

    // 2. Create/Update Site on Supabase via RPC
    final siteId = await _supabase.rpc('insert_full_site', params: {
      'p_user_id': currentUser.id,
      'p_owner_name': inspection.ownerName,
      'p_owner_contact': inspection.contactNo,
      'p_longitude': inspection.longitude,
      'p_latitude': inspection.latitude,
      'p_building_ref': inspection.id,
      'p_distance_from_row': inspection.distanceFromRow,
      'p_address': inspection.siteAddress,
      'p_type': inspection.typeOfStructure,
      'p_present_condition': inspection.presentCondition,
      'p_approx_age': inspection.ageOfStructure?.toString(),
      'p_pipe_born_water': inspection.hasPipeBorneWater == true
          ? (inspection.waterSource ?? 'Available')
          : 'Not Available',
      'p_sewage_waste': inspection.hasSewageWaste == true
          ? (inspection.sewageType ?? 'Available')
          : 'Not Available',
      'p_electricity_source': inspection.hasElectricity == true
          ? (inspection.electricitySource ?? 'Available')
          : 'Not Available',
      'p_no_floors': inspection.numberOfFloors,
    }) as String;

    // Save photo URL on site record
    if (buildingPhotoRemoteUrl != null && buildingPhotoRemoteUrl.startsWith('http')) {
      await _supabase.from('site').update({
        'building_photo_url': buildingPhotoRemoteUrl,
        'updated_by': currentUser.id,
      }).eq('site_id', siteId);
    }

    // 3. Sync Building Elements Specifications
    final buildingRes = await _supabase
        .from('main_building')
        .select('building_id')
        .eq('site_id', siteId)
        .maybeSingle();

    if (buildingRes != null) {
      final buildingId = buildingRes['building_id'] as String;
      await _syncBuildingSpecifications(buildingId, inspection);
    }

    // 4. Sync Defects & Upload Defect Images
    for (final defect in inspection.defects) {
      String? defectRemoteUrl = defect.photoUrl;

      // Upload defect photo if local file
      if ((defectRemoteUrl == null || !defectRemoteUrl.startsWith('http')) &&
          defect.photoPath != null &&
          defect.photoPath!.isNotEmpty) {
        final photoFile = File(defect.photoPath!);
        if (await photoFile.exists()) {
          final defectStoragePath = '${currentUser.id}/${inspection.id}/defects/${defect.id}.jpg';
          final uploadedUrl = await _uploadFileToStorage(
            file: photoFile,
            storagePath: defectStoragePath,
            candidateBuckets: ['defect-images', 'site-images', 'inspections'],
          );
          if (uploadedUrl != null) {
            defectRemoteUrl = uploadedUrl;
            await _localDataSource.updateDefectPhotoRemoteUrl(defect.id, defectRemoteUrl);
          }
        }
      }

      // Call insert_defect_with_details RPC
      await _supabase.rpc('insert_defect_with_details', params: {
        'p_site_id': siteId,
        'p_notation': defect.notation.code,
        'p_defect_category': defect.category.name,
        'p_floor_level': defect.floorLevel,
        'p_location_description': null,
        'p_length_mm': defect.lengthMm,
        'p_width_mm': defect.widthMm,
        'p_remarks': defect.remarks,
        'p_image_url': defectRemoteUrl,
        'p_image_path': defect.photoPath,
      });
    }

    // Mark local record as SYNCED
    await _localDataSource.updateInspectionSyncStatus(
      localId,
      SyncStatus.synced,
      serverId: siteId,
      buildingPhotoRemoteUrl: buildingPhotoRemoteUrl,
    );

    debugPrint('[SyncService] 🎉 Successfully synchronized inspection $localId to Supabase.');
  }

  Future<String?> _uploadFileToStorage({
    required File file,
    required String storagePath,
    required List<String> candidateBuckets,
  }) async {
    for (final bucket in candidateBuckets) {
      try {
        await _supabase.storage.from(bucket).upload(
          storagePath,
          file,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
        final publicUrl = _supabase.storage.from(bucket).getPublicUrl(storagePath);
        debugPrint('[SyncService] ✓ Uploaded photo to storage bucket "$bucket": $publicUrl');
        return publicUrl;
      } catch (e) {
        debugPrint('[SyncService] ⚠️ Storage upload to bucket "$bucket" failed ($e). Trying next bucket...');
      }
    }
    debugPrint('[SyncService] ⚠️ All storage buckets failed for path: $storagePath');
    return null;
  }

  Future<void> _syncBuildingSpecifications(String buildingId, Inspection inspection) async {
    final specItems = <Map<String, dynamic>>[];
    bool isUsed(dynamic v) => v == true || v == 'true' || v == 1;

    void addSpecs(String scope, Map<String, bool>? materials) {
      if (materials == null) return;
      materials.forEach((key, isSelected) {
        if (isUsed(isSelected)) {
          specItems.add({
            'building_id': buildingId,
            'is_used': true,
            'element_type': '$scope|$key',
          });
        }
      });
    }

    addSpecs('wall', inspection.wallMaterials);
    addSpecs('door', inspection.doorMaterials);
    addSpecs('floor', inspection.floorMaterials);
    addSpecs('roof', inspection.roofMaterials);

    if (inspection.roofCovering != null && inspection.roofCovering!.isNotEmpty) {
      specItems.add({
        'building_id': buildingId,
        'is_used': true,
        'element_type': 'roofcovering|${inspection.roofCovering}',
      });
    }

    if (specItems.isNotEmpty) {
      await _supabase.from('specification').delete().eq('building_id', buildingId);
      await _supabase.from('specification').insert(specItems);
    }
  }
}
