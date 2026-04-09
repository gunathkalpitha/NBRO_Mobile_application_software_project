import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nbro_mobile_application/domain/models/user_profile.dart';

class ProfileRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<UserProfile> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found');
    }

    final row = await _client
        .from('profile')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) {
      final fallback = {
        'id': user.id,
        'full_name': user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'User',
        'role': user.userMetadata?['role'] ?? 'officer',
        'is_active': true,
      };

      await _client.from('profile').upsert(fallback);
      return UserProfile.fromMap(fallback);
    }

    return UserProfile.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _client
        .from('profile')
        .update(profile.toUpdateMap())
        .eq('id', profile.id);
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
  }) async {
    final filePath = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await _client.storage
        .from('profile-images')
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );

    return _client.storage.from('profile-images').getPublicUrl(filePath);
  }
}