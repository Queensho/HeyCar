import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/owner_reference_design.dart';

void main(){
  for(final size in <Size>[
    const Size(320,568),
    const Size(360,640),
    const Size(393,852),
    const Size(430,932),
  ]){
    testWidgets('five interactive waves tabs remain visible on ${size.width}x${size.height}',
      (tester) async{
        tester.view.physicalSize=size;
        tester.view.devicePixelRatio=1;
        addTearDown((){
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        var selected=0;
        await tester.pumpWidget(MaterialApp(
          home:Scaffold(
            body:const Center(child:Text('Real app content')),
            bottomNavigationBar:OwnerReferenceBottomNav(
              selected:selected,unread:true,
              onChanged:(value)=>selected=value,
            ),
          ),
        ));
        for(final label in OwnerReferenceBottomNav.labels){
          expect(find.text(label),findsOneWidget);
        }
        expect(find.byKey(const ValueKey('owner-reference-tab-0')),findsOneWidget);
        for(var tab=0;tab<5;tab++){
          final tile=find.byKey(ValueKey('owner-reference-tab-$tab'));
          final box=tester.getRect(tile);
          expect(box.left,greaterThanOrEqualTo(0));
          expect(box.right,lessThanOrEqualTo(size.width+.01));
          expect(box.top,greaterThanOrEqualTo(0));
          expect(box.bottom,lessThanOrEqualTo(size.height+.01));
          await tester.tap(tile);
          expect(selected,tab);
        }
        expect(tester.takeException(),isNull);
      },
    );
  }


  testWidgets('active navigation light stays circular and bottom bar compact',
    (tester)async{
      tester.view.physicalSize=const Size(393,852);
      tester.view.devicePixelRatio=1;
      addTearDown((){
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(MaterialApp(home:Scaffold(
        body:const SizedBox.expand(),
        bottomNavigationBar:OwnerReferenceBottomNav(
          selected:0,unread:false,onChanged:(_){},
        ),
      )));
      final nav=tester.getRect(find.byType(OwnerReferenceBottomNav));
      final glow=tester.getRect(find.byKey(const ValueKey('owner-reference-active-glow')));
      expect(nav.height,lessThanOrEqualTo(82));
      expect(glow.width,58);
      expect(glow.height,58);
      expect(glow.center.dx,closeTo(43.3,2));
      expect(find.byType(ClipPath),findsWidgets);
      expect(tester.takeException(),isNull);
    },
  );

  testWidgets('shared header routes notifications and settings independently',
    (tester)async{
      var notifications=0,settings=0;
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:SafeArea(
        child:OwnerReferenceHeader(
          unread:true,
          onNotifications:()=>notifications++,
          onSettings:()=>settings++,
        ),
      ))));
      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await tester.tap(find.byIcon(Icons.settings_outlined));
      expect(notifications,1);
      expect(settings,1);
      expect(tester.takeException(),isNull);
    },
  );
}
