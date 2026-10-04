import 'package:flutter_test/flutter_test.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';

void main() {
  test('converts Supabase data into an Inspection', () {
    final inspection = Inspection.fromJson({
      'building_ref': 'H-01',
      'owner_name': 'Test Owner',
      'address': 'Test Address',
      'created_at': '2026-01-01T00:00:00Z',
      'sync_status': 'pending',
    });

    expect(inspection.id, 'H-01');
    expect(inspection.ownerName, 'Test Owner');
    expect(inspection.siteAddress, 'Test Address');
    expect(inspection.syncStatus, SyncStatus.pending);
  });

  test('converts an Inspection into JSON', () {
    final inspection = Inspection(
      id: 'H-02',
      ownerName: 'Another Owner',
      siteAddress: 'Another Address',
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
    );

    final json = inspection.toJson();

    expect(json['building_ref'], 'H-02');
    expect(json['owner_name'], 'Another Owner');
    expect(json['address'], 'Another Address');
  });
}
