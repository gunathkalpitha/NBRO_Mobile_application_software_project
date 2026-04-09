import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nbro_mobile_application/domain/models/user_profile.dart';

class ProfileCompletionState {
  final int percentage;
  final bool isLoading;

  const ProfileCompletionState({
    required this.percentage,
    required this.isLoading,
  });

  bool get isComplete => percentage >= 100;

  ProfileCompletionState copyWith({
    int? percentage,
    bool? isLoading,
  }) {
    return ProfileCompletionState(
      percentage: percentage ?? this.percentage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ProfileCompletionService {
  static final ValueNotifier<ProfileCompletionState> notifier =
      ValueNotifier<ProfileCompletionState>(
    const ProfileCompletionState(percentage: 0, isLoading: false),
  );

  static Future<void> refresh() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      notifier.value = const ProfileCompletionState(percentage: 0, isLoading: false);
      return;
    }

    notifier.value = notifier.value.copyWith(isLoading: true);

    try {
      final row = await client
          .from('profile')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final percentage = UserProfile.completionPercentageFromMap(
        Map<String, dynamic>.from(row ?? const {}),
        email: user.email ?? '',
      );

      notifier.value = ProfileCompletionState(
        percentage: percentage,
        isLoading: false,
      );
    } catch (_) {
      notifier.value = notifier.value.copyWith(isLoading: false);
    }
  }
}