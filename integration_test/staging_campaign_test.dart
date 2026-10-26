import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:heycar_app/app_environment.dart';
import 'package:heycar_app/cepqar_offers_page.dart';
import 'package:heycar_app/staging_banner.dart';
import 'package:heycar_app/entry_theme_live.dart';
import 'package:heycar_app/owner_welcome_overlay.dart';
import 'package:heycar_app/owner_password_login.dart';
import 'package:heycar_app/call_permission_setup.dart';

void main(){
 final binding=IntegrationTestWidgetsFlutterBinding.ensureInitialized();
 const id=String.fromEnvironment('STAGING_CAMPAIGN_ID');
 const active=bool.fromEnvironment('STAGING_EXPECT_ACTIVE',defaultValue:true);
 testWidgets('native staging guest reaches login without disabled calling setup',(tester)async{
  expect(AppEnvironment.isStaging,isTrue);
  await AppEnvironment.verifyServer();
  await tester.pumpWidget(const ThemeOwnerApp());
  final deadline=DateTime.now().add(const Duration(seconds:60));
  while(find.byType(OwnerWelcomeOverlay).evaluate().isEmpty&&DateTime.now().isBefore(deadline)){
   await tester.pump(const Duration(milliseconds:100));
   await tester.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:150)));
  }
  expect(find.byType(OwnerWelcomeOverlay),findsOneWidget);
  expect(find.byType(CallPermissionSetupPage),findsNothing);
  final login=find.byKey(const ValueKey('owner-welcome-login'));
  await tester.ensureVisible(login);await tester.tap(login);
  await tester.pumpAndSettle();
  expect(find.byType(PasswordOwnerLoginScreen),findsOneWidget);
  expect(find.text('STAGING / TEST ORTAMI'),findsOneWidget);
  await binding.convertFlutterSurfaceToImage();await tester.pump();
  await binding.takeScreenshot('staging-guest-login-${active?'active':'inactive'}');
 });
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
   // The nearby section is lazily built below the editorial sections. Search
   // through the real field, then scroll the vertical page into that section.
   final search=find.byType(TextField);
   if(search.evaluate().isNotEmpty){
    await tester.enterText(search.first,'CepQontag Staging Test');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
   }
   final vertical=find.descendant(of:find.byType(CustomScrollView),matching:find.byType(Scrollable)).first;
   await tester.scrollUntilVisible(find.text('Yakınımdaki Fırsatlar'),300,scrollable:vertical,maxScrolls:20);
   await tester.pumpAndSettle(const Duration(milliseconds:300),EnginePhase.sendSemanticsUpdate,const Duration(seconds:30));
   await binding.convertFlutterSurfaceToImage();
   await tester.pump();
   await binding.takeScreenshot('staging-${driver?'driver':'owner'}-${active?'active':'inactive'}-list');
   expect(find.byType(CircularProgressIndicator),findsNothing);
   expect(find.byKey(const ValueKey('offers-load-error')),findsNothing);
   expect(find.textContaining('Konum izni gerekli'),findsNothing);
   expect(find.textContaining('Sunucu hatası'),findsNothing);
   final card=find.byKey(const ValueKey('offer-$id'));
   if(active){
    await tester.scrollUntilVisible(card,180,scrollable:vertical,maxScrolls:12);
    expect(card,findsWidgets);
    await tester.ensureVisible(card.first);await tester.tap(card.first);
    await tester.pumpAndSettle();
    expect(find.text('CepQontag Staging Test'),findsWidgets);
   }else{expect(card,findsNothing);}
   await tester.pump();
   await binding.takeScreenshot('staging-${driver?'driver':'owner'}-${active?'active':'inactive'}');
  });
 }
}
