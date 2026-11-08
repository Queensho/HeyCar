import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/cepqar_offers_page.dart';
import 'package:heycar_app/offers/marketplace_api.dart';
import 'package:heycar_app/offers/offer_detail_page.dart';

class FakeMarketplace extends MarketplaceApi {
  FakeMarketplace() : super();
  final favoriteIds = <String>{};
  final calls = <String>[];
  bool fail = false;
  Map<String, dynamic>? redemption;
  List<Map<String, dynamic>> get offers => [
        {
          'id': 'campaign-one',
          'business_id': 'business-one',
          'name': 'Test Yıkama',
          'title': 'İç dış temizlik',
          'category': 'Oto Yıkama',
          'description': 'Test koşulları',
          'terms': 'Yalnızca seçilen araç için',
          'badge': '%20',
          'rating': '4.5',
          'review_count': 2,
          'starts_at': '2020-01-01T00:00:00Z',
          'ends_at': '2099-01-01T00:00:00Z',
          'address': 'Kadıköy',
          'distance_m': 1200
        },
        {
          'id': 'campaign-two',
          'business_id': 'business-two',
          'name': 'Test Lastik',
          'title': 'Balans hizmeti',
          'category': 'Lastik',
          'starts_at': '2020-01-01T00:00:00Z',
          'ends_at': '2099-01-01T00:00:00Z'
        },
      ];
  @override
  Future<Map<String, dynamic>> request(String path,
      {String method = 'GET',
      Map<String, dynamic>? body,
      bool authenticated = false}) async {
    calls.add('$method $path');
    final uri = Uri.parse(path);
    if (uri.path == '/api/offers/discover') {
      if (fail) throw const MarketplaceException('SERVER_ERROR');
      final q = uri.queryParameters['q'] ?? '',
          cat = uri.queryParameters['category'] ?? '';
      return {
        'offers': offers
            .where((e) =>
                (q.isEmpty ||
                    '${e['name']} ${e['title']}'
                        .toLowerCase()
                        .contains(q.toLowerCase())) &&
                (cat.isEmpty || e['category'] == cat))
            .toList()
      };
    }
    if (path == '/api/offers/categories')
      return {
        'categories': [
          {'name': 'Oto Yıkama'},
          {'name': 'Lastik'}
        ]
      };
    if (path == '/api/offers/editorial') return {'offers': []};
    if (path == '/api/offers/page-design') return {'design': {}};
    if (path == '/api/offers/favorites')
      return {'favorites': <String>[], 'businesses': favoriteIds.toList()};
    if (path == '/api/offers/saved')
      return {
        'offers':
            offers.where((o) => favoriteIds.contains(o['business_id'])).toList()
      };
    if (path.endsWith('/favorite')) {
      final id = uri.pathSegments[3];
      method == 'DELETE' ? favoriteIds.remove(id) : favoriteIds.add(id);
      return {'ok': true};
    }
    if (path.startsWith('/api/offers/businesses/'))
      return {
        'business': {
          'id': 'business-one',
          'name': 'Test Yıkama',
          'address': 'Kadıköy',
          'approval_status': 'approved',
          'vehicle_types': ['car'],
          'opening_hours': '09:00–18:00'
        },
        'services': [
          {'name': 'İç dış temizlik', 'price': '500.00'}
        ],
        'campaigns': [offers.first],
        'reviews': []
      };
    if (path == '/api/owner/vehicles')
      return {
        'vehicles': [
          {'id': 'v-one', 'plate': '34ABC123'},
          {'id': 'v-two', 'plate': '06XYZ456'}
        ]
      };
    if (path.endsWith('/redemption')) return {'redemption': redemption};
    if (path.endsWith('/redeem')) {
      redemption = {
        'id': 'redemption-one',
        'campaign_id': 'campaign-one',
        'usage_code': '0123456789ABCDEF0123456789ABCDEF',
        'plate': body!['plate'],
        'status': 'pending'
      };
      return {'redemption': redemption};
    }
    if (path == '/api/offers/history')
      return {
        'redemptions': redemption == null
            ? []
            : [
                {
                  ...redemption!,
                  'name': 'Test Yıkama',
                  'title': 'İç dış temizlik',
                  'display_status': redemption!['status']
                }
              ]
      };
    return {'ok': true};
  }
}

Future<void> mount(WidgetTester tester, FakeMarketplace api,
    {double width = 393, double scale = 1}) async {
  tester.view.physicalSize = Size(width, 852);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          useMaterial3: true,
          colorScheme:
              ColorScheme.fromSeed(seedColor: const Color(0xFF651FFF))),
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: Scaffold(
          extendBody: true,
          body: CepqarOffersPage(api: api),
          bottomNavigationBar: const SizedBox(
              height: 80,
              child: ColoredBox(
                  color: Colors.black,
                  child: Center(
                      child: Text('Alt menü',
                          style: TextStyle(color: Colors.white))))))));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {});
  test('campaign dates reject expired and future validity', () {
    expect(
        campaignAvailable({'starts_at': '2020-01-01', 'ends_at': '2021-01-01'},
            DateTime(2026)),
        false);
    expect(
        campaignAvailable({'starts_at': '2090-01-01', 'ends_at': '2091-01-01'},
            DateTime(2026)),
        false);
    expect(
        campaignAvailable({'starts_at': '2020-01-01', 'ends_at': '2091-01-01'},
            DateTime(2026)),
        true);
  });
  for (final width in [393.0, 430.0])
    for (final scale in [1.0, 2.0])
      testWidgets('discovery scroll and bottom clearance $width dp text $scale',
          (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await mount(tester, FakeMarketplace(), width: width, scale: scale);
        expect(tester.takeException(), isNull);
        final footer = find.text(
            'Fiyatlar ve kampanya koşulları işletmeler tarafından sağlanır.');
        await tester.scrollUntilVisible(footer, 400,
            scrollable: find
                .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable))
                .first);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(footer, findsOneWidget);
        expect(tester.getBottomLeft(footer).dy, lessThan(772));
        expect(tester.takeException(), isNull);
      });
  testWidgets('search and category filter results', (tester) async {
    final api = FakeMarketplace();
    await mount(tester, api);
    await tester.enterText(find.byType(TextField), 'Lastik');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Test Lastik'), findsOneWidget);
    expect(find.text('Test Yıkama'), findsNothing);
    await tester.tap(find.byTooltip('Aramayı temizle'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Lastik'));
    await tester.pumpAndSettle();
    expect(find.text('Test Yıkama'), findsNothing);
  });
  testWidgets('favorites persist when discovery is reopened', (tester) async {
    final api = FakeMarketplace();
    await mount(tester, api);
    await tester.ensureVisible(find.byTooltip('Favorilere ekle').first);
    await tester.tap(find.byTooltip('Favorilere ekle').first);
    await tester.pumpAndSettle();
    expect(api.favoriteIds, contains('business-one'));
    await tester.pumpWidget(const SizedBox());
    await mount(tester, api);
    await tester.ensureVisible(find.byTooltip('Favorilerden çıkar').first);
    expect(find.byTooltip('Favorilerden çıkar'), findsOneWidget);
    await tester.tap(find.byTooltip('Favorilerden çıkar'));
    await tester.pumpAndSettle();
    expect(api.favoriteIds, isEmpty);
  });
  testWidgets(
      'detail navigation, real service and explicit vehicle selection create local QR',
      (tester) async {
    final api = FakeMarketplace();
    await mount(tester, api);
    await tester.ensureVisible(find.text('Test Yıkama'));
    await tester.tap(find.text('Test Yıkama'));
    await tester.pumpAndSettle();
    expect(find.byType(OfferDetailPage), findsOneWidget);
    expect(find.text('CepQontag tarafından onaylı işletme'), findsOneWidget);
    await tester.tap(find.text('Fırsatı kullan'));
    await tester.pumpAndSettle();
    expect(find.text('Aracınızı seçin'), findsOneWidget);
    await tester.tap(find.text('06XYZ456'));
    await tester.pumpAndSettle();
    expect(api.redemption?['plate'], '06XYZ456');
    expect(find.text('İşletmeye gösterin'), findsOneWidget);
    expect(find.text('0123456789ABCDEF0123456789ABCDEF'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('error retry and manual city search without location permission',
      (tester) async {
    final api = FakeMarketplace()..fail = true;
    await mount(tester, api);
    await tester.ensureVisible(find.text('Yeniden dene'));
    api.fail = false;
    await tester.tap(find.text('Yeniden dene'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konum veya şehir seçin'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Şehir veya ilçe'), 'Kadıköy');
    await tester.tap(find.widgetWithText(FilledButton, 'Ara'));
    await tester.pumpAndSettle();
    expect(api.calls.lastWhere((e) => e.contains('discover')),
        contains('city=Kad%C4%B1k%C3%B6y'));
    expect(tester.takeException(), isNull);
  });
}
