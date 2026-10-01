import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nbro_mobile_application/presentation/screens/inspection/site_inspection_wizard.dart';

void main() {
  testWidgets('inspection wizard displays form controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SiteInspectionWizard()));

    await tester.pump();

    expect(find.byType(TextField), findsWidgets);
    expect(find.text('Next Step'), findsOneWidget);
  });

  testWidgets('inspection wizard displays image controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SiteInspectionWizard()));

    await tester.pump();

    expect(find.byIcon(Icons.add_a_photo_outlined), findsWidgets);
  });
}
