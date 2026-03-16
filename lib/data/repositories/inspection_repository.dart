import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/inspection.dart';
import 'dart:io';

/// Repository for managing inspections in Supabase
class InspectionRepository {
  final SupabaseClient _supabase;

  InspectionRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Create a new inspection (site) in the database
  Future<void> createInspection(Inspection inspection,
      {String? buildingPhotoPath}) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      // New schema stores inspection sections in normalized tables.
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

      if (buildingPhotoPath != null) {
        try {
          final upload = await _uploadBuildingPhoto(siteId, buildingPhotoPath);
          await _supabase.from('site').update({
            'building_photo_url': upload['url'],
            'building_photo_path': upload['path'],
          }).eq('site_id', siteId);
        } catch (e) {
          debugPrint('[Repository] ⚠️ Building photo upload failed (inspection still saved): $e');
        }
      }

      for (final defect in inspection.defects) {
        await _createDefectForSite(siteId, defect);
      }

      await _supabase
          .from('site')
          .update({'sync_status': 'synced'})
          .eq('site_id', siteId);
    } catch (e, stackTrace) {
      debugPrint('[Repository] ❌ ERROR saving inspection: $e');
      debugPrint('[Repository] Stack trace: $stackTrace');
      throw Exception('Failed to create inspection: $e');
    }
  }

  /// Get all inspections for the current user
  Future<List<Inspection>> getInspections() async {
    try {
      final response = await _supabase
          .from('site')
          .select('''
            site_id,
            user_id,
            owner_name,
            owner_contact,
            address,
            building_ref,
            distance_from_row,
            latitude,
            longitude,
            building_photo_url,
            building_photo_path,
            sync_status,
            created_at,
            updated_at,
            general_observation(type, present_condition, approx_age),
            external_services(pipe_born_water_supply, sewage_waste, electricity_source),
            main_building(no_floors),
            defects(
              defect_id,
              created_at,
              defect_info(
                info_id,
                remarks,
                length,
                width,
                defect_image(image_url, image_path)
              )
            )
          ''')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => _mapInspectionFromSiteRow(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get inspections: $e');
    }
  }

  /// Get a single inspection with its defects
  Future<Inspection?> getInspection(String id) async {
    try {
      var siteResponse = await _supabase
          .from('site')
          .select('''
            site_id,
            user_id,
            owner_name,
            owner_contact,
            address,
            building_ref,
            distance_from_row,
            latitude,
            longitude,
            building_photo_url,
            building_photo_path,
            sync_status,
            created_at,
            updated_at,
            general_observation(type, present_condition, approx_age),
            external_services(pipe_born_water_supply, sewage_waste, electricity_source),
            main_building(no_floors),
            defects(
              defect_id,
              created_at,
              defect_info(
                info_id,
                remarks,
                length,
                width,
                defect_image(image_url, image_path)
              )
            )
          ''')
          .eq('building_ref', id)
          .maybeSingle();

      siteResponse ??= await _supabase
          .from('site')
          .select('''
            site_id,
            user_id,
            owner_name,
            owner_contact,
            address,
            building_ref,
            distance_from_row,
            latitude,
            longitude,
            building_photo_url,
            building_photo_path,
            sync_status,
            created_at,
            updated_at,
            general_observation(type, present_condition, approx_age),
            external_services(pipe_born_water_supply, sewage_waste, electricity_source),
            main_building(no_floors),
            defects(
              defect_id,
              created_at,
              defect_info(
                info_id,
                remarks,
                length,
                width,
                defect_image(image_url, image_path)
              )
            )
          ''')
          .eq('site_id', id)
          .maybeSingle();

      if (siteResponse == null) {
        return null;
      }

      return _mapInspectionFromSiteRow(siteResponse);
    } catch (e) {
      throw Exception('Failed to get inspection: $e');
    }
  }

  /// Update an existing inspection
  Future<void> updateInspection(Inspection inspection, {String? newBuildingPhotoPath}) async {
    try {
      final site = await _resolveSiteByInspectionId(inspection.id);
      if (site == null) {
        throw Exception('Inspection not found: ${inspection.id}');
      }

      final siteId = site['site_id'] as String;

      await _supabase.from('site').update({
        'owner_name': inspection.ownerName,
        'owner_contact': inspection.contactNo,
        'address': inspection.siteAddress,
        'latitude': inspection.latitude,
        'longitude': inspection.longitude,
        'distance_from_row': inspection.distanceFromRow,
        'sync_status': inspection.syncStatus.name,
      }).eq('site_id', siteId);

      if (newBuildingPhotoPath != null) {
        final upload = await _uploadBuildingPhoto(siteId, newBuildingPhotoPath);
        await _supabase.from('site').update({
          'building_photo_url': upload['url'],
          'building_photo_path': upload['path'],
        }).eq('site_id', siteId);
      } else if (inspection.buildingPhotoUrl == null) {
        // photo was explicitly removed
        await _supabase.from('site').update({
          'building_photo_url': null,
          'building_photo_path': null,
        }).eq('site_id', siteId);
      }

      await _upsertSectionBySiteId(
        table: 'general_observation',
        idColumn: 'observation_id',
        siteId: siteId,
        payload: {
          'type': inspection.typeOfStructure,
          'present_condition': inspection.presentCondition,
          'approx_age': inspection.ageOfStructure?.toString(),
        },
      );

      await _upsertSectionBySiteId(
        table: 'external_services',
        idColumn: 'service_id',
        siteId: siteId,
        payload: {
          'pipe_born_water_supply': inspection.hasPipeBorneWater == true
              ? (inspection.waterSource ?? 'Available')
              : 'Not Available',
          'sewage_waste': inspection.hasSewageWaste == true
              ? (inspection.sewageType ?? 'Available')
              : 'Not Available',
          'electricity_source': inspection.hasElectricity == true
              ? (inspection.electricitySource ?? 'Available')
              : 'Not Available',
        },
      );

      await _upsertSectionBySiteId(
        table: 'main_building',
        idColumn: 'building_id',
        siteId: siteId,
        payload: {
          'no_floors': inspection.numberOfFloors,
        },
      );
    } catch (e) {
      throw Exception('Failed to update inspection: $e');
    }
  }

  /// Delete an inspection and all its defects
  Future<void> deleteInspection(String id) async {
    try {
      await _supabase.from('site').delete().eq('building_ref', id);
      await _supabase.from('site').delete().eq('site_id', id);
    } catch (e) {
      throw Exception('Failed to delete inspection: $e');
    }
  }

  /// Add a defect to an existing inspection
  Future<void> addDefect(Defect defect) async {
    try {
      final site = await _resolveSiteByInspectionId(defect.inspectionId);
      if (site == null) {
        throw Exception('Inspection not found for defect: ${defect.inspectionId}');
      }

      final siteId = site['site_id'] as String;
      await _createDefectForSite(siteId, defect);
    } catch (e) {
      throw Exception('Failed to add defect: $e');
    }
  }

  /// Update an existing defect
  Future<void> updateDefect(Defect defect) async {
    try {
      var defectInfo = await _supabase
          .from('defect_info')
          .select('info_id')
          .eq('defect_id', defect.id)
          .maybeSingle();

      if (defectInfo == null) {
        throw Exception('Defect info not found for defect: ${defect.id}');
      }

      final infoId = defectInfo['info_id'] as String;
      await _supabase.from('defect_info').update({
        'remarks': _composeDefectRemarks(defect),
        'length': defect.lengthMm.toString(),
        'width': defect.widthMm?.toString(),
      }).eq('info_id', infoId);

      if (defect.photoPath != null) {
        final upload = await _uploadDefectPhoto(defect.id, defect.photoPath!);
        final existingImage = await _supabase
            .from('defect_image')
            .select('image_id')
            .eq('info_id', infoId)
            .maybeSingle();

        if (existingImage == null) {
          await _supabase.from('defect_image').insert({
            'info_id': infoId,
            'image_url': upload['url'],
            'image_path': upload['path'],
          });
        } else {
          await _supabase.from('defect_image').update({
            'image_url': upload['url'],
            'image_path': upload['path'],
          }).eq('image_id', existingImage['image_id']);
        }
      }
    } catch (e) {
      throw Exception('Failed to update defect: $e');
    }
  }

  /// Delete a defect
  Future<void> deleteDefect(String defectId) async {
    try {
      await _deleteDefectPhoto(defectId);
      await _supabase.from('defects').delete().eq('defect_id', defectId);
    } catch (e) {
      throw Exception('Failed to delete defect: $e');
    }
  }

  /// Get all defects for a specific inspection
  Future<List<Defect>> getDefects(String inspectionId) async {
    try {
      final site = await _resolveSiteByInspectionId(inspectionId);
      if (site == null) return [];

      final response = await _supabase
          .from('defects')
          .select('''
            defect_id,
            created_at,
            defect_info(
              info_id,
              remarks,
              length,
              width,
              defect_image(image_url, image_path)
            )
          ''')
          .eq('site_id', site['site_id'])
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => _mapDefectFromRow(
                json as Map<String, dynamic>,
                inspectionId,
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to get defects: $e');
    }
  }

  /// Search inspections by owner name or site address
  Future<List<Inspection>> searchInspections(String query) async {
    try {
      final response = await _supabase
          .from('site')
          .select()
          .or('owner_name.ilike.%$query%,address.ilike.%$query%,building_ref.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Inspection.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to search inspections: $e');
    }
  }

  /// Get pending inspections (not synced)
  Future<List<Inspection>> getPendingInspections() async {
    try {
      final response = await _supabase
          .from('site')
          .select()
          .eq('sync_status', 'pending')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Inspection.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get pending inspections: $e');
    }
  }

  /// Get synced inspections
  Future<List<Inspection>> getSyncedInspections() async {
    try {
      final response = await _supabase
          .from('site')
          .select()
          .eq('sync_status', 'synced')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Inspection.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get synced inspections: $e');
    }
  }

  /// Get inspection count by sync status
  Future<Map<String, int>> getInspectionStats() async {
    try {
      final totalResponse = await _supabase
        .from('site')
        .select('site_id');
      final total = (totalResponse as List).length;

      final pendingResponse = await _supabase
        .from('site')
        .select('site_id')
          .eq('sync_status', 'pending');
      final pending = (pendingResponse as List).length;

      final syncedResponse = await _supabase
        .from('site')
        .select('site_id')
          .eq('sync_status', 'synced');
      final synced = (syncedResponse as List).length;

      return {
        'total': total,
        'pending': pending,
        'synced': synced,
      };
    } catch (e) {
      throw Exception('Failed to get inspection stats: $e');
    }
  }

  Future<void> _upsertSectionBySiteId({
    required String table,
    required String idColumn,
    required String siteId,
    required Map<String, dynamic> payload,
  }) async {
    final existing = await _supabase
        .from(table)
        .select(idColumn)
        .eq('site_id', siteId)
        .maybeSingle();

    if (existing == null) {
      await _supabase.from(table).insert({
        'site_id': siteId,
        ...payload,
      });
      return;
    }

    await _supabase
        .from(table)
        .update(payload)
        .eq(idColumn, existing[idColumn]);
  }

  Future<void> _createDefectForSite(String siteId, Defect defect) async {
    String? imageUrl;
    String? imagePath;
    if (defect.photoPath != null) {
      final upload = await _uploadDefectPhoto(defect.id, defect.photoPath!);
      imageUrl = upload['url'];
      imagePath = upload['path'];
    }

    await _supabase.rpc('insert_defect_with_details', params: {
      'p_site_id': siteId,
      'p_remarks': _composeDefectRemarks(defect),
      'p_length': defect.lengthMm.toString(),
      'p_width': defect.widthMm?.toString(),
      'p_image_url': imageUrl,
      'p_image_path': imagePath,
    });
  }

  Map<String, String> _parseDefectRemarks(String? remarks) {
    if (remarks == null || !remarks.startsWith('NBRO_META:')) {
      return {
        'notation': DefectNotation.c.code,
        'category': DefectCategory.buildingFloor.name,
        'floor': '',
        'remarks': remarks ?? '',
      };
    }

    final divider = remarks.indexOf('|');
    if (divider == -1) {
      return {
        'notation': DefectNotation.c.code,
        'category': DefectCategory.buildingFloor.name,
        'floor': '',
        'remarks': remarks,
      };
    }

    final meta = remarks.substring('NBRO_META:'.length, divider);
    final body = remarks.substring(divider + 1);
    final parts = <String, String>{
      'notation': DefectNotation.c.code,
      'category': DefectCategory.buildingFloor.name,
      'floor': '',
      'remarks': body,
    };

    for (final kv in meta.split(';')) {
      final idx = kv.indexOf('=');
      if (idx <= 0) continue;
      parts[kv.substring(0, idx)] = kv.substring(idx + 1);
    }
    return parts;
  }

  String _composeDefectRemarks(Defect defect) {
    final floor = defect.floorLevel ?? '';
    final note = defect.remarks ?? '';
    return 'NBRO_META:notation=${defect.notation.code};category=${defect.category.name};floor=$floor|$note';
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final text = value.toString();
    final match = RegExp(r'[0-9]+(\.[0-9]+)?').firstMatch(text);
    if (match == null) return null;
    return double.tryParse(match.group(0)!);
  }

  Inspection _mapInspectionFromSiteRow(Map<String, dynamic> row) {
    final observationList = (row['general_observation'] as List?) ?? const [];
    final serviceList = (row['external_services'] as List?) ?? const [];
    final buildingList = (row['main_building'] as List?) ?? const [];

    final observation = observationList.isNotEmpty
        ? observationList.first as Map<String, dynamic>
        : const <String, dynamic>{};
    final services = serviceList.isNotEmpty
        ? serviceList.first as Map<String, dynamic>
        : const <String, dynamic>{};
    final building = buildingList.isNotEmpty
        ? buildingList.first as Map<String, dynamic>
        : const <String, dynamic>{};

    final defectsRows = (row['defects'] as List?) ?? const [];
    final defects = defectsRows
        .map((d) => _mapDefectFromRow(
              d as Map<String, dynamic>,
              (row['building_ref'] as String?) ?? (row['site_id'] as String),
            ))
        .toList();

    return Inspection(
      id: (row['building_ref'] as String?) ?? (row['site_id'] as String),
      ownerName: (row['owner_name'] as String?) ?? 'Unknown Owner',
      siteAddress: (row['address'] as String?) ?? 'Unknown Address',
      contactNo: row['owner_contact'] as String?,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      distanceFromRow: (row['distance_from_row'] as num?)?.toDouble(),
      ageOfStructure: _parseDouble(observation['approx_age'])?.round(),
      typeOfStructure: observation['type'] as String?,
      presentCondition: observation['present_condition'] as String?,
      hasPipeBorneWater: (services['pipe_born_water_supply'] as String?)
              ?.toLowerCase()
              .contains('available') ??
          false,
      waterSource: services['pipe_born_water_supply'] as String?,
      hasElectricity: (services['electricity_source'] as String?)
              ?.toLowerCase()
              .contains('available') ??
          false,
      electricitySource: services['electricity_source'] as String?,
      hasSewageWaste: (services['sewage_waste'] as String?)
              ?.toLowerCase()
              .contains('available') ??
          false,
      sewageType: services['sewage_waste'] as String?,
      numberOfFloors: building['no_floors'] as String?,
      defects: defects,
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == row['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
      createdBy: row['user_id'] as String?,
      buildingPhotoUrl: row['building_photo_url'] as String?,
    );
  }

  Defect _mapDefectFromRow(Map<String, dynamic> row, String inspectionId) {
    final infos = (row['defect_info'] as List?) ?? const [];
    final info = infos.isNotEmpty
        ? infos.first as Map<String, dynamic>
        : const <String, dynamic>{};
    final images = (info['defect_image'] as List?) ?? const [];
    final image = images.isNotEmpty
        ? images.first as Map<String, dynamic>
        : const <String, dynamic>{};

    final parsed = _parseDefectRemarks(info['remarks'] as String?);

    return Defect(
      id: (row['defect_id'] as String?) ?? '',
      inspectionId: inspectionId,
      notation: DefectNotation.values.firstWhere(
        (e) => e.code == parsed['notation'],
        orElse: () => DefectNotation.c,
      ),
      category: DefectCategory.values.firstWhere(
        (e) => e.name == parsed['category'],
        orElse: () => DefectCategory.buildingFloor,
      ),
      floorLevel: parsed['floor'],
      lengthMm: _parseDouble(info['length']) ?? 0,
      widthMm: _parseDouble(info['width']),
      remarks: parsed['remarks'],
      photoPath: image['image_path'] as String?,
      photoUrl: image['image_url'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
    );
  }

  Future<Map<String, dynamic>?> _resolveSiteByInspectionId(
      String inspectionId) async {
    final byBuildingRef = await _supabase
        .from('site')
        .select('site_id, building_ref')
        .eq('building_ref', inspectionId)
        .maybeSingle();
    if (byBuildingRef != null) return byBuildingRef;

    final bySiteId = await _supabase
        .from('site')
        .select('site_id, building_ref')
        .eq('site_id', inspectionId)
        .maybeSingle();
    if (bySiteId != null) return bySiteId;

    return null;
  }

  /// Upload building/site front-view photo to Supabase Storage
  Future<Map<String, String>> _uploadBuildingPhoto(
      String siteId, String photoPath) async {
    try {
      final file = File(photoPath);
      if (!await file.exists()) {
        throw Exception('Building photo file not found: $photoPath');
      }

      final fileName = 'building_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'sites/$siteId/$fileName';
      await _supabase.storage
          .from('site-images')
          .upload(
            storagePath,
            file,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final publicUrl = _supabase.storage
          .from('site-images')
          .getPublicUrl(storagePath);

      return {'url': publicUrl, 'path': storagePath};
    } catch (e) {
      debugPrint('[Repository] ❌ ERROR uploading building photo: $e');
      throw Exception('Failed to upload building photo: $e');
    }
  }

  /// Upload defect photo to Supabase Storage
  Future<Map<String, String>> _uploadDefectPhoto(
      String defectId, String photoPath) async {
    try {
      final file = File(photoPath);
      if (!await file.exists()) {
        throw Exception('Photo file not found: $photoPath');
      }

      final fileName = 'defect_${defectId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'defects/$defectId/$fileName';
      await _supabase.storage
          .from('defect-images')
          .upload(
            storagePath,
            file,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
            ),
          );

      final publicUrl = _supabase.storage
          .from('defect-images')
          .getPublicUrl(storagePath);

      return {
        'url': publicUrl,
        'path': storagePath,
      };
    } catch (e, stackTrace) {
      debugPrint('[Repository] ❌ ERROR uploading photo: $e');
      debugPrint('[Repository] Stack trace: $stackTrace');
      throw Exception('Failed to upload photo: $e');
    }
  }

  /// Delete defect photo from storage
  Future<void> _deleteDefectPhoto(String defectId) async {
    try {
      final defectInfo = await _supabase
          .from('defect_info')
          .select('info_id')
          .eq('defect_id', defectId)
          .maybeSingle();

      if (defectInfo == null) {
        return;
      }

      final infoId = defectInfo['info_id'] as String;
      final images = await _supabase
          .from('defect_image')
          .select('image_path')
          .eq('info_id', infoId) as List<dynamic>;

      for (final image in images) {
        final imagePath = image['image_path'] as String?;
        if (imagePath != null && imagePath.isNotEmpty) {
          await _supabase.storage.from('defect-images').remove([imagePath]);
        }
      }

      await _supabase.from('defect_image').delete().eq('info_id', infoId);
    } catch (e) {
      if (kDebugMode) {
        print('Warning: Failed to delete defect photo: $e');
      }
    }
  }

  /// Get photo URL for a defect
  Future<String?> getDefectPhotoUrl(String defectId) async {
    try {
      final info = await _supabase
          .from('defect_info')
          .select('info_id')
          .eq('defect_id', defectId)
          .maybeSingle();

      if (info == null) return null;

      final image = await _supabase
          .from('defect_image')
          .select('image_url')
          .eq('info_id', info['info_id'])
          .limit(1)
          .maybeSingle();

      return image?['image_url'] as String?;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to get photo URL: $e');
      }
      return null;
    }
  }

  /// Sync local inspection to Supabase
  Future<void> syncInspection(Inspection inspection) async {
    try {
      final existing = await _supabase
          .from('site')
          .select('site_id')
          .eq('building_ref', inspection.id)
          .maybeSingle();

      if (existing != null) {
        await updateInspection(inspection);
      } else {
        await createInspection(inspection);
      }

      await _supabase
          .from('site')
          .update({'sync_status': 'synced', 'updated_at': DateTime.now().toIso8601String()})
          .eq('building_ref', inspection.id);
    } catch (e) {
      await _supabase
          .from('site')
          .update({'sync_status': 'error', 'updated_at': DateTime.now().toIso8601String()})
          .eq('building_ref', inspection.id);
      
      throw Exception('Failed to sync inspection: $e');
    }
  }
}
