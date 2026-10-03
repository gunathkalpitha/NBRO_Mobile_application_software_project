import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';
import 'package:nbro_mobile_application/data/local/datasources/local_inspection_datasource.dart';
import 'package:nbro_mobile_application/core/services/officer_name_resolver.dart';
import 'package:nbro_mobile_application/core/services/profile_state_service.dart';
import 'package:nbro_mobile_application/core/storage/image_storage_service.dart';
import 'package:nbro_mobile_application/core/sync/sync_service.dart';
import 'package:nbro_mobile_application/core/network/connectivity_service.dart';
import 'package:uuid/uuid.dart';

/// Offline-First Repository for managing inspections
class InspectionRepository {
  final SupabaseClient _supabase;
  final LocalInspectionDataSource _localDataSource = LocalInspectionDataSource();
  final ImageStorageService _imageStorage = ImageStorageService.instance;
  final SyncService _syncService = SyncService.instance;

  InspectionRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Create a new inspection locally (Offline-First) and initiate background sync
  Future<void> createInspection(
    Inspection inspection, {
    String? buildingPhotoPath,
  }) async {
    try {
      final currentUser = _supabase.auth.currentUser;
      final userId = currentUser?.id ?? inspection.createdBy ?? 'local_user';

      // 1. Save building photo locally if provided
      String? localBuildingPhotoPath;
      if (buildingPhotoPath != null) {
        localBuildingPhotoPath = await _imageStorage.saveImageLocally(
          sourcePath: buildingPhotoPath,
          inspectionLocalId: inspection.id,
          customFileName: 'building_front.jpg',
        );
      }

      // 2. Save defect photos locally
      final defectsWithLocalPhotos = <Defect>[];
      for (final defect in inspection.defects) {
        String? localDefectPhotoPath = defect.photoPath;
        if (defect.photoPath != null && defect.photoPath!.isNotEmpty) {
          localDefectPhotoPath = await _imageStorage.saveImageLocally(
            sourcePath: defect.photoPath!,
            inspectionLocalId: inspection.id,
            customFileName: 'defect_${defect.id}.jpg',
          );
        }
        defectsWithLocalPhotos.add(
          Defect(
            id: defect.id,
            inspectionId: defect.inspectionId,
            notation: defect.notation,
            category: defect.category,
            floorLevel: defect.floorLevel,
            lengthMm: defect.lengthMm,
            widthMm: defect.widthMm,
            photoPath: localDefectPhotoPath ?? defect.photoPath,
            photoUrl: defect.photoUrl,
            remarks: defect.remarks,
            createdAt: defect.createdAt,
          ),
        );
      }

      final inspectionToSave = inspection.copyWith(
        createdBy: userId,
        defects: defectsWithLocalPhotos,
        syncStatus: SyncStatus.pending,
      );

      // 3. Save to local SQLite database atomically
      await _localDataSource.saveInspection(
        inspectionToSave,
        buildingPhotoLocalPath: localBuildingPhotoPath,
      );

      // 4. Trigger background sync if online
      _syncService.triggerSync().catchError((e) {
        debugPrint('[InspectionRepository] Background sync trigger failed: $e');
      });
    } catch (e, stackTrace) {
      debugPrint('[InspectionRepository] ❌ ERROR saving inspection locally: $e');
      debugPrint('[InspectionRepository] Stack trace: $stackTrace');
      throw Exception('Failed to save inspection: $e');
    }
  }

  /// Check if the currently logged in user is an Administrator (Main, Super, or Regional Admin)
  Future<bool> isUserAdmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final role = await _getUserRole(user.id, user.email ?? '');
    return role.contains('admin');
  }

  Future<String> _getUserRole(String userId, String email) async {
    final lowerEmail = email.toLowerCase();
    if (lowerEmail == 'admin@gmail.com') return 'super_admin';
    if (lowerEmail == 'mainadminnbro@gmail.com') return 'main_admin';

    // 1. Check cached profile
    final profile = ProfileStateService.notifier.value;
    if (profile != null && profile.role.isNotEmpty) {
      return profile.role.toLowerCase();
    }

    // 2. Query DB profile
    try {
      final res = await _supabase
          .from('profile')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      if (res != null && res['role'] != null) {
        return (res['role'] as String).toLowerCase();
      }
    } catch (_) {}

    if (lowerEmail.startsWith('admin.') || lowerEmail.contains('admin')) {
      return 'admin';
    }

    return 'officer';
  }

  Future<Set<String>> _getOfficersCreatedBy(String adminId) async {
    try {
      final res = await _supabase
          .from('profile')
          .select('id, full_name')
          .eq('created_by', adminId);

      final ids = <String>{};
      for (final row in (res as List)) {
        if (row['id'] != null) ids.add(row['id'] as String);
        if (row['full_name'] != null && (row['full_name'] as String).trim().isNotEmpty) {
          ids.add((row['full_name'] as String).trim());
        }
      }
      return ids;
    } catch (e) {
      debugPrint('[InspectionRepository] _getOfficersCreatedBy error: $e');
      return {};
    }
  }

  /// Get inspections based on role boundaries:
  /// - Super Admin (admin@gmail.com): Returns empty list (Data Privacy for Dev Team).
  /// - Main Admin (mainadminnbro@gmail.com): Sees ALL inspections across Sri Lanka.
  /// - Regional Admin (sub-admin): Sees ONLY inspections created by officers HE created/manages.
  /// - Field Officer: Sees ONLY inspections created by himself.
  Future<List<Inspection>> getInspections() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return await _localDataSource.getAllInspections();

      final email = currentUser.email?.toLowerCase() ?? '';
      final role = await _getUserRole(currentUser.id, email);

      final isSuperAdmin = role == 'super_admin' || email == 'admin@gmail.com';
      final isMainAdmin = role == 'main_admin' || email == 'mainadminnbro@gmail.com';
      final isRegionalAdmin = !isSuperAdmin && !isMainAdmin && (role.contains('admin') || email.startsWith('admin.'));

      // 1. Super Admin (admin@gmail.com): Dev/System Admin has no access to sensitive field surveys
      if (isSuperAdmin) {
        return [];
      }

      // 2. Determine officers created by this admin if Regional Admin
      Set<String> managedOfficerIds = {};
      if (isRegionalAdmin) {
        managedOfficerIds = await _getOfficersCreatedBy(currentUser.id);
      }

      // 3. Fetch local inspections first
      List<Inspection> localInspections = await _localDataSource.getAllInspections();

      // 4. If online, try syncing and fetching remote records
      final isOnline = await ConnectivityService.instance.checkActualConnectivity();
      if (isOnline) {
        _syncService.triggerSync().catchError((_) {});

        try {
          final remoteInspections = await _fetchRemoteInspections(
            isMainAdmin: isMainAdmin,
            isRegionalAdmin: isRegionalAdmin,
            managedOfficerIds: managedOfficerIds,
            userId: currentUser.id,
          );
          for (final remote in remoteInspections) {
            await _localDataSource.saveInspection(remote);
          }
          localInspections = await _localDataSource.getAllInspections();
        } catch (e) {
          debugPrint('[InspectionRepository] Remote fetch failed ($e), serving local cache.');
        }
      }

      // 5. Apply local list filtering based on role
      if (isMainAdmin) {
        return localInspections; // Main Admin sees all
      } else if (isRegionalAdmin) {
        // Regional Admin sees ONLY inspections from officers HE created
        if (managedOfficerIds.isEmpty) {
          return [];
        }

        return localInspections.where((inspection) {
          final creator = (inspection.createdBy ?? '').trim();
          if (creator.isEmpty) return false;

          // Direct ID or Name match
          if (managedOfficerIds.contains(creator)) return true;

          // Case-insensitive match (excluding generic fallback strings)
          final lowerCreator = creator.toLowerCase();
          for (final id in managedOfficerIds) {
            final lowerId = id.toLowerCase();
            if (lowerId == lowerCreator && lowerId != 'government officer' && lowerId != 'officer') {
              return true;
            }
          }
          return false;
        }).toList();
      } else {
        // Field Officer sees only his own created inspections
        final currentUserId = currentUser.id;
        final currentEmail = currentUser.email;

        return localInspections.where((inspection) {
          final creator = inspection.createdBy;
          if (creator == null || creator.isEmpty) return false;
          return creator == currentUserId ||
                 creator == currentEmail ||
                 OfficerNameResolver.resolve(creator) == OfficerNameResolver.resolve(currentUserId);
        }).toList();
      }
    } catch (e) {
      debugPrint('[InspectionRepository] Failed to get inspections: $e');
      return await _localDataSource.getAllInspections();
    }
  }

  /// Get a single inspection by ID
  Future<Inspection?> getInspectionById(String id) async {
    final local = await _localDataSource.getInspection(id);
    if (local != null) return local;

    final isOnline = await ConnectivityService.instance.checkActualConnectivity();
    if (isOnline) {
      try {
        final remote = await _fetchSingleRemoteInspection(id);
        if (remote != null) {
          await _localDataSource.saveInspection(remote);
          return remote;
        }
      } catch (e) {
        debugPrint('[InspectionRepository] Single remote fetch failed: $e');
      }
    }
    return null;
  }

  /// Update existing inspection
  Future<void> updateInspection(Inspection updatedInspection, {String? newBuildingPhotoPath}) async {
    await createInspection(updatedInspection, buildingPhotoPath: newBuildingPhotoPath);
  }

  /// Delete inspection
  Future<void> deleteInspection(String id) async {
    await _localDataSource.deleteInspection(id);
    await _imageStorage.deleteInspectionDirectory(id);

    final isOnline = await ConnectivityService.instance.checkActualConnectivity();
    if (isOnline) {
      try {
        await _supabase.from('site').delete().eq('building_ref', id);
      } catch (e) {
        debugPrint('[InspectionRepository] Remote delete failed: $e');
      }
    }
  }

  // --- Remote Supabase Helpers ---

  Future<List<Inspection>> _fetchRemoteInspections({
    bool isMainAdmin = false,
    bool isRegionalAdmin = false,
    Set<String> managedOfficerIds = const {},
    String? userId,
  }) async {
    final profileMap = await _getProfileNamesMap();
    dynamic query = _supabase.from('site').select('''
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
          updated_by,
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
        ''');

    if (!isMainAdmin) {
      if (isRegionalAdmin) {
        final uuidList = managedOfficerIds.where((id) => RegExp(r'^[0-9a-fA-F]{8}-').hasMatch(id)).toList();
        if (uuidList.isNotEmpty) {
          query = query.inFilter('user_id', uuidList);
        } else {
          return [];
        }
      } else if (userId != null && userId.isNotEmpty) {
        query = query.eq('user_id', userId);
      }
    }

    final response = await query.order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((json) => _mapInspectionFromSiteRow(
              json as Map<String, dynamic>,
              profileMap: profileMap,
            ))
        .toList();
  }

  Future<Inspection?> _fetchSingleRemoteInspection(String id) async {
    final profileMap = await _getProfileNamesMap();
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
          updated_by,
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
        .or('site_id.eq.$id,building_ref.eq.$id')
        .maybeSingle();

    if (response == null) return null;
    return _mapInspectionFromSiteRow(
      response,
      profileMap: profileMap,
    );
  }

  Future<Map<String, String>> _getProfileNamesMap() async {
    try {
      final res = await _supabase.from('profile').select('id, full_name');
      final map = <String, String>{};
      for (final item in (res as List)) {
        if (item['id'] != null && item['full_name'] != null && (item['full_name'] as String).trim().isNotEmpty) {
          map[item['id'] as String] = (item['full_name'] as String).trim();
        }
      }
      final currentUser = _supabase.auth.currentUser;
      if (currentUser != null) {
        final name = currentUser.userMetadata?['full_name'] ?? currentUser.userMetadata?['name'] ?? currentUser.email?.split('@').first;
        if (name != null) {
          map[currentUser.id] = name;
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Inspection _mapInspectionFromSiteRow(
    Map<String, dynamic> row, {
    Map<String, String> profileMap = const {},
  }) {
    final rawObservation = row['general_observation'];
    final observation = rawObservation is List
        ? (rawObservation.isNotEmpty ? rawObservation.first as Map<String, dynamic> : <String, dynamic>{})
        : (rawObservation as Map<String, dynamic>?) ?? <String, dynamic>{};

    final rawServices = row['external_services'];
    final services = rawServices is List
        ? (rawServices.isNotEmpty ? rawServices.first as Map<String, dynamic> : <String, dynamic>{})
        : (rawServices as Map<String, dynamic>?) ?? <String, dynamic>{};

    final rawBuilding = row['main_building'];
    final building = rawBuilding is List
        ? (rawBuilding.isNotEmpty ? rawBuilding.first as Map<String, dynamic> : <String, dynamic>{})
        : (rawBuilding as Map<String, dynamic>?) ?? <String, dynamic>{};

    final rawSpecs = building['specification'];
    final specList = rawSpecs is List ? rawSpecs : <dynamic>[];

    final wallMaterials = <String, bool>{};
    final doorMaterials = <String, bool>{};
    final floorMaterials = <String, bool>{};
    final roofMaterials = <String, bool>{};
    String? roofCovering;

    for (final s in specList) {
      if (s is Map<String, dynamic>) {
        final elementType = s['element_type'] as String?;
        final isUsed = s['is_used'] == true;
        if (elementType != null && isUsed) {
          final parts = elementType.split('|');
          if (parts.length == 2) {
            final scope = parts[0].toLowerCase();
            final value = parts[1];
            if (scope == 'wall') wallMaterials[value] = true;
            if (scope == 'door') doorMaterials[value] = true;
            if (scope == 'floor') floorMaterials[value] = true;
            if (scope == 'roof') roofMaterials[value] = true;
            if (scope == 'roofcovering') roofCovering = value;
          } else if (parts.length == 1 && elementType.trim().isNotEmpty) {
            wallMaterials[elementType.trim()] = true;
          }
        }
      }
    }

    final rawDefects = row['defects'];
    final defectList = rawDefects is List ? rawDefects : <dynamic>[];
    final mappedDefects = defectList
        .whereType<Map<String, dynamic>>()
        .map((json) => Defect(
              id: (json['defect_id'] as String?) ?? const Uuid().v4(),
              inspectionId: (row['building_ref'] as String?) ?? 'UNKNOWN',
              notation: DefectNotation.values.firstWhere(
                (e) => e.code == json['notation'],
                orElse: () => DefectNotation.c,
              ),
              category: DefectCategory.values.firstWhere(
                (e) => e.name == json['defect_category'],
                orElse: () => DefectCategory.buildingFloor,
              ),
              floorLevel: json['floor_level'] as String?,
              lengthMm: (json['length_mm'] as num?)?.toDouble() ?? 0.0,
              widthMm: (json['width_mm'] as num?)?.toDouble(),
              photoPath: json['photo_path'] as String?,
              photoUrl: json['photo_url'] as String?,
              remarks: json['remarks'] as String?,
              createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
            ))
        .toList();

    // Deduplicate defects by content key to guarantee zero duplicate displays
    final seenKeys = <String>{};
    final uniqueDefects = <Defect>[];
    for (final d in mappedDefects) {
      final key = '${d.notation.code}_${d.category.name}_${d.floorLevel}_${d.lengthMm}_${d.widthMm}_${d.remarks}';
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        uniqueDefects.add(d);
      }
    }

    final userId = row['user_id'] as String?;
    final updatedBy = row['updated_by'] as String?;

    return Inspection(
      id: (row['building_ref'] as String?) ?? (row['site_id'] as String),
      ownerName: (row['owner_name'] as String?) ?? 'Unknown Owner',
      siteAddress: (row['address'] as String?) ?? 'Unknown Address',
      contactNo: row['owner_contact'] as String?,
      latitude: row['latitude'] != null ? (row['latitude'] as num).toDouble() : null,
      longitude: row['longitude'] != null ? (row['longitude'] as num).toDouble() : null,
      distanceFromRow: (row['distance_from_row'] as num?)?.toDouble(),
      ageOfStructure: int.tryParse(observation['approx_age']?.toString() ?? ''),
      typeOfStructure: observation['type'] as String?,
      presentCondition: observation['present_condition'] as String?,
      hasPipeBorneWater: services['pipe_born_water_supply'] != null
          ? !services['pipe_born_water_supply'].toString().toLowerCase().contains('not available')
          : false,
      waterSource: services['pipe_born_water_supply'] as String?,
      hasElectricity: services['electricity_source'] != null
          ? !services['electricity_source'].toString().toLowerCase().contains('not available')
          : false,
      electricitySource: services['electricity_source'] as String?,
      hasSewageWaste: services['sewage_waste'] != null
          ? !services['sewage_waste'].toString().toLowerCase().contains('not available')
          : false,
      sewageType: services['sewage_waste'] as String?,
      numberOfFloors: building['no_floors'] as String?,
      wallMaterials: wallMaterials.isNotEmpty ? wallMaterials : null,
      doorMaterials: doorMaterials.isNotEmpty ? doorMaterials : null,
      floorMaterials: floorMaterials.isNotEmpty ? floorMaterials : null,
      roofMaterials: roofMaterials.isNotEmpty ? roofMaterials : null,
      roofCovering: roofCovering,
      defects: uniqueDefects,
      syncStatus: SyncStatus.synced,
      createdAt: row['created_at'] != null ? DateTime.parse(row['created_at'] as String) : DateTime.now(),
      updatedAt: row['updated_at'] != null ? DateTime.parse(row['updated_at'] as String) : null,
      createdBy: OfficerNameResolver.resolve(profileMap[userId] ?? userId),
      updatedBy: OfficerNameResolver.resolve(profileMap[updatedBy] ?? updatedBy),
      buildingPhotoUrl: row['building_photo_url'] as String?,
    );
  }
}
