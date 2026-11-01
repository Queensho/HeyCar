import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../lib/business_marketplace_page.dart';
import '../lib/api_base_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('staging business session storage cannot overwrite production sessions', () async {
    SharedPreferences.setMockInitialValues({'business_token':'production-fixture-token'});
    final prefs=await SharedPreferences.getInstance();
    final scoped=apiScopedPreferenceKey('business_token');
    if(cepqontagApiBaseUrl=='https://heycar-api-185-165-46-213.nip.io'){
      expect(scoped,'business_token');
      expect(prefs.getString(scoped),'production-fixture-token');
      return;
    }
    expect(scoped,isNot('business_token'));
    expect(prefs.getString(scoped),isNull);
    await prefs.setString(scoped,'staging-fixture-token');
    expect(prefs.getString('business_token'),'production-fixture-token');
    expect(prefs.getString(scoped),'staging-fixture-token');
    await prefs.remove(scoped);
    expect(prefs.getString('business_token'),'production-fixture-token');
  });
  testWidgets('hours edits preserve the business timezone and use the selected API', (tester) async {
    Map<String,dynamic>? submitted;
    final hours={for(var i=1;i<=7;i++)'$i':{'open':'09:00','close':'18:00'}};
    final service={'id':'00000000-0000-4000-8000-000000000001','title':'Test hizmet',
      'category':'Servis','price_cents':10000,'duration_minutes':60,'active':true,
      'booking_timezone':'Europe/Berlin','weekly_hours':hours};
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home:BusinessMarketplacePage(token:'test-business-token')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çalışma Saatleri'));
      await tester.pumpAndSettle();
      expect(find.text('Saat dilimi: Europe/Berlin'),findsOneWidget);
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(submitted?['timezone'],'Europe/Berlin');
      expect(submitted?['weeklyHours'],hours);
      expect(tester.takeException(),isNull);
    },()=>MockClient((request) async {
      expect(request.url.host,Uri.parse(cepqontagApiBaseUrl).host);
      expect(request.headers['Authorization'],'Bearer test-business-token');
      if(request.method=='PATCH'){
        submitted=Map<String,dynamic>.from(jsonDecode(request.body) as Map);
        return http.Response('{"ok":true}',200);
      }
      return http.Response(jsonEncode(request.url.path.endsWith('/services')?
        {'ok':true,'services':[service]}:{'ok':true,'appointments':[]}),200);
    }));
  });
}
