import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/owner_story_highlights.dart';
import 'package:heycar_app/story_service.dart';

class _MemoryStoryService extends StoryService {
  final events = <String>[];
  @override
  Future<void> mark(String storyId, String event) async => events.add('$storyId/$event');
}

void main() {
  testWidgets('reduced-motion stories stay readable and support manual navigation', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _MemoryStoryService();
    final items = [
      StoryItem.fromJson({'id': 'one', 'title': 'Güvenli yolculuk',
        'subtitle': 'Aracınız için bakım, sigorta ve güvenlik bilgilerini inceleyin. '
          'Büyük yazıda tüm içerik kaydırılarak okunabilmelidir.',
        'ctaEnabled': true, 'ctaText': 'Araçlarım',
        'actionType': 'IN_APP_PAGE', 'actionTarget': 'vehicles'}),
      StoryItem.fromJson({'id': 'two', 'title': 'İkinci hikâye'}),
    ];
    String? shortcut;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true,
          textScaler: const TextScaler.linear(3)), child: child!),
      home: StoryViewerPage(items: items, service: service,
        shortcut: (value) => shortcut = value),
    ));
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Güvenli yolculuk'), findsWidgets);
    expect(find.text('İkinci hikâye'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Sonraki'));
    await tester.pump();
    expect(find.text('İkinci hikâye'), findsWidgets);
    await tester.tap(find.byTooltip('Önceki'));
    await tester.pump();
    await tester.ensureVisible(find.text('ARAÇLARIM'));
    await tester.tap(find.text('ARAÇLARIM'));
    await tester.pump();
    expect(shortcut, 'vehicles');
    expect(service.events, contains('one/click'));
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('İkinci hikâye'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
