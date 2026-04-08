import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FirstLoginGuideService {
  static const String _prefix = 'first_login_guide_seen_';

  static String? _currentKey() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return null;
    }
    return '$_prefix${user.id}';
  }

  static Future<bool> shouldShowForCurrentUser() async {
    final key = _currentKey();
    if (key == null) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(key) ?? false);
  }

  static Future<void> markSeenForCurrentUser() async {
    final key = _currentKey();
    if (key == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }
}
