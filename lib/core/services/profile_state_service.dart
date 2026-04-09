import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nbro_mobile_application/data/repositories/profile_repository.dart';
import 'package:nbro_mobile_application/domain/models/user_profile.dart';

class ProfileStateService {
  static final ValueNotifier<UserProfile?> notifier = ValueNotifier<UserProfile?>(null);
  static final ProfileRepository _repository = ProfileRepository();

  static Future<void> refresh() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      notifier.value = null;
      return;
    }

    try {
      notifier.value = await _repository.getCurrentProfile();
    } catch (_) {
      notifier.value = null;
    }
  }
}