import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/album.dart';

/* 📚 사진첩 크게 보기(PhotoPage) — 넘기기 (2026-09-26 사장님: 「안드로이드에서 좌우로 안 넘어간다」).

   에뮬레이터에서 찾은 까닭: 크게 본 사진을 **한 번 톡 누르면** 그 위에 «한 장짜리» 보기 창이
   하나 더 떴다(사진 한 장의 기본 누르기 = 크게 보기). 그 창에는 사진이 한 장뿐이라
   **아무리 밀어도 안 넘어간다.** 크게 본 사진을 톡 누르는 것은 사람이 늘 하는 일이다. */
void main() {
  tearDown(Demo.stop);

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start();
    final rows = sortPhotosByDay(AppState.i.by('photo'));
    await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: PhotoPage(rows: rows, start: 0)));
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

  testWidgets('곧게 빠르게 밀면 넘어간다', (t) async {
    await open(t);
    expect(counter(t), '1 / 3');
    await t.flingFrom(t.getCenter(find.byType(PageView)), const Offset(-300, 0), 800);
    await t.pumpAndSettle();
    expect(counter(t), '2 / 3');
  });

  testWidgets('천천히 비스듬히 밀어도 넘어간다', (t) async {
    await open(t);
    final c = t.getCenter(find.byType(PageView));
    await t.timedDragFrom(c, const Offset(-150, 27), const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    expect(counter(t), '2 / 3', reason: '천천히 비스듬히 밀면 안 넘어간다');
  });

  testWidgets('한 번 천천히 민 뒤에도 넘기기가 잠기지 않는다', (t) async {
    await open(t);
    final c = t.getCenter(find.byType(PageView));
    await t.timedDragFrom(c, const Offset(-150, 27), const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    final before = counter(t);
    await t.flingFrom(c, const Offset(-300, 0), 800);
    await t.pumpAndSettle();
    expect(counter(t), isNot(before), reason: '한 번 천천히 밀고 나면 넘기기가 잠긴다');
  });

  /* 🖼 사장님이 원한 것(2026-09-26): 사진을 누르면 «전체화면»으로 커지고, 그 전체화면에서도 좌우로 넘어간다.
     ⚠️ 예전에는 전체화면이 «그 한 장만» 담아 넘어가지 않았다. 한때(1.6.2 초안) 누르기를 아예 없애
        전체화면 자체가 사라졌다 — 사장님이 쓰던 기능을 없앤 것이다. 전체화면은 두고 «사진 전부»를 담는다. */
  Finder full() => find.byType(Dialog);
  String fullCounter(WidgetTester t) {
    final f = find.descendant(of: full(), matching: find.textContaining(' / '));
    return f.evaluate().isEmpty ? '' : (t.widget<Text>(f.first).data ?? '');
  }

  testWidgets('사진을 누르면 전체화면 — 거기서도 좌우로 넘어가고, 닫으면 본 사진 자리로', (t) async {
    await open(t);
    await t.tap(find.byType(Image).first);
    // 두 번 치기(확대)를 기다리느라 한 번 누르기는 0.3초 뒤에 알린다
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(full(), findsOneWidget, reason: '사진을 눌러도 전체화면이 안 뜬다');
    expect(fullCounter(t), '1 / 3', reason: '전체화면이 한 장짜리다 — 넘길 수 없다');
    final pv = find.descendant(of: full(), matching: find.byType(PageView));
    await t.flingFrom(t.getCenter(pv), const Offset(-300, 0), 800);
    await t.pumpAndSettle();
    expect(fullCounter(t), '2 / 3', reason: '전체화면에서 좌우로 안 넘어간다');
    await t.tap(find.byIcon(Icons.close));
    await t.pumpAndSettle();
    expect(full(), findsNothing);
    expect(counter(t), '2 / 3', reason: '닫으면 전체화면에서 보던 사진 자리로 돌아와야 한다');
  });

  /* ✋ 빠르게 휙 밀면 손가락이 «한 번에 크게» 움직인 것으로 들어온다(터치 표본이 드문 폰·빠른 손짓).
     그러면 사진의 확대 손짓이 그 움직임을 넘기기보다 «먼저» 보고 가로채 넘어가지 않았다
     (2026-09-26 에뮬레이터: 사진 위에서 휙 밀면 안 넘어가고, 까만 바깥에서 밀면 넘어감). */
  testWidgets('첫 움직임이 크게 들어와도(빠른 손짓) 사진 위에서 넘어간다', (t) async {
    await open(t);
    final c = t.getCenter(find.byType(PageView));
    final g = await t.startGesture(c);
    await g.moveBy(const Offset(-60, 0));
    await t.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 4; i++) {
      await g.moveBy(const Offset(-60, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await t.pumpAndSettle();
    expect(counter(t), '2 / 3', reason: '빠르게 밀면 사진이 손짓을 가로채 안 넘어간다');
  });
}
