import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';
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

      // Ensure coordinates are persisted even if the deployed RPC version ignores them.
      await _persistSiteCoordinates(siteId, inspection.latitude, inspection.longitude);

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

      await _syncMaterialSpecifications(siteId, inspection);

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
            location,
            latitude,
            longitude,
            building_photo_url,
            building_photo_path,
            sync_status,
            created_at,
            updated_at,
            general_observation(type, present_condition, approx_age),
            external_services(pipe_born_water_supply, sewage_waste, electricity_source),
            main_building(
              no_floors,
              specification(element_type, is_used)
            ),
            defects(
              defect_id,
              notation,
              defect_category,
              floor_level,
              location_description,
              length_mm,
              width_mm,
              photo_url,
              photo_path,
              remarks,
              created_at
            )
          ''')
          .order('created_at', ascending: false);

      final inspections = (response as List)
          .map((json) => _mapInspectionFromSiteRow(json as Map<String, dynamic>))
          .toList();

      return inspections;
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
            location,
            latitude,
            longitude,
            building_photo_url,
            building_photo_path,
            sync_status,
            created_at,
            updated_at,
            general_observation(type, present_condition, approx_age),
            external_services(pipe_born_water_supply, sewage_waste, electricity_source),
            main_building(
              no_floors,
              specification(element_type, is_used)
            ),
            defects(
              defect_id,
              notation,
              defect_category,
              floor_level,
              location_description,
              length_mm,
              width_mm,
              photo_url,
              photo_path,
              remarks,
              created_at
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
            location,
            latitude,
            longitude,
            building_photo_url,
            building_photo_path,
            sync_status,
            created_at,
            updated_at,
            general_observation(type, present_condition, approx_age),
            external_services(pipe_born_water_supply, sewage_waste, electricity_source),
            main_building(
              no_floors,
              specification(element_type, is_used)
            ),
            defects(
              defect_id,
              notation,
              defect_category,
              floor_level,
              location_description,
              length_mm,
              width_mm,
              photo_url,
              photo_path,
              remarks,
              created_at
            )
          ''')
          .eq('site_id', id)
          .maybeSingle();

      if (siteResponse == null) {
        return null;
      }

      final inspection = _mapInspectionFromSiteRow(siteResponse);
      return inspection;
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
        'updated_at': inspection.updatedAt?.toIso8601String(),
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

      await _syncMaterialSpecifications(siteId, inspection);
      await _syncDefectsForSite(siteId, inspection.defects);
    } catch (e) {
      throw Exception('Failed to update inspection: $e');
    }
  }

  /// Delete an inspection and all its defects
  Future<void> deleteInspection(String id) async {
    try {
      debugPrint('[Repository] 🗑️ Deleting inspection: $id');
      
      String? siteId;
      bool isUuid = id.contains('-') && RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(id);
      
      // If it's a UUID, use it directly as site_id
      if (isUuid) {
        siteId = id;
        debugPrint('[Repository] ✓ Using ID as site_id (UUID format): $siteId');
      } else {
        // It's a building_ref, need to look up the site_id
        debugPrint('[Repository] Looking up site by building_ref: $id');
        final response = await _supabase
            .from('site')
            .select('site_id')
            .eq('building_ref', id)
            .maybeSingle();
        
        if (response != null) {
          siteId = response['site_id'] as String;
          debugPrint('[Repository] ✓ Found site_id: $siteId');
        } else {
          debugPrint('[Repository] ⚠️ Site not found with building_ref, trying direct delete by building_ref...');
          // Try deleting by building_ref directly
          await _supabase.from('site').delete().eq('building_ref', id);
          debugPrint('[Repository] ✓ Inspection deleted by building_ref: $id');
          return;
        }
      }
      
      // Delete by site_id (CASCADE constraints will handle dependent records)
      await _supabase.from('site').delete().eq('site_id', siteId);
      debugPrint('[Repository] ✓ Inspection deleted successfully: $siteId');
    } catch (e, stackTrace) {
      debugPrint('[Repository] ❌ Error deleting inspection: $e');
      debugPrint('[Repository] Stack trace: $stackTrace');
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

      if (defect.photoPath != null && !_isRemoteUrl(defect.photoPath!)) {
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
      } else if (defect.photoPath != null && _isRemoteUrl(defect.photoPath!)) {
        final existingImage = await _supabase
            .from('defect_image')
            .select('image_id')
            .eq('info_id', infoId)
            .maybeSingle();

        if (existingImage == null) {
          await _supabase.from('defect_image').insert({
            'info_id': infoId,
            'image_url': defect.photoPath,
            'image_path': null,
          });
        } else {
          await _supabase.from('defect_image').update({
            'image_url': defect.photoPath,
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
          .select('defect_id, created_at')
          .eq('site_id', site['site_id'])
          .order('created_at', ascending: true);

      final defects = (response as List)
          .map((json) => _mapDefectFromRow(
                json as Map<String, dynamic>,
                inspectionId,
              ))
          .toList();

      // Fetch defect_info separately for each defect to avoid RLS policy issues
      if (defects.isNotEmpty) {
        final defectIds = defects.map((d) => d.id).toList();

        try {
          final infosResponse = await _supabase
              .from('defect_info')
              .select('defect_id, info_id, remarks, length, width, defect_image(image_url, image_path)')
              .inFilter('defect_id', defectIds);

          // Create a map of defect_id -> info for quick lookup
          final infosMap = <String, Map<String, dynamic>>{};
          for (final info in (infosResponse as List)) {
            final defectId = (info['defect_id'] as String?) ?? '';
            if (defectId.isNotEmpty) {
              infosMap[defectId] = info as Map<String, dynamic>;
            }
          }

          // Update each defect with its info
          for (int i = 0; i < defects.length; i++) {
            final defect = defects[i];
            final info = infosMap[defect.id] ?? const <String, dynamic>{};

            // Rebuild the defect with updated info
            final images = (info['defect_image'] as List?) ?? const [];
            final image = images.isNotEmpty
                ? images.first as Map<String, dynamic>
                : const <String, dynamic>{};

            final parsed = _parseDefectRemarks(info['remarks'] as String?);

            defects[i] = Defect(
              id: defect.id,
              inspectionId: defect.inspectionId,
              notation: DefectNotation.values.firstWhere(
                (e) => e.code == parsed['notation'],
                orElse: () => defect.notation,
              ),
              category: DefectCategory.values.firstWhere(
                (e) => e.name == parsed['category'],
                orElse: () => defect.category,
              ),
              floorLevel: parsed['floor'] ?? defect.floorLevel,
              lengthMm: _parseDouble(info['length']) ?? defect.lengthMm,
              widthMm: _parseDouble(info['width']) ?? defect.widthMm,
              remarks: parsed['remarks'] ?? defect.remarks,
              photoPath: (image['image_url'] as String?) ?? (image['image_path'] as String?) ?? defect.photoPath,
              photoUrl: (image['image_url'] as String?) ?? defect.photoUrl,
              createdAt: defect.createdAt,
            );
          }
        } catch (e) {
          debugPrint('[Repository] ⚠️ Failed to populate defect_info in getDefects: $e');
        }
      }

      return defects;
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

  Future<void> _syncMaterialSpecifications(
    String siteId,
    Inspection inspection,
  ) async {
    final building = await _supabase
        .from('main_building')
        .select('building_id')
        .eq('site_id', siteId)
        .maybeSingle();

    if (building == null) return;
    final buildingId = building['building_id'] as String;

    await _supabase.from('specification').delete().eq('building_id', buildingId);

    final rows = <Map<String, dynamic>>[];

    void appendSelected(String scope, Map<String, bool>? materials) {
      if (materials == null || materials.isEmpty) return;
      materials.forEach((key, value) {
        if (value == true) {
          rows.add({
            'building_id': buildingId,
            'is_used': true,
            'element_type': '$scope|$key',
          });
        }
      });
    }

    appendSelected('wall', inspection.wallMaterials);
    appendSelected('door', inspection.doorMaterials);
    appendSelected('floor', inspection.floorMaterials);
    appendSelected('roof', inspection.roofMaterials);

    if (rows.isNotEmpty) {
      await _supabase.from('specification').insert(rows);
    }
  }

  Future<void> _createDefectForSite(String siteId, Defect defect) async {
    String? imageUrl;
    String? imagePath;
    if (defect.photoPath != null && !_isRemoteUrl(defect.photoPath!)) {
      final upload = await _uploadDefectPhoto(defect.id, defect.photoPath!);
      imageUrl = upload['url'];
      imagePath = upload['path'];
    } else if (defect.photoPath != null && _isRemoteUrl(defect.photoPath!)) {
      imageUrl = defect.photoPath;
    }

    await _supabase.rpc('insert_defect_with_details', params: {
      'p_site_id': siteId,
      'p_notation': defect.notation.code,
      'p_defect_category': defect.category.name,
      'p_floor_level': defect.floorLevel,
      'p_length_mm': defect.lengthMm,
      'p_width_mm': defect.widthMm,
      'p_remarks': defect.remarks,
      'p_image_url': imageUrl,
      'p_image_path': imagePath,
    });
  }

  Future<void> _syncDefectsForSite(String siteId, List<Defect> defects) async {
    await _supabase.from('defects').delete().eq('site_id', siteId);

    for (final defect in defects) {
      await _createDefectForSite(siteId, defect);
    }
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

  bool _isRemoteUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
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

    final specs = (building['specification'] as List?) ?? const [];
    final wallMaterials = <String, bool>{};
    final doorMaterials = <String, bool>{};
    final floorMaterials = <String, bool>{};
    final roofMaterials = <String, bool>{};

    for (final spec in specs) {
      final item = spec as Map<String, dynamic>;
      final isUsed = item['is_used'] == true;
      final elementType = item['element_type'] as String?;
      if (!isUsed || elementType == null || !elementType.contains('|')) continue;

      final parts = elementType.split('|');
      if (parts.length < 2) continue;
      final scope = parts.first.toLowerCase();
      final key = parts.sublist(1).join('|');

      switch (scope) {
        case 'wall':
          wallMaterials[key] = true;
          break;
        case 'door':
          doorMaterials[key] = true;
          break;
        case 'floor':
          floorMaterials[key] = true;
          break;
        case 'roof':
          roofMaterials[key] = true;
          break;
      }
    }

    final defectsRows = (row['defects'] as List?) ?? const [];
    final defects = defectsRows
        .map((d) => _mapDefectFromRow(
              d as Map<String, dynamic>,
              (row['building_ref'] as String?) ?? (row['site_id'] as String),
            ))
        .toList();

    final resolvedCoords = _resolveCoordinatesFromRow(row);

    return Inspection(
      id: (row['building_ref'] as String?) ?? (row['site_id'] as String),
      ownerName: (row['owner_name'] as String?) ?? 'Unknown Owner',
      siteAddress: (row['address'] as String?) ?? 'Unknown Address',
      contactNo: row['owner_contact'] as String?,
      latitude: resolvedCoords.$1,
      longitude: resolvedCoords.$2,
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
      wallMaterials: wallMaterials.isEmpty ? null : wallMaterials,
      doorMaterials: doorMaterials.isEmpty ? null : doorMaterials,
      floorMaterials: floorMaterials.isEmpty ? null : floorMaterials,
      roofMaterials: roofMaterials.isEmpty ? null : roofMaterials,
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
      updatedBy: row['user_id'] as String?,
      buildingPhotoUrl: row['building_photo_url'] as String?,
    );
  }

  Future<void> _persistSiteCoordinates(
    String siteId,
    double? latitude,
    double? longitude,
  ) async {
    if (latitude == null || longitude == null) return;

    await _supabase.from('site').update({
      'latitude': latitude,
      'longitude': longitude,
    }).eq('site_id', siteId);
  }

  (double?, double?) _resolveCoordinatesFromRow(Map<String, dynamic> row) {
    final directLat = (row['latitude'] as num?)?.toDouble();
    final directLng = (row['longitude'] as num?)?.toDouble();
    if (directLat != null && directLng != null) {
      return (directLat, directLng);
    }

    final location = row['location'];
    if (location is String) {
      final pointMatch = RegExp(r'POINT\s*\(([-0-9.]+)\s+([-0-9.]+)\)')
          .firstMatch(location);
      if (pointMatch != null) {
        final lng = double.tryParse(pointMatch.group(1)!);
        final lat = double.tryParse(pointMatch.group(2)!);
        if (lat != null && lng != null) {
          return (lat, lng);
        }
      }
    }

    if (location is Map<String, dynamic>) {
      final coords = location['coordinates'];
      if (coords is List && coords.length >= 2) {
        final lng = (coords[0] as num?)?.toDouble();
        final lat = (coords[1] as num?)?.toDouble();
        if (lat != null && lng != null) {
          return (lat, lng);
        }
      }
    }

    return (directLat, directLng);
  }

  Defect _mapDefectFromRow(Map<String, dynamic> row, String inspectionId) {
    return Defect(
      id: (row['defect_id'] as String?) ?? '',
      inspectionId: inspectionId,
      notation: DefectNotation.values.firstWhere(
        (e) => e.code == (row['notation'] as String?),
        orElse: () => DefectNotation.c,
      ),
      category: DefectCategory.values.firstWhere(
        (e) => e.name == (row['defect_category'] as String?),
        orElse: () => DefectCategory.buildingFloor,
      ),
      floorLevel: row['floor_level'] as String?,
      lengthMm: _parseDouble(row['length_mm']) ?? 0,
      widthMm: _parseDouble(row['width_mm']),
      remarks: row['remarks'] as String?,
      photoPath: (row['photo_url'] as String?) ?? (row['photo_path'] as String?),
      photoUrl: row['photo_url'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Populate defect_info for all defects in an inspection
  /// This is done separately because nested defect_info queries fail with RLS policies
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

