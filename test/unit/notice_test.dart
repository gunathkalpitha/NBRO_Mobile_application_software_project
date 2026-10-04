import 'package:flutter_test/flutter_test.dart';
import 'package:nbro_mobile_application/domain/models/notice.dart';

void main() {
  test('converts Supabase data into an unread notice', () {
    final notice = Notice.fromJson({
      'id': 'notice-01',
      'title': 'Site Inspection Meeting',
      'message': 'Meeting at 9 AM',
      'published_at': '2026-01-01T00:00:00Z',
      'published_by': 'Admin',
      'priority': 'high',
      'is_read': false,
    });

    expect(notice.title, 'Site Inspection Meeting');
    expect(notice.message, 'Meeting at 9 AM');
    expect(notice.priority, NoticePriority.high);
    expect(notice.isRead, false);
  });

  test('copyWith marks a notice as read', () {
    final unreadNotice = Notice(
      id: 'notice-02',
      title: 'Test Notice',
      message: 'Test Message',
      publishedAt: DateTime.now(),
      publishedBy: 'Admin',
    );

    final readNotice = unreadNotice.copyWith(isRead: true);

    expect(unreadNotice.isRead, false);
    expect(readNotice.isRead, true);
  });
}
