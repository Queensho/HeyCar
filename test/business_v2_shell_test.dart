import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/business_v2_shell.dart';
import 'package:heycar_app/business_car_wash_page.dart';
import 'car_wash_test.dart' show FixtureWashApi;
void main() {
 testWidgets('actual business route allows desktop sidebar', (t) async {
 t.view.physicalSize=const Size(1280,1000);t.view.devicePixelRatio=1;addTearDown(t.view.resetPhysicalSize);addTearDown(t.view.resetDevicePixelRatio);
 await t.pumpWidget(MaterialApp(home:BusinessCarWashPage(api:FixtureWashApi(),onEditProfile:()async{},uploadPhoto:()async=>null)));await t.pumpAndSettle();
 expect(find.byKey(const ValueKey('business-section-services')),findsOneWidget);await t.pumpWidget(const SizedBox.shrink());
 });
  for (final width in [320.0, 360.0, 393.0, 430.0, 1280.0]) {
    for (final scale in [1.0, 1.3, 1.6]) {
      testWidgets('business navigation $width / $scale', (t) async {
        t.view.physicalSize = Size(width, 1000); t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(MaterialApp(home: MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(scale)), child: Scaffold(body: BusinessV2Shell(builder: (s) => Center(child: Text('Bölüm: ${s.name}')))))));
        for (final section in BusinessSection.values) {
          if (width < 1000) {
            await t.tap(find.byType(DropdownButtonFormField<BusinessSection>)); await t.pumpAndSettle();
            await t.ensureVisible(find.text(section.label).last); await t.tap(find.text(section.label).last); await t.pumpAndSettle();
          } else {
            await t.tap(find.byKey(ValueKey('business-section-${section.name}'))); await t.pumpAndSettle();
          }
          expect(find.text('Bölüm: ${section.name}'), findsOneWidget); expect(t.takeException(), isNull);
        }
      });
    }
  }
}
