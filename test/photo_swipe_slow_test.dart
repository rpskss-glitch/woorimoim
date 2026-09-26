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
    await t.pump(const Duration(milliseconds: 400)); // 두 번 치기를 기다린 뒤 알린다
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.close).evaluate().length, closeBefore,
        reason: '사진을 누르니 한 장짜리 창이 또 떴다');
    expect(counter(t), '1 / 3');
  });

  testWidgets('첫 움직임이 크게 들어와도(빠른 손짓) 사진 위에서 넘어간다', (t) async {
    await openGallery(t);
    final g = await t.startGesture(t.getCenter(find.byType(PageView)));
    for (var i = 0; i < 5; i++) {
      await g.moveBy(const Offset(-60, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await t.pumpAndSettle();
    expect(counter(t), '2 / 3', reason: '빠르게 밀면 사진이 손짓을 가로채 안 넘어간다');
  });

  /* 🔍 전체화면에서 «확대가 안 된다» (2026-09-26 사장님 안드로이드).
     확대 영역이 «사진 크기만큼»이라 가로 사진처럼 납작한 사진은 두 손가락을 벌리다
     한 손가락만 까만 곳에 닿아도 확대가 안 먹었다 → 확대 영역을 «화면 전체»로.
     그리고 두 번 톡 치면 확대(한 번 더 치면 원래대로) — 사람들이 먼저 해 보는 손짓이다. */
  testWidgets('확대 영역이 사진 크기가 아니라 화면 전체다', (t) async {
    await openGallery(t);
    final iv = t.getSize(find.byType(InteractiveViewer).first);
    final pv = t.getSize(find.byType(PageView));
    expect(iv.height, greaterThan(pv.height * 0.9),
        reason: '확대 영역이 사진 높이뿐이라 손가락이 까만 곳에 닿으면 확대가 안 된다');
  });

  testWidgets('두 번 톡 치면 확대, 한 번 더 두 번 치면 원래대로', (t) async {
    await openGallery(t);
    double scale() => t
        .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
        .transformationController!
        .value
        .getMaxScaleOnAxis();
    final c = t.getCenter(find.byType(PageView));
    await t.tapAt(c);
    await t.pump(const Duration(milliseconds: 60));
    await t.tapAt(c);
    await t.pumpAndSettle();
    expect(scale(), greaterThan(1.5), reason: '두 번 톡 쳐도 확대가 안 된다');
    expect(find.byType(PageView), findsOneWidget, reason: '두 번 쳤는데 창이 닫혔다');
    await t.tapAt(c);
    await t.pump(const Duration(milliseconds: 60));
    await t.tapAt(c);
    await t.pumpAndSettle();
    expect(scale(), lessThan(1.05), reason: '한 번 더 두 번 쳐도 원래대로 안 돌아온다');
  });
}
