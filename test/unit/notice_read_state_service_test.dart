import 'package:flutter_test/flutter_test.dart';
import 'package:nbro_mobile_application/core/services/notice_read_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores and returns a locally read notice', () async {
    await NoticeReadStateService.markNoticeAsReadLocally('notice-01');

    final readIds = await NoticeReadStateService.getLocalReadNoticeIds();

    expect(readIds, contains('notice-01'));
  });

  test('does not duplicate a locally read notice', () async {
    await NoticeReadStateService.markMultipleAsReadLocally([
      'notice-01',
      'notice-01',
    ]);

    final readIds = await NoticeReadStateService.getLocalReadNoticeIds();

    expect(readIds.length, 1);
  });
}
