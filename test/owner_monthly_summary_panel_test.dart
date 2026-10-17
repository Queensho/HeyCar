import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/owner_monthly_summary_panel.dart';

void main(){
  const purple=Color(0xFF651FFF);
  final actions=<String>[];
  setUp(()=>actions.clear());

  List<OwnerMonthlyMetric> metrics({
    int messages=24,int parks=21,int calls=0,int? offers=0,
    String messageLabel='Mesaj Talebi',
    double? messagesChange,
  })=>[
    OwnerMonthlyMetric(
      id:'messages',label:messageLabel,icon:Icons.chat_bubble_rounded,
      tint:purple,background:const Color(0xFFF3EDFF),
      count:messages,changePercent:messagesChange,
      onTap:()=>actions.add('messages')),
    OwnerMonthlyMetric(
      id:'park',label:'Park Uyarısı',icon:Icons.warning_rounded,
      tint:const Color(0xFFE84D66),background:const Color(0xFFFFF0F2),
      count:parks,onTap:()=>actions.add('park')),
    OwnerMonthlyMetric(
      id:'calls',label:'Gelen Arama',icon:Icons.phone_rounded,
      tint:const Color(0xFF59667C),background:const Color(0xFFF3F5F9),
      count:calls,onTap:()=>actions.add('calls')),
    OwnerMonthlyMetric(
      id:'offers',label:'Fırsat Kullanımı',icon:Icons.local_offer_rounded,
      tint:const Color(0xFF478D19),background:const Color(0xFFF1FBDD),
      count:offers),
  ];

  Widget app(List<OwnerMonthlyMetric> data,{
    bool loading=false,bool error=false,VoidCallback? retry,
  })=>MaterialApp(home:Scaffold(body:ListView(children:[
    Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:
      OwnerMonthlySummaryPanel(
        metrics:data,isLoading:loading,hasError:error,
        onViewAll:()=>actions.add('all'),onRetry:retry,
      )),
  ])));

  for(final width in <double>[320,360,390,430]){
    testWidgets('responsive compact owner summary at $width dp',(tester)async{
      tester.view.physicalSize=Size(width,760);
      tester.view.devicePixelRatio=1;
      addTearDown((){
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(app(metrics(
        messageLabel:'Mesaj Talebi Çok Uzun Başlık Sınaması',
        messages:1234567,parks:21,calls:0,offers:0,
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('owner-monthly-summary-panel')),findsOneWidget);
      expect(find.byKey(const ValueKey('owner-monthly-messages')),findsOneWidget);
      final panel=tester.getRect(find.byKey(
        const ValueKey('owner-monthly-summary-panel')));
      expect(panel.width,closeTo(width-32,.1));
      for(final id in ['messages','park','calls','offers']){
        expect(find.byKey(ValueKey('owner-monthly-$id')),findsOneWidget);
      }
      final first=tester.getRect(find.byKey(const ValueKey('owner-monthly-messages')));
      final second=tester.getRect(find.byKey(const ValueKey('owner-monthly-park')));
      final third=tester.getRect(find.byKey(const ValueKey('owner-monthly-calls')));
      final fourth=tester.getRect(find.byKey(const ValueKey('owner-monthly-offers')));
      expect(first.width,closeTo(second.width,.1));
      // All metric tiles keep a compact fixed height on every screen.
      for(final rect in [first,second,third,fourth]){
        expect(rect.height,closeTo(96,.01));
      }
      final messageLabel=find.descendant(
        of:find.byKey(const ValueKey('owner-monthly-messages')),
        matching:find.text('Mesaj Talebi Çok Uzun Başlık Sınaması'),
      );
      expect(messageLabel,findsOneWidget);
      final labelBottom=tester.getRect(messageLabel).bottom;
      // Content is vertically balanced, not pinned at the top of a tall card.
      expect(first.bottom-labelBottom,lessThan(31));
      expect(first.top,closeTo(third.top,1));
      expect(third.top,closeTo(fourth.top,1));
      expect(third.width,closeTo(fourth.width,.1));
      expect(find.text('0'),findsNWidgets(2));
      // The caller never provided previous-month data: hide all deltas.
      expect(find.textContaining('%'),findsNothing);
      expect(tester.takeException(),isNull);
      await tester.tap(find.byKey(const ValueKey('owner-monthly-messages')));
      await tester.tap(find.byKey(const ValueKey('owner-monthly-park')));
      await tester.tap(find.byKey(const ValueKey('owner-monthly-calls')));
      await tester.tap(find.byKey(const ValueKey('owner-monthly-view-all')));
      expect(actions,['messages','park','calls','all']);
    });
  }

  testWidgets('no fake counts or clicks for unavailable offer history',(tester)async{
    await tester.pumpWidget(app(metrics(offers:null)));
    await tester.pumpAndSettle();
    expect(find.text('—'),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('owner-monthly-offers')));
    await tester.pump();
    expect(actions,isEmpty);
    expect(tester.takeException(),isNull);
  });

  testWidgets('optional verified deltas display only when supplied',(tester)async{
    await tester.pumpWidget(app(metrics(messagesChange:12)));
    await tester.pumpAndSettle();
    expect(find.text('↑ %12'),findsOneWidget);
    expect(tester.getSize(find.byKey(
      const ValueKey('owner-monthly-messages'))).height,96);
    expect(tester.takeException(),isNull);
  });

  testWidgets('loading, API error and retry never render misleading zeros',(tester)async{
    await tester.pumpWidget(app(metrics(),loading:true));
    expect(find.byType(CircularProgressIndicator),findsOneWidget);
    expect(find.byKey(const ValueKey('owner-monthly-calls')),findsNothing);
    await tester.pumpWidget(app(metrics(),error:true,retry:()=>actions.add('retry')));
    await tester.pumpAndSettle();
    expect(find.text('İstatistikler yüklenemedi.'),findsOneWidget);
    expect(find.byKey(const ValueKey('owner-monthly-calls')),findsNothing);
    await tester.tap(find.text('Tekrar dene'));
    expect(actions,['retry']);
    expect(tester.takeException(),isNull);
  });
}
