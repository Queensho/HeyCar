import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:heycar_app/design/cq_components.dart';
import 'package:heycar_app/design/cq_motion.dart';
import 'package:heycar_app/onboarding_backend.dart';
import 'package:heycar_app/owner_home_redesign.dart';
import 'package:heycar_app/owner_notifications_page.dart';
import 'package:heycar_app/owner_new_vehicle_page.dart';
import 'package:heycar_app/roadside_help_page.dart';
import 'package:heycar_app/owner_qr_dialog.dart';
import 'package:heycar_app/qr_backend.dart';
import 'package:heycar_app/cepqontag_store_page.dart';
import 'package:heycar_app/valet_info_page.dart';
import 'package:heycar_app/cepqar_offers_page.dart';
import 'package:heycar_app/owner_settings_detail.dart';
import 'package:heycar_app/owner_settings_page.dart';
import 'package:heycar_app/owner_vehicles_page.dart';
import 'package:heycar_app/parking_location_card.dart';

void main() {
  for (final width in [320.0, 393.0]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('park options remain horizontal at $width dp and $scale text scale', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(body: SingleChildScrollView(
            child: ParkingLocationCard(vehicleId: 'test-vehicle'),
          )),
        ));
        await tester.pump();
        expect(find.text('Yakındaki Otoparklar'), findsOneWidget);
        expect(find.text('Sokakta Park Ettim'), findsOneWidget);
        expect(find.text('Park Yerim'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (scale == 1.0) {
          final icon = tester.getCenter(find.byIcon(Icons.map_outlined));
          final title = tester.getCenter(find.text('Yakındaki Otoparklar'));
          expect((icon.dy - title.dy).abs(), lessThan(35),
            reason: 'Park icon and title should share a horizontal card row');
        }
      });
    }
  }
  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    for (final scale in [1.0, 1.5, 2.0, 3.0]) {
      testWidgets('owner screens at $width dp, text $scale', (tester) async {
        final previousErrorHandler=FlutterError.onError;
        FlutterError.onError=(details){
          FlutterError.dumpErrorToConsole(details,forceReport:true);
          previousErrorHandler?.call(details);
        };
        addTearDown(()=>FlutterError.onError=previousErrorHandler);
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
          const OwnerNewVehiclePage(),
          const RoadsideHelpPage(),
          const CepqontagStorePage(),
          const ValetInfoPage(vehicleId:''),
          const CepqarOffersPage(),
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
          final scrollable = find.byWidgetPredicate((widget)=>widget is Scrollable&&widget.axisDirection==AxisDirection.down).first;
          await tester.drag(scrollable, const Offset(0, -500));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '${page.runtimeType}, scrolled');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      });

      testWidgets('populated vehicle card and QR dialog at $width dp, text $scale', (tester) async {
        tester.view.physicalSize=Size(width,700);
        tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var qrTaps=0;
        QrDraft.token='TEST-QR-TOKEN';
        QrDraft.scanSecret='TEST-SCAN-SECRET';
        await tester.pumpWidget(MaterialApp(
          theme:CQTheme.apply(ThemeData(useMaterial3:true)),
          builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(
            textScaler:TextScaler.linear(scale),disableAnimations:true),child:child!),
          home:Scaffold(body:Builder(builder:(context)=>SingleChildScrollView(
            padding:const EdgeInsets.all(16),child:Column(children:[
              OwnerVehicleCard(v:const {'plate':'34 ABC 123','make':'BMW',
                'model':'Çok uzun araç modeli ve donanım paketi','year':2025,'active':true},
                selected:false,open:(){},select:(){},qr:()=>qrTaps++,transfer:(){},remove:(){}),
              TextButton(onPressed:()=>showOwnerQrDialog(context),child:const Text('QR aç')),
            ])))),
        ));
        await tester.pump();
        expect(tester.takeException(),isNull);
        await tester.ensureVisible(find.text('QR Etiket'));
        await tester.tap(find.text('QR Etiket'));
        expect(qrTaps,1);
        await tester.ensureVisible(find.text('QR aç'));
        await tester.tap(find.text('QR aç'));
        await tester.pumpAndSettle();
        expect(find.text('QR Kodum'),findsOneWidget);
        expect(tester.takeException(),isNull);
        await tester.tap(find.byTooltip('Kapat'));
        await tester.pumpAndSettle();
        expect(find.text('QR Kodum'),findsNothing);
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
