import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../lib/business_marketplace_page.dart';

void main() {
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
      expect(request.url.host,'marketplace-test.invalid');
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
