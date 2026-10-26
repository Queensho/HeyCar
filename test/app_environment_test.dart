import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/app_environment.dart';
import '../lib/owner_auth.dart';
import '../lib/driver_auth.dart';
import '../lib/staging_banner.dart';

void main(){
 testWidgets('staging announcement stays accessible across Navigator routes',(tester)async{
  final semantics=tester.ensureSemantics();
  addTearDown(semantics.dispose);
  final navigator=GlobalKey<NavigatorState>();
  Set<String> labels(){
   final result=<String>{};
   void visit(SemanticsNode node){
    result.add(node.label);
    node.visitChildren((child){visit(child);return true;});
   }
   visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
   return result;
  }
  await tester.pumpWidget(MaterialApp(navigatorKey:navigator,builder:environmentBanner,home:const Scaffold(body:Text('Guest'))));
  await tester.pumpAndSettle();
  expect(labels().any((label)=>label.contains('STAGING / TEST ORTAMI')),isTrue);
  navigator.currentState!.push(MaterialPageRoute<void>(builder:(_)=>const Scaffold(body:TextField(obscureText:true))));
  await tester.pumpAndSettle();
  expect(labels().any((label)=>label.contains('STAGING / TEST ORTAMI')),isTrue);
 });
 test('production default remains unchanged',(){expect(AppEnvironment.productionApi,'https://heycar-api-185-165-46-213.nip.io');});
 test('staging refuses production, missing TLS and unknown environments',(){
  for(final api in [AppEnvironment.productionApi,'http://staging.example.com','https://cepqar.com','https://a.example/path']){
   expect(()=>AppEnvironment.validate(environment:'staging',api:api),throwsStateError);
  }
  expect(()=>AppEnvironment.validate(environment:'other',api:'https://a.example'),throwsStateError);
  AppEnvironment.validate(environment:'staging',api:'https://staging.example.com');
 });
 test('SSH transport is an explicit loopback-only test opt-in',(){
  AppEnvironment.validate(environment:'staging',api:'http://10.0.2.2:18091',tunnel:true);
  expect(()=>AppEnvironment.validate(environment:'staging',api:'http://10.0.2.2:18091',tunnel:false),throwsStateError);
  expect(()=>AppEnvironment.validate(environment:'staging',api:'http://example.com:18091',tunnel:true),throwsStateError);
 });
 test('staging owner and driver credentials do not reuse production storage',()async{
  SharedPreferences.setMockInitialValues({'owner_access_token':'production-owner','driver_access_token':'production-driver'});
  await OwnerAuth.restore();await DriverAuth.restore();
  expect(OwnerAuth.accessToken,isEmpty);expect(DriverAuth.accessToken,isEmpty);
  await OwnerAuth.saveFrom({'accessToken':'staging-owner','refreshToken':'staging-refresh'});
  final p=await SharedPreferences.getInstance();
  expect(p.getString('owner_access_token'),'production-owner');
  expect(p.getString('staging:owner_access_token'),'staging-owner');
 });
}
