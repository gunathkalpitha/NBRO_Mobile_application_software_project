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
  Future<void> createInspection(Inspection inspection) async {
    try {
      // Insert site data
      await _supabase.from('sites').insert(inspection.toJson());

      // Insert defects if any
      if (inspection.defects.isNotEmpty) {
        final defectsJson = inspection.defects
            .map((defect) => defect.toJson())
            .toList();
        await _supabase.from('defects').insert(defectsJson);

        // Upload defect photos
        for (final defect in inspection.defects) {
          if (defect.photoPath != null) {
            await _uploadDefectPhoto(defect.id, defect.photoPath!);
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to create inspection: $e');
    }
  }

  /// Get all inspections for the current user
  Future<List<Inspection>> getInspections() async {
    try {
      final response = await _supabase
          .from('sites')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Inspection.fromJson(json))
          .toList();
    } catch (e) {
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
      
      // Add defects to inspection
      final defects = defectsResponse
          .map((json) => Defect.fromJson(json as Map<String, dynamic>))
          .toList();
      
      return inspection.copyWith(defects: defects);
    } catch (e) {
      throw Exception('Failed to get inspection: $e');
    }
  }

  /// Update an existing inspection
  Future<void> updateInspection(Inspection inspection) async {
    try {
      await _supabase
          .from('sites')
          .update(inspection.toJson())
          .eq('building_reference_no', inspection.id);
    } catch (e) {
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
        await _uploadDefectPhoto(defect.id, defect.photoPath!);
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

  /// Upload defect photo to Supabase Storage
  Future<String> _uploadDefectPhoto(String defectId, String photoPath) async {
    try {
      final file = File(photoPath);
      if (!await file.exists()) {
        throw Exception('Photo file not found: $photoPath');
      }

      // Create a unique file name
      final fileName = 'defect_${defectId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'defects/$defectId/$fileName';

      // Upload to Supabase Storage
      await _supabase.storage
          .from('inspection-photos')
          .upload(storagePath, file);

      // Get public URL
      final publicUrl = _supabase.storage
          .from('inspection-photos')
          .getPublicUrl(storagePath);

      // Update defect record with photo URL
      await _supabase
          .from('defect_media')
          .insert({
            'defect_id': defectId,
            'storage_path': storagePath,
            'photo_url': publicUrl,
            'file_size': await file.length(),
          });

      return publicUrl;
    } catch (e) {
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
