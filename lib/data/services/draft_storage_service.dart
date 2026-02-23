import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service to manage draft inspections stored locally
class DraftStorageService {
  static const String _draftKey = 'inspection_drafts';
  static const String _draftTimestampKey = 'draft_timestamps';

  /// Save a draft inspection
  Future<void> saveDraft({
    required String draftId,
    required Map<String, dynamic> draftData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing drafts
      final draftsJson = prefs.getString(_draftKey) ?? '{}';
      final drafts = Map<String, dynamic>.from(jsonDecode(draftsJson));
      
      // Get existing timestamps
      final timestampsJson = prefs.getString(_draftTimestampKey) ?? '{}';
      final timestamps = Map<String, dynamic>.from(jsonDecode(timestampsJson));
      
      // Add current draft
      drafts[draftId] = draftData;
      timestamps[draftId] = DateTime.now().toIso8601String();
      
      // Save back
      await prefs.setString(_draftKey, jsonEncode(drafts));
      await prefs.setString(_draftTimestampKey, jsonEncode(timestamps));
      
      debugPrint('✅ Draft saved: $draftId');
    } catch (e) {
      debugPrint('❌ Error saving draft: $e');
      rethrow;
    }
  }

  /// Get a specific draft by ID
  Future<Map<String, dynamic>?> getDraft(String draftId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftsJson = prefs.getString(_draftKey) ?? '{}';
      final drafts = Map<String, dynamic>.from(jsonDecode(draftsJson));
      
      return drafts[draftId] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('❌ Error getting draft: $e');
      return null;
    }
  }

  /// Get all drafts
  Future<List<Map<String, dynamic>>> getAllDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftsJson = prefs.getString(_draftKey) ?? '{}';
      final timestampsJson = prefs.getString(_draftTimestampKey) ?? '{}';
      
      final drafts = Map<String, dynamic>.from(jsonDecode(draftsJson));
      final timestamps = Map<String, dynamic>.from(jsonDecode(timestampsJson));
      
      final draftList = <Map<String, dynamic>>[];
      
      for (final entry in drafts.entries) {
        final draftData = Map<String, dynamic>.from(entry.value as Map);
        draftData['draft_id'] = entry.key;
        draftData['saved_at'] = timestamps[entry.key] ?? DateTime.now().toIso8601String();
        draftList.add(draftData);
      }
      
      // Sort by saved_at (most recent first)
      draftList.sort((a, b) {
        final aTime = DateTime.parse(a['saved_at'] as String);
        final bTime = DateTime.parse(b['saved_at'] as String);
        return bTime.compareTo(aTime);
      });
      
      return draftList;
    } catch (e) {
      debugPrint('❌ Error getting all drafts: $e');
      return [];
    }
  }

  /// Delete a specific draft
  Future<void> deleteDraft(String draftId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing drafts and timestamps
      final draftsJson = prefs.getString(_draftKey) ?? '{}';
      final timestampsJson = prefs.getString(_draftTimestampKey) ?? '{}';
      
      final drafts = Map<String, dynamic>.from(jsonDecode(draftsJson));
      final timestamps = Map<String, dynamic>.from(jsonDecode(timestampsJson));
      
      // Remove the draft
      drafts.remove(draftId);
      timestamps.remove(draftId);
      
      // Save back
      await prefs.setString(_draftKey, jsonEncode(drafts));
      await prefs.setString(_draftTimestampKey, jsonEncode(timestamps));
      
      debugPrint('✅ Draft deleted: $draftId');
    } catch (e) {
      debugPrint('❌ Error deleting draft: $e');
      rethrow;
    }
  }

  /// Delete all drafts
  Future<void> deleteAllDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
      await prefs.remove(_draftTimestampKey);
      debugPrint('✅ All drafts deleted');
    } catch (e) {
      debugPrint('❌ Error deleting all drafts: $e');
      rethrow;
    }
  }

  /// Check if a draft exists
  Future<bool> hasDraft(String draftId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftsJson = prefs.getString(_draftKey) ?? '{}';
      final drafts = Map<String, dynamic>.from(jsonDecode(draftsJson));
      return drafts.containsKey(draftId);
    } catch (e) {
      debugPrint('❌ Error checking draft: $e');
      return false;
    }
  }

  /// Get the count of drafts
  Future<int> getDraftCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftsJson = prefs.getString(_draftKey) ?? '{}';
      final drafts = Map<String, dynamic>.from(jsonDecode(draftsJson));
      return drafts.length;
    } catch (e) {
      debugPrint('❌ Error getting draft count: $e');
      return 0;
    }
  }
}
