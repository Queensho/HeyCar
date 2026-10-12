import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/app_ui_config.dart';
import '../lib/owner_home_services_promo.dart';

void main(){
  final defaults=AppUiConfig.defaults();
  final original=defaults.services;
  final navigations=<String>[];
  setUp(()=>navigations.clear());

  Widget app(List<AppUiServiceItem> services,{double margin=16})=>
    MaterialApp(home:Scaffold(body:ListView(children:[
      Padding(
        padding:EdgeInsets.symmetric(horizontal:margin),
        child:OwnerHomeServicesPromo(
          services:services,tokens:AppUiTokens.defaults,
          onOpenServices:()=>navigations.add('services'),
        ),
      ),
    ])));

  for(final width in <double>[320,360,390,430]){
    testWidgets('single compact panel at '+width.toInt().toString()+'dp',(tester)async{
      tester.view.physicalSize=Size(width,800);
      tester.view.devicePixelRatio=1;
      addTearDown((){
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(app(original));
      await tester.pumpAndSettle();

      final card=find.byKey(const ValueKey('owner-home-services-promo'));
      expect(card,findsOneWidget);
      final rect=tester.getRect(card);
      expect(rect.height,124);
      expect(rect.width,closeTo(width-32,.1));
      expect(find.text('CepQontag Hizmetleri'),findsOneWidget);
      expect(find.text('Çekici, vale, yol yardımı ve daha fazlası yakında hizmetinizde.'),
        findsOneWidget);
      expect(find.byKey(const ValueKey('owner-home-service-tags')),findsOneWidget);
      expect(find.byType(ListView),findsNWidgets(2));
      expect(tester.takeException(),isNull);
      await tester.tap(card);
      expect(navigations,['services']);
    });
  }

  testWidgets('admin title/order/visibility stay authoritative',(tester)async{
    final raws=<Map<String,dynamic>>[
      {'id':'valet','title':'Özel Vale','subtitle':'Vale desteği',
        'enabled':true,'sortOrder':5,'action':'OPEN_VALE','testOnly':false,
        'badgeText':'','iconToken':'primary'},
      {'id':'towing','title':'Gizlenmiş Çekici',
        'enabled':false,'sortOrder':10,'action':'OPEN_TOWING'},
      {'id':'offers','title':'Yeni Fırsatlar',
        'enabled':true,'sortOrder':15,'action':'OPEN_OPPORTUNITIES',
        'testOnly':true,'badgeText':'Yakında','iconToken':'success'},
    ];
    final config=AppUiConfig(version:3,
      raw:{...bundledAppUiConfig,'services':raws});
    expect(config.services.map((s)=>s.id),['valet','offers']);
    await tester.pumpWidget(app(config.services));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('owner-service-tag-valet')),findsOneWidget);
    expect(find.byKey(const ValueKey('owner-service-tag-towing')),findsNothing);
    expect(find.text('Gizlenmiş Çekici'),findsNothing);
    expect(OwnerHomeServicesPromo.descriptionFor(config.services),
      'Özel Vale hizmetinizde, diğerleri yakında.');
    final first=tester.getRect(find.byKey(const ValueKey('owner-service-tag-valet')));
    final second=tester.getRect(find.byKey(const ValueKey('owner-service-tag-offers')));
    expect(first.left,lessThan(second.left));
    expect(tester.takeException(),isNull);
  });

  testWidgets('no service means no empty card or fake action',(tester)async{
    await tester.pumpWidget(app([]));
    expect(find.byKey(const ValueKey('owner-home-services-promo')),findsNothing);
    expect(tester.takeException(),isNull);
  });

  test('all live, all upcoming and mixed descriptions derive from admin state',(){
    expect(OwnerHomeServicesPromo.descriptionFor(original),
      'Çekici, vale, yol yardımı ve daha fazlası yakında hizmetinizde.');
    final active=[AppUiServiceItem({
      'id':'towing','title':'Çekici','action':'OPEN_TOWING',
      'enabled':true,'badgeText':'','testOnly':false,
    })];
    expect(OwnerHomeServicesPromo.descriptionFor(active),
      'Çekici, vale, yol yardımı ve daha fazlası hizmetinizde.');
    expect(OwnerHomeServicesPromo.descriptionFor([...active,original[1]]),
      'Çekici hizmetinizde, diğerleri yakında.');
  });
}
