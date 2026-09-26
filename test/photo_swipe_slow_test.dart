import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/demo_photos.dart';
import 'package:woorimoim/ui/common.dart';

/* 📚 사진을 «천천히·살짝 비스듬히» 한 번 밀면 그 뒤로 넘기기가 통째로 멈췄다 (2026-09-26 사장님 안드로이드 폰).

   에뮬레이터에서 재현: 사진을 열고 곧게·빠르게 밀면 넘어가는데, 사람 손처럼 천천히 비스듬히
   한 번 밀고 나면 **그 뒤로는 곧게 밀어도 안 넘어갔다.** 실제 손가락은 거의 늘 조금 비스듬하다. */
const _png = 'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAACgAAAAeCAIAAADRv8uKAAAAK0lEQVR4nO3NMQ0AAAgDsHmafweIQgYcTfo3056IWCwWi8VisVgsFov/xguuIJqsWNdF6AAAAABJRU5ErkJggg==';

void main() {
  Future<void> openGallery(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showPhotoPages(
                  c, [for (var i = 0; i < 3; i++) const PhotoShot(src: _png)], 0),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    await t.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await t.pumpAndSettle();
  }

  String counter(WidgetTester t) {
    final f = find.textContaining(' / ');
    return f.evaluate().isEmpty ? '' : (t.widget<Text>(f.first).data ?? '');
  }

  testWidgets('천천히 비스듬히 밀어도 넘어간다', (t) async {
    await openGallery(t);
    final c = t.getCenter(find.byType(PageView));
    await t.timedDragFrom(c, const Offset(-150, 27), const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    expect(counter(t), '2 / 3', reason: '천천히 비스듬히 밀면 안 넘어간다');
  });

  testWidgets('한 번 천천히 민 뒤에도 곧게 밀면 넘어간다 — 넘기기가 잠기지 않는다', (t) async {
    await openGallery(t);
    final c = t.getCenter(find.byType(PageView));
    await t.timedDragFrom(c, const Offset(-150, 27), const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    final before = counter(t);
    await t.flingFrom(c, const Offset(-300, 0), 800);
    await t.pumpAndSettle();
    expect(counter(t), isNot(before), reason: '한 번 천천히 밀고 나면 넘기기가 잠긴다');
  });

  /* 💬 대화방 사진 보기도 같은 사진 조각(ZoomPhoto)을 쓴다 — 저장소 번호(photoId)로 여는 길에서
     크게 본 사진을 누르면 한 장짜리 창이 또 떴다(2026-09-26). */
  testWidgets('대화방 사진 보기 — 크게 본 사진을 눌러도 한 장짜리 창이 또 뜨지 않는다', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start(); // 체험 사진은 번호(photoId)로 열리고 서버 없이 뜬다
    addTearDown(Demo.stop);
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showPhotoPages(
                  c, [for (var i = 0; i < 3; i++) PhotoShot(photoId: demoPhotoCourt)], 0),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    await t.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await t.pumpAndSettle();
    final closeBefore = find.byIcon(Icons.close).evaluate().length;
    await t.tap(find.byType(Image).first);
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.close).evaluate().length, closeBefore,
        reason: '사진을 누르니 한 장짜리 창이 또 떴다');
    expect(counter(t), '1 / 3');
  });
}
