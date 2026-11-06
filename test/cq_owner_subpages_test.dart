import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heycar_app/design/cq_components.dart';
import 'package:heycar_app/onboarding_backend.dart';
import 'package:heycar_app/qr_backend.dart';
import 'package:heycar_app/maintenance_page.dart';
import 'package:heycar_app/maintenance_v2_page.dart';
import 'package:heycar_app/maintenance_detail_page.dart';
import 'package:heycar_app/maintenance_share_page.dart';
import 'package:heycar_app/upcoming_maintenance_page.dart';
import 'package:heycar_app/vehicle_reminders_page.dart';
import 'package:heycar_app/vehicle_analytics_page.dart';
import 'package:heycar_app/qr_security_page.dart';
import 'package:heycar_app/nfc_setup_page.dart';
import 'package:heycar_app/motorcycle_profile_page.dart';
import 'package:heycar_app/motorcycle_emergency_page.dart';
import 'package:heycar_app/owner_dnd_card.dart';
import 'package:heycar_app/support_ticket_page.dart';
import 'package:heycar_app/premium_page.dart';
import 'package:heycar_app/legal_pages.dart';
import 'package:heycar_app/owner_guide_page.dart';
import 'package:heycar_app/owner_settings_detail.dart';
import 'package:heycar_app/vehicle_center_page.dart';

void main(){
  final pages=<String,Widget Function()>{
    'maintenance':()=>const MaintenancePage(plate:'34 ABC 123',title:'BMW 135i'),
    'maintenance-add':()=>const MaintenanceAddPage(vehicleId:'test',ownerId:'',currentKm:15000),
    'maintenance-v2':()=>const MaintenanceV2Page(vehicleId:'test'),
    'maintenance-detail':()=>const MaintenanceDetailPage(record:{'id':'test','type':'Yağ ve filtre bakımı','description':'Uzun bakım açıklaması','km':15000,'cost':1250}),
    'maintenance-share':()=>const MaintenanceSharePage(),
    'maintenance-upcoming':()=>UpcomingMaintenancePage(upcoming:const [],records:const [],currentKm:15000,onEditIntervals:(){}),
    'reminders':()=>const VehicleRemindersPage(vehicleId:'test'),
    'analytics':()=>const VehicleAnalyticsPage(vehicleId:'test',plate:'34 ABC 123'),
    'qr-security':()=>const QrSecurityPage(vehicleId:'test',plate:'34 ABC 123'),
    'nfc':()=>const NfcSetupPage(vehicleId:'test',plate:'34 ABC 123'),
    'motorcycle-profile':()=>const MotorcycleProfilePage(vehicleId:'test',plate:'34 ABC 123'),
    'motorcycle-emergency':()=>const MotorcycleEmergencyPage(vehicleId:'test',plate:'34 ABC 123'),
    'dnd':()=>const OwnerDndPage(),
    'support':()=>const SupportTicketPage(),
    'premium':()=>const PremiumPage(),
    'legal':()=>const LegalCenterPage(),
    'terms':()=>const TermsOfUsePage(),
    'privacy':()=>const PrivacyKvkkPage(),
    'guide':()=>OwnerGuidePage(onDone:(){},onBack:(){}),
    'account':()=>const OwnerAccountSettingsPage(),
    'notification-settings':()=>const OwnerNotificationSettingsPage(),
    'privacy-settings':()=>const OwnerPrivacySettingsPage(),
    'sessions':()=>const OwnerActiveSessionsPage(),
    'blocked-visitors':()=>const OwnerBlockedVisitorsPage(),
    'vehicle-center':()=>const VehicleCenterPage(plate:'34 ABC 123',title:'BMW 135i',initialVehicle:{'id':'test','make':'BMW','model':'135i','plate':'34 ABC 123'}),
  };
  for(final width in [320.0,360.0,393.0,430.0]){
    for(final scale in [1.0,2.0,3.0]){
      for(final entry in pages.entries){
        testWidgets('${entry.key} at $width dp text $scale',(tester)async{
          SharedPreferences.setMockInitialValues({});
          OnboardingDraft.userId='';
          QrDraft.vehicleId='';
          OnboardingDraft.vehicleId='';
          final original=FlutterError.onError;
          FlutterError.onError=(details){FlutterError.dumpErrorToConsole(details,forceReport:true);original?.call(details);};
          addTearDown(()=>FlutterError.onError=original);
          tester.view.physicalSize=Size(width,852);
          tester.view.devicePixelRatio=1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MaterialApp(
            theme:CQTheme.apply(ThemeData(useMaterial3:true)),
            builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(
              textScaler:TextScaler.linear(scale),disableAnimations:true,
              padding:const EdgeInsets.only(top:44,bottom:34)),
              child:CQAppFrame(child:child!)),
            home:entry.value(),
          ));
          await tester.pump();
          await tester.pump(const Duration(milliseconds:100));
          expect(tester.takeException(),isNull);
          final scrollables=find.byWidgetPredicate((w)=>w is Scrollable&&w.axisDirection==AxisDirection.down);
          if(scrollables.evaluate().isNotEmpty){
            for(var i=0;i<4;i++){
              await tester.drag(scrollables.first,const Offset(0,-500));
              await tester.pump();
              expect(tester.takeException(),isNull);
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          expect(tester.takeException(),isNull);
        });
      }
    }
  }
}
