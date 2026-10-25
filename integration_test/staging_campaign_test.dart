import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import '../lib/app_environment.dart';
import '../lib/cepqar_offers_page.dart';
import '../lib/staging_banner.dart';

void main(){
 final binding=IntegrationTestWidgetsFlutterBinding.ensureInitialized();
 const id=String.fromEnvironment('STAGING_CAMPAIGN_ID');
 const active=bool.fromEnvironment('STAGING_EXPECT_ACTIVE',defaultValue:true);
 for(final driver in [false,true]){
  testWidgets('real Android ${driver?'driver':'owner'} campaign ${active?'visible and detail':'removed'}',(tester)async{
   expect(AppEnvironment.isStaging,isTrue);expect(id,isNotEmpty);
   await AppEnvironment.verifyServer();
   final response=await http.get(Uri.parse('${AppEnvironment.apiBase}/api/offers/nearby?lat=41.0082&lon=28.9784'));
   expect(response.statusCode,200);
   final offers=(jsonDecode(response.body)['offers'] as List);
   expect(offers.any((o)=>o['id']==id),active);
   await tester.pumpWidget(MaterialApp(builder:environmentBanner,home:CepqarOffersPage(driverMode:driver)));
   await tester.pumpAndSettle(const Duration(milliseconds:300),EnginePhase.sendSemanticsUpdate,const Duration(seconds:60));
   expect(find.byType(CircularProgressIndicator),findsNothing);
   expect(find.byKey(const ValueKey('offers-load-error')),findsNothing);
   expect(find.textContaining('Konum izni gerekli'),findsNothing);
   expect(find.textContaining('Sunucu hatası'),findsNothing);
   final card=find.byKey(const ValueKey('offer-$id'));
   if(active){
    expect(card,findsWidgets);
    await tester.ensureVisible(card.first);await tester.tap(card.first);
    await tester.pumpAndSettle();
    expect(find.text('CepQontag Staging Test'),findsWidgets);
   }else{expect(card,findsNothing);}
   if(!driver)await binding.convertFlutterSurfaceToImage();
   await tester.pump();
   await binding.takeScreenshot('staging-${driver?'driver':'owner'}-${active?'active':'inactive'}');
  });
 }
}
