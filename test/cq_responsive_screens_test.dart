import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:heycar_app/design/cq_components.dart';
import 'package:heycar_app/design/cq_motion.dart';
import 'package:heycar_app/onboarding_backend.dart';
import 'package:heycar_app/owner_home_redesign.dart';
import 'package:heycar_app/owner_notifications_page.dart';
import 'package:heycar_app/owner_settings_detail.dart';
import 'package:heycar_app/owner_settings_page.dart';
import 'package:heycar_app/owner_vehicles_page.dart';

void main() {
  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    for (final scale in [1.0, 1.5, 2.0, 3.0]) {
      testWidgets('owner screens at $width dp, text $scale', (tester) async {
        SharedPreferences.setMockInitialValues({});
        OnboardingDraft.userId = '';
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pages = <Widget>[
          const OwnerNotificationsPage(active: false),
          const OwnerSettingsPage(),
          const OwnerVehiclesPage(),
          OwnerServicesRedesign(active: false, onVale: () {}, onTowing: () {},
            onPark: () {}, onOffers: () {}, onMaintenance: () {}, onReminders: () {}),
          const OwnerVehicleSummaryPage(),
        ];
        for (final page in pages) {
          await tester.pumpWidget(MaterialApp(
            theme: CQTheme.apply(ThemeData(useMaterial3: true)),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale), disableAnimations: true,
                padding: const EdgeInsets.only(top: 44, bottom: 34)),
              child: child!),
            home: page,
          ));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
          // Render lower sections too; checking just the first viewport misses
          // clipped settings rows and the vehicle action/banner area.
          final scrollable = find.byType(Scrollable).first;
          await tester.drag(scrollable, const Offset(0, -500));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${page.runtimeType}, scrolled');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      });

      testWidgets('navigation keeps all actions at $width dp, text $scale', (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = -1;
        const labels = ['Anasayfa', 'Araçlarım', 'Hizmetler', 'Hızlı Erişim', 'Profil'];
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
          home: Scaffold(bottomNavigationBar: CQNavigationBar(
            labels: labels, icons: const [Icons.home, Icons.directions_car,
              Icons.grid_view, Icons.apps, Icons.person],
            selectedIndex: 0, onSelected: (i) => selected = i)),
        ));
        for (var i = 0; i < labels.length; i++) {
          final control = find.byType(CQPressable).at(i);
          final size = tester.getSize(control);
          expect(size.width, greaterThanOrEqualTo(44));
          expect(size.height, greaterThanOrEqualTo(44));
          await tester.tap(control);
          await tester.pumpAndSettle();
          expect(selected, i);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('sheet action remains reachable above keyboard with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(size: Size(320, 600), viewInsets: EdgeInsets.only(bottom: 280),
        textScaler: TextScaler.linear(3)),
      child: Scaffold(body: CQSheetBody(child: Column(children: [
        const Text('Araç bilgilerini düzenleyin. Güvenli alan ve büyük yazı desteği.'),
        const TextField(decoration: InputDecoration(labelText: 'Araç adı')),
        FilledButton(onPressed: () => taps++, child: const Text('Kaydet')),
      ]))),
    )));
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
