import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/app_ui_config.dart';
import '../lib/owner_quick_access_panel.dart';

void main(){
  const purple=Color(0xFF651FFF);
  const palePurple=Color(0xFFF1EAFF);
  const green=Color(0xFF478D19);
  const paleLime=Color(0xFFEEFFD8);

  final actions=<String>[];
  OwnerQuickPanelItem item(String id,String title,{Color? color,Color? bg})=>
    OwnerQuickPanelItem(
      id:id,title:title,icon:Icons.build_rounded,
      iconColor:color??purple,iconBackground:bg??palePurple,
      onTap:()=>actions.add(id),
      onLongPress:()=>actions.add('edit-$id'),
    );
  setUp(()=>actions.clear());

  for(final width in <double>[320,360,393,430]){
    testWidgets('one panel with four equal touch targets at $width dp',(tester)async{
      tester.view.physicalSize=Size(width,760);
      tester.view.devicePixelRatio=1;
      addTearDown((){
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final items=[
        item('parking','Park Yerim',color:green,bg:paleLime),
        item('maintenance','Bakım Geçmişi'),
        item('drivers','Sürücüler'),
        item('inspection','Muayene'),
      ];
      await tester.pumpWidget(MaterialApp(home:Scaffold(
        body:Padding(
          padding:const EdgeInsets.symmetric(horizontal:16),
          child:OwnerQuickAccessPanel(items:items),
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('owner-home-quick-panel')),findsOneWidget);
      final panelRect=tester.getRect(
        find.byKey(const ValueKey('owner-home-quick-panel')));
      expect(panelRect.height,116);
      expect(panelRect.width,closeTo(width-32,0.01));
      final tiles=<Rect>[];
      for(final id in ['parking','maintenance','drivers','inspection']){
        tiles.add(tester.getRect(find.byKey(ValueKey('owner-quick-$id'))));
      }
      expect(find.byKey(const ValueKey('owner-quick-divider-1')),findsOneWidget);
      expect(find.byKey(const ValueKey('owner-quick-divider-2')),findsOneWidget);
      expect(find.byKey(const ValueKey('owner-quick-divider-3')),findsOneWidget);
      for(final rect in tiles.skip(1)){
        expect(rect.width,closeTo(tiles.first.width,0.1));
        expect(rect.left,greaterThan(tiles.first.left));
      }
      expect(tester.takeException(),isNull);
      for(final id in ['parking','maintenance','drivers','inspection']){
        await tester.tap(find.byKey(ValueKey('owner-quick-$id')));
        await tester.pump();
      }
      expect(actions,['parking','maintenance','drivers','inspection']);
    });
  }

  testWidgets('disabled or reordered admin entries receive equal available width',(tester)async{
    const quick=<Map<String,dynamic>>[
      {'id':'inspection','title':'Özel Muayene','icon':'inspection',
        'enabled':true,'sortOrder':10,'action':'OPEN_INSPECTION'},
      {'id':'parking','title':'Kapalı öğe','icon':'parking',
        'enabled':false,'sortOrder':20,'action':'OPEN_PARKING'},
      {'id':'drivers','title':'Ekip Sürücüleri','icon':'drivers',
        'enabled':true,'sortOrder':30,'action':'OPEN_DRIVERS'},
    ];
    final config=AppUiConfig(version:2,raw:{
      ...bundledAppUiConfig,
      'quickActions':quick,
    });
    final selected=config.quickActions.map((entry)=>item(
      entry.id,entry.title)).toList();
    await tester.pumpWidget(MaterialApp(home:Scaffold(
      body:OwnerQuickAccessPanel(items:selected),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Kapalı öğe'),findsNothing);
    expect(find.byKey(const ValueKey('owner-quick-parking')),findsNothing);
    expect(find.byKey(const ValueKey('owner-quick-divider-1')),findsOneWidget);
    expect(find.byKey(const ValueKey('owner-quick-divider-2')),findsNothing);
    final first=tester.getRect(find.byKey(const ValueKey('owner-quick-inspection')));
    final second=tester.getRect(find.byKey(const ValueKey('owner-quick-drivers')));
    expect(first.width,closeTo(second.width,0.1));
    expect(first.left,lessThan(second.left));
    await tester.tap(find.byKey(const ValueKey('owner-quick-inspection')));
    await tester.longPress(find.byKey(const ValueKey('owner-quick-drivers')));
    expect(actions,['inspection','edit-drivers']);
    expect(tester.takeException(),isNull);
  });
}
