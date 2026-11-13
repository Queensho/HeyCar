import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/owner_service_notification.dart';
import 'package:heycar_app/car_wash_pages.dart';
import 'car_wash_test.dart' show FixtureWashApi;
void main(){for(final category in ['car_wash','interior','polish','ceramic','ppf','inspection']){
 testWidgets('$category shared notification opens exact existing appointment detail',(t)async{
 final api=FixtureWashApi();const id='12345678-1234-1234-1234-123456789abc';
 await t.pumpWidget(MaterialApp(home:Builder(builder:(c)=>Scaffold(body:FilledButton(onPressed:()=>openOwnerServiceNotification(c,{'type':'service_booking','service_category':category,'booking_id':id},api:api),child:const Text('Bildirim'))))));
 await t.tap(find.text('Bildirim'));await t.pumpAndSettle();expect(find.byType(WashBookingDetailPage),findsOneWidget);expect(api.calls.any((c)=>c['path']=='/api/car-wash/bookings/$id'),isTrue);expect(t.takeException(),isNull);await t.pumpWidget(const SizedBox.shrink());
 });
}}
