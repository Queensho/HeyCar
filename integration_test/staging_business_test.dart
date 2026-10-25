import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heycar_app/app_environment.dart';
import 'package:heycar_app/entry_business.dart';

void main(){
 final binding=IntegrationTestWidgetsFlutterBinding.ensureInitialized();
 const phase=String.fromEnvironment('STAGING_PHASE',defaultValue:'create');
 Finder field(String label)=>find.byWidgetPredicate((w)=>w is TextField&&w.decoration?.labelText==label);
 Future<void> waitFor(WidgetTester t,Finder finder)async{
  final deadline=DateTime.now().add(const Duration(seconds:60));
  while(finder.evaluate().isEmpty&&DateTime.now().isBefore(deadline)){
   await t.pump(const Duration(milliseconds:100));
   await t.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:150)));
  }
  expect(finder,findsWidgets);
 }
 Future<void> enter(WidgetTester t,String label,String value)async{
  final f=field(label);await waitFor(t,f);await t.ensureVisible(f);await t.enterText(f,value);await t.pump();
 }
 Future<void> tap(WidgetTester t,String label)async{
  final f=find.text(label).first;await waitFor(t,f);await t.ensureVisible(f);await t.pump(const Duration(milliseconds:250));await t.tap(f);await t.pump(const Duration(milliseconds:300));
 }
 testWidgets('real Chrome business panel $phase',(tester)async{
  await AppEnvironment.verifyServer();
  final response=await http.get(Uri.base.resolve('staging-fixture.json'));
  expect(response.statusCode,200);final fixture=jsonDecode(response.body) as Map;
  final frameworkErrors=<String>[];
  binding.reportData={'frameworkErrors':frameworkErrors};
  final originalErrorHandler=FlutterError.onError;
  FlutterError.onError=(details){
   if(frameworkErrors.length<3)frameworkErrors.add('${details.exceptionAsString()}\n${details.stack}'.split(fixture['password'] as String).join('[redacted]').split('\n').take(12).join('\n'));
   originalErrorHandler?.call(details);
  };
  addTearDown(()=>FlutterError.onError=originalErrorHandler);
  final prefs=await SharedPreferences.getInstance();
  await prefs.setString('business_token','production-session-sentinel');
  await prefs.remove(AppEnvironment.storageKey('business_token'));
  await tester.pumpWidget(const CepqarBusinessApp());
  await waitFor(tester,find.text('STAGING / TEST ORTAMI'));
  await tap(tester,'Giriş Yap');
  await enter(tester,'E-posta',fixture['email'] as String);
  await enter(tester,'Şifre',fixture['password'] as String);
  await tap(tester,'Giriş Yap');
  await waitFor(tester,find.text('Yeni Kampanya Oluştur'));
  expect(find.text('CepQontag Staging İşletmesi'),findsWidgets);
  if(phase=='create'){
   await tap(tester,'Yeni Kampanya Oluştur');
   await enter(tester,'Kampanya başlığı',fixture['title'] as String);
   await enter(tester,'Açıklama','Yalnız staging arayüz testi');
   await enter(tester,'Normal fiyat (TL)','100');
   await enter(tester,'CepQontag fiyatı (TL)','50');
   await tap(tester,'Yayınla');
   await waitFor(tester,find.text(fixture['title'] as String));
   await tap(tester,'Düzenle');
   await enter(tester,'Açıklama','Staging panelinde düzenlendi');
   await tap(tester,'Kaydet');
   await waitFor(tester,find.text('Kampanya güncellendi.'));
  }else{
   await waitFor(tester,find.text(fixture['title'] as String));
   await tap(tester,'Düzenle');
   final toggle=find.byType(SwitchListTile);
   await waitFor(tester,toggle);await tester.ensureVisible(toggle);
   final current=tester.widget<SwitchListTile>(toggle).value;
   if(current!=(phase=='publish'))await tester.tap(toggle);
   await tap(tester,'Kaydet');
   await waitFor(tester,find.text('Kampanya güncellendi.'));
  }
  // Read-only correlation after genuine UI writes. Never create/update via API
  // from this test; the application's own button callbacks perform all writes.
  final token=prefs.getString(AppEnvironment.storageKey('business_token'))??'';
  expect(token,isNotEmpty);
  final list=await http.get(Uri.parse('${AppEnvironment.apiBase}/api/business/campaigns'),headers:{'Authorization':'Bearer $token'});
  expect(list.statusCode,200);
  final campaigns=jsonDecode(list.body)['campaigns'] as List;
  final campaign=campaigns.singleWhere((c)=>c['title']==fixture['title']);
  expect(campaign['business_id'],fixture['businessId']);
  expect(campaign['is_active'],phase=='publish');
  if(phase=='create')expect(campaign['description'],'Staging panelinde düzenlendi');
  expect(prefs.getString('business_token'),'production-session-sentinel');
  binding.reportData={'campaignId':campaign['id'],'phase':phase,'realBrowserUi':true,'frameworkErrors':frameworkErrors};
  await binding.takeScreenshot('panel-$phase');
  FlutterError.onError=originalErrorHandler;
 });
}
