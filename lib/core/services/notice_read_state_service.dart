import 'package:shared_preferences/shared_preferences.dart';

/// Client-side persistent cache for notice read states to guarantee zero reversion to unread
class NoticeReadStateService {
  static const String _readNoticeIdsKey = 'nbro_read_notice_ids_v1';

  /// Get set of notice IDs marked as read locally
  static Future<Set<String>> getLocalReadNoticeIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_readNoticeIdsKey) ?? [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  /// Mark a notice ID as read locally in SharedPreferences
  static Future<void> markNoticeAsReadLocally(String noticeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_readNoticeIdsKey) ?? [];
      if (!list.contains(noticeId)) {
        list.add(noticeId);
        await prefs.setStringList(_readNoticeIdsKey, list);
      }
    } catch (_) {}
  }

  /// Mark multiple notice IDs as read locally
  static Future<void> markMultipleAsReadLocally(Iterable<String> noticeIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_readNoticeIdsKey) ?? [];
      bool modified = false;
      for (final id in noticeIds) {
        if (!list.contains(id)) {
          list.add(id);
          modified = true;
        }
      }
      if (modified) {
        await prefs.setStringList(_readNoticeIdsKey, list);
      }
    } catch (_) {}
  }
}
