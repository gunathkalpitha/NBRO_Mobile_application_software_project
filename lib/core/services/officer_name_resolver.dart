import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nbro_mobile_application/core/services/profile_state_service.dart';

/// Service to resolve officer UUIDs into human-readable full names across the application
class OfficerNameResolver {
  static final Map<String, String> _cache = {};

  /// Resolve raw string or UUID into full officer name
  static String resolve(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Government Officer';
    final trimmed = raw.trim();

    // 1. If cached, return full name
    if (_cache.containsKey(trimmed)) return _cache[trimmed]!;

    // 2. Check if raw matches UUID pattern
    final isUuid = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(trimmed);

    if (isUuid) {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final profile = ProfileStateService.notifier.value;

      // Match current logged in user
      if (currentUser != null && currentUser.id == trimmed) {
        final name = (profile?.fullName.isNotEmpty == true ? profile?.fullName : null) ??
            currentUser.userMetadata?['full_name'] ??
            currentUser.userMetadata?['name'] ??
            currentUser.email?.split('@').first ??
            'Government Officer';
        _cache[trimmed] = name;
        return name;
      }

      if (profile != null && profile.id == trimmed && profile.fullName.isNotEmpty) {
        _cache[trimmed] = profile.fullName;
        return profile.fullName;
      }

      // Asynchronously fetch profile from Supabase and cache it
      _fetchProfileName(trimmed);
      return 'Government Officer';
    }

    // Already a human-readable name
    return trimmed;
  }

  static Future<void> _fetchProfileName(String userId) async {
    try {
      final res = await Supabase.instance.client
          .from('profile')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      if (res != null && res['full_name'] != null) {
        final name = res['full_name'] as String;
        if (name.trim().isNotEmpty) {
          _cache[userId] = name.trim();
        }
      }
    } catch (e) {
      debugPrint('[OfficerNameResolver] Failed to fetch name for $userId: $e');
    }
  }

  /// Bulk preload profile names into cache
  static Future<void> preloadProfiles() async {
    try {
      final res = await Supabase.instance.client.from('profile').select('id, full_name');
      for (final item in (res as List)) {
        final id = item['id'] as String?;
        final name = item['full_name'] as String?;
        if (id != null && name != null && name.trim().isNotEmpty) {
          _cache[id] = name.trim();
        }
      }
    } catch (_) {}
  }
}
