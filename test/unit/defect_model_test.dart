import 'package:flutter_test/flutter_test.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';

void main() {
  test('converts Supabase data into a Defect', () {
    final defect = Defect.fromJson({
      'defect_id': 'D-01',
      'building_reference_no': 'H-01',
      'notation': 'C',
      'defect_category': 'buildingFloor',
      'floor_level': 'Ground Floor',
      'length_mm': 120,
      'width_mm': 5,
      'photo_path': 'defects/photo.jpg',
      'remarks': 'Wall crack',
      'created_at': '2026-01-01T00:00:00Z',
    });

    expect(defect.id, 'D-01');
    expect(defect.inspectionId, 'H-01');
    expect(defect.lengthMm, 120);
    expect(defect.widthMm, 5);
    expect(defect.remarks, 'Wall crack');
  });

  test('converts a Defect into JSON', () {
    final defect = Defect(
      id: 'D-02',
      inspectionId: 'H-02',
      notation: DefectNotation.c,
      category: DefectCategory.buildingFloor,
      lengthMm: 100,
      widthMm: 4,
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
    );

    final json = defect.toJson();

    expect(json['defect_id'], 'D-02');
    expect(json['building_reference_no'], 'H-02');
    expect(json['length_mm'], 100);
    expect(json['width_mm'], 4);
  });
}
