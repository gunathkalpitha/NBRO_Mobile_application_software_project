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
  Future<void> createInspection(Inspection inspection, {String? buildingPhotoPath}) async {
    try {
      debugPrint('[Repository] Starting inspection save...');
      debugPrint('[Repository] Inspection ID: ${inspection.id}');
      debugPrint('[Repository] Site address: ${inspection.siteAddress}');
      debugPrint('[Repository] Defects count: ${inspection.defects.length}');
      debugPrint('[Repository] Building photo path: $buildingPhotoPath');
      
      // Get current user ID
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }
      debugPrint('[Repository] Current user ID: ${currentUser.id}');
      
      // Upload building photo if provided
      String? buildingPhotoUrl;
      if (buildingPhotoPath != null) {
        buildingPhotoUrl = await _uploadBuildingPhoto(inspection.id, buildingPhotoPath);
        debugPrint('[Repository] ✅ Building photo uploaded: $buildingPhotoUrl');
      }
      
      // Add user ID and building photo URL to inspection
      final inspectionWithUser = inspection.copyWith(
        createdBy: currentUser.id,
        buildingPhotoUrl: buildingPhotoUrl,
      );
      
      // Insert site data
      final siteJson = inspectionWithUser.toJson();
      debugPrint('[Repository] Site JSON: $siteJson');
      
      await _supabase.from('sites').insert(siteJson);
      debugPrint('[Repository] ✅ Site inserted successfully');

      // Insert defects if any
      if (inspection.defects.isNotEmpty) {
        final defectsJson = inspection.defects
            .map((defect) => defect.toJson())
            .toList();
        debugPrint('[Repository] Defects JSON: $defectsJson');
        
        await _supabase.from('defects').insert(defectsJson);
        debugPrint('[Repository] ✅ Defects inserted successfully');

        // Upload defect photos
        for (final defect in inspection.defects) {
          if (defect.photoPath != null) {
            await _uploadDefectPhoto(defect.id, inspection.id, defect.photoPath!);
            debugPrint('[Repository] ✅ Photo uploaded for defect ${defect.id}');
          }
        }
      }
      
      // Update sync status to 'synced' since save was successful
      await _supabase
          .from('sites')
          .update({'sync_status': 'synced'})
          .eq('building_reference_no', inspection.id);
      
      debugPrint('[Repository] ✅ Inspection save completed and marked as synced');
    } catch (e, stackTrace) {
      debugPrint('[Repository] ❌ ERROR saving inspection: $e');
      debugPrint('[Repository] Stack trace: $stackTrace');
      throw Exception('Failed to create inspection: $e');
    }
  }

  /// Get all inspections for the current user
  Future<List<Inspection>> getInspections() async {
    try {
      debugPrint('[Repository] Loading inspections from database...');
      final response = await _supabase
          .from('sites')
          .select()
          .order('created_at', ascending: false);

      final inspections = <Inspection>[];
      
      for (final siteJson in response as List) {
        final inspection = Inspection.fromJson(siteJson);
        
        // Load defects for this inspection
        try {
          final defectsResponse = await _supabase
              .from('defects')
              .select()
              .eq('building_reference_no', inspection.id)
              .order('created_at', ascending: true) as List<dynamic>;

          // Fetch photo URLs from defect_media table
          final defects = <Defect>[];
          for (final defectJson in defectsResponse) {
            final defect = Defect.fromJson(defectJson as Map<String, dynamic>);
            
            // Get photo URL from defect_media table
            final mediaResponse = await _supabase
                .from('defect_media')
                .select('storage_url')
                .eq('defect_id', defect.id)
                .limit(1)
                .maybeSingle();
            
            if (mediaResponse != null) {
              final photoUrl = mediaResponse['storage_url'] as String?;
              defects.add(Defect(
                id: defect.id,
                inspectionId: defect.inspectionId,
                notation: defect.notation,
                category: defect.category,
                floorLevel: defect.floorLevel,
                lengthMm: defect.lengthMm,
                widthMm: defect.widthMm,
                photoPath: defect.photoPath,
                remarks: defect.remarks,
                createdAt: defect.createdAt,
                photoUrl: photoUrl,
              ));
            } else {
              defects.add(defect);
            }
          }
          
          debugPrint('[Repository] Loaded ${defects.length} defects for inspection ${inspection.id}');
          
          inspections.add(inspection.copyWith(defects: defects));
        } catch (e) {
          debugPrint('[Repository] Error loading defects for ${inspection.id}: $e');
          // Add inspection without defects if defect loading fails
          inspections.add(inspection);
        }
      }
      
      debugPrint('[Repository] Loaded ${inspections.length} inspections');
      return inspections;
    } catch (e) {
      debugPrint('[Repository] Error loading inspections: $e');
      throw Exception('Failed to get inspections: $e');
    }
  }

  /// Get a single inspection with its defects
  Future<Inspection?> getInspection(String id) async {
    try {
      // Get site data
      final siteResponse = await _supabase
          .from('sites')
          .select()
          .eq('building_reference_no', id)
          .maybeSingle();

      if (siteResponse == null) return null;

      // Get defects for this site
      final defectsResponse = await _supabase
          .from('defects')
          .select()
          .eq('building_reference_no', id)
          .order('created_at', ascending: true) as List<dynamic>;

      final inspection = Inspection.fromJson(siteResponse);
      
      // Add defects to inspection with photo URLs from defect_media
      final defects = <Defect>[];
      for (final defectJson in defectsResponse) {
        final defect = Defect.fromJson(defectJson as Map<String, dynamic>);
        
        // Get photo URL from defect_media table
        final mediaResponse = await _supabase
            .from('defect_media')
            .select('storage_url')
            .eq('defect_id', defect.id)
            .limit(1)
            .maybeSingle();
        
        if (mediaResponse != null) {
          final photoUrl = mediaResponse['storage_url'] as String?;
          defects.add(Defect(
            id: defect.id,
            inspectionId: defect.inspectionId,
            notation: defect.notation,
            category: defect.category,
            floorLevel: defect.floorLevel,
            lengthMm: defect.lengthMm,
            widthMm: defect.widthMm,
            photoPath: defect.photoPath,
            remarks: defect.remarks,
            createdAt: defect.createdAt,
            photoUrl: photoUrl,
          ));
        } else {
          defects.add(defect);
        }
      }
      
      return inspection.copyWith(defects: defects);
    } catch (e) {
      throw Exception('Failed to get inspection: $e');
    }
  }

  /// Update an existing inspection
  Future<void> updateInspection(Inspection inspection) async {
    try {
      debugPrint('[Repository] Updating inspection ${inspection.id}...');
      final updateData = inspection.copyWith(
        updatedAt: DateTime.now(),
      ).toJson();
      debugPrint('[Repository] Update data: $updateData');
      
      await _supabase
          .from('sites')
          .update(updateData)
          .eq('building_reference_no', inspection.id);
      
      debugPrint('[Repository] ✅ Inspection updated successfully in database');
    } catch (e) {
      debugPrint('[Repository] ❌ ERROR updating inspection: $e');
      throw Exception('Failed to update inspection: $e');
    }
  }

  /// Delete an inspection and all its defects
  Future<void> deleteInspection(String id) async {
    try {
      // Delete all defects first (cascading delete should handle this, but explicit is safer)
      await _supabase
          .from('defects')
          .delete()
          .eq('building_reference_no', id);

      // Delete the site
      await _supabase
          .from('sites')
          .delete()
          .eq('building_reference_no', id);
    } catch (e) {
      throw Exception('Failed to delete inspection: $e');
    }
  }

  /// Add a defect to an existing inspection
  Future<void> addDefect(Defect defect) async {
    try {
      await _supabase.from('defects').insert(defect.toJson());

      // Upload photo if exists
      if (defect.photoPath != null) {
        await _uploadDefectPhoto(defect.id, defect.inspectionId, defect.photoPath!);
      }
    } catch (e) {
      throw Exception('Failed to add defect: $e');
    }
  }

  /// Update an existing defect
  Future<void> updateDefect(Defect defect) async {
    try {
      await _supabase
          .from('defects')
          .update(defect.toJson())
          .eq('defect_id', defect.id);
    } catch (e) {
      throw Exception('Failed to update defect: $e');
    }
  }

  /// Delete a defect
  Future<void> deleteDefect(String defectId) async {
    try {
      // Delete photo from storage first
      await _deleteDefectPhoto(defectId);

      // Delete the defect record
      await _supabase
          .from('defects')
          .delete()
          .eq('defect_id', defectId);
    } catch (e) {
      throw Exception('Failed to delete defect: $e');
    }
  }

  /// Get all defects for a specific inspection
  Future<List<Defect>> getDefects(String inspectionId) async {
    try {
      final response = await _supabase
          .from('defects')
          .select()
          .eq('building_reference_no', inspectionId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => Defect.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to get defects: $e');
    }
  }

  /// Search inspections by owner name or site address
  Future<List<Inspection>> searchInspections(String query) async {
    try {
      final response = await _supabase
          .from('sites')
          .select()
          .or('owner_name.ilike.%$query%,site_address.ilike.%$query%')
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
          .from('sites')
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
          .from('sites')
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
      // Total inspections
      final totalResponse = await _supabase
          .from('sites')
          .select('building_reference_no');
      final total = (totalResponse as List).length;

      // Pending inspections
      final pendingResponse = await _supabase
          .from('sites')
          .select('building_reference_no')
          .eq('sync_status', 'pending');
      final pending = (pendingResponse as List).length;

      // Synced inspections
      final syncedResponse = await _supabase
          .from('sites')
          .select('building_reference_no')
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

  /// Upload building photo to Supabase Storage
  Future<String> _uploadBuildingPhoto(String buildingReferenceNo, String photoPath) async {
    try {
      final file = File(photoPath);
      if (!await file.exists()) {
        throw Exception('Photo file not found: $photoPath');
      }

      // Create a unique file name
      final fileName = 'building_${buildingReferenceNo}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'buildings/$buildingReferenceNo/$fileName';

      debugPrint('[Repository] Uploading building photo: $fileName');
      
      // Upload to Supabase Storage with proper content type
      await _supabase.storage
          .from('inspection-photos')
          .upload(
            storagePath, 
            file,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
            ),
          );

      debugPrint('[Repository] ✅ Building photo uploaded to storage');

      // Get public URL
      final publicUrl = _supabase.storage
          .from('inspection-photos')
          .getPublicUrl(storagePath);

      debugPrint('[Repository] Building photo URL: $publicUrl');

      return publicUrl;
    } catch (e, stackTrace) {
      debugPrint('[Repository] ❌ ERROR uploading building photo: $e');
      debugPrint('[Repository] Stack trace: $stackTrace');
      throw Exception('Failed to upload building photo: $e');
    }
  }

  /// Upload defect photo to Supabase Storage
  Future<String> _uploadDefectPhoto(String defectId, String buildingReferenceNo, String photoPath) async {
    try {
      final file = File(photoPath);
      if (!await file.exists()) {
        throw Exception('Photo file not found: $photoPath');
      }

      // Create a unique file name
      final fileName = 'defect_${defectId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'defects/$defectId/$fileName';

      debugPrint('[Repository] Uploading photo: $fileName');
      
      // Upload to Supabase Storage with proper content type
      await _supabase.storage
          .from('inspection-photos')
          .upload(
            storagePath, 
            file,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
            ),
          );

      debugPrint('[Repository] ✅ Photo uploaded to storage');

      // Get public URL
      final publicUrl = _supabase.storage
          .from('inspection-photos')
          .getPublicUrl(storagePath);

      debugPrint('[Repository] Photo URL: $publicUrl');

      // Insert defect media record with all required fields
      await _supabase
          .from('defect_media')
          .insert({
            'defect_id': defectId,
            'building_reference_no': buildingReferenceNo,
            'storage_path': storagePath,
            'storage_url': publicUrl,
            'file_name': fileName,
            'file_size': await file.length(),
            'mime_type': 'image/jpeg',
          });

      debugPrint('[Repository] ✅ Defect media record inserted');

      return publicUrl;
    } catch (e, stackTrace) {
      debugPrint('[Repository] ❌ ERROR uploading photo: $e');
      debugPrint('[Repository] Stack trace: $stackTrace');
      throw Exception('Failed to upload photo: $e');
    }
  }

  /// Delete defect photo from storage
  Future<void> _deleteDefectPhoto(String defectId) async {
    try {
      // Get all media records for this defect
      final mediaResponse = await _supabase
          .from('defect_media')
          .select('storage_path')
          .eq('defect_id', defectId) as List<dynamic>;

      for (final media in mediaResponse) {
        final storagePath = media['storage_path'] as String;
        
        // Delete from storage
        await _supabase.storage
            .from('inspection-photos')
            .remove([storagePath]);
      }

      // Delete media records
      await _supabase
          .from('defect_media')
          .delete()
          .eq('defect_id', defectId);
    } catch (e) {
      // Non-critical error, log but don't throw
      if (kDebugMode) {
        print('Warning: Failed to delete defect photo: $e');
      }
    }
  }

  /// Get photo URL for a defect
  Future<String?> getDefectPhotoUrl(String defectId) async {
    try {
      final response = await _supabase
          .from('defect_media')
          .select('photo_url')
          .eq('defect_id', defectId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response?['photo_url'] as String?;
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
      // Check if inspection exists
      final existing = await _supabase
          .from('sites')
          .select('building_reference_no')
          .eq('building_reference_no', inspection.id)
          .maybeSingle();

      if (existing != null) {
        // Update existing
        await updateInspection(inspection);
      } else {
        // Create new
        await createInspection(inspection);
      }

      // Update sync status to synced
      await _supabase
          .from('sites')
          .update({'sync_status': 'synced', 'updated_at': DateTime.now().toIso8601String()})
          .eq('building_reference_no', inspection.id);
    } catch (e) {
      // Update sync status to error
      await _supabase
          .from('sites')
          .update({'sync_status': 'error', 'updated_at': DateTime.now().toIso8601String()})
          .eq('building_reference_no', inspection.id);
      
      throw Exception('Failed to sync inspection: $e');
    }
  }
}
