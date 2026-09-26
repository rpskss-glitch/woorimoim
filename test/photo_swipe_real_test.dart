import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/ui/common.dart';

/* 📚 사진을 크게 본 채로 «정말 손가락으로 밀어서» 다음 사진이 나오는가.

   2026-09-25 사장님: 「사진을 누르면 커지는데 커진 상태로 옆으로 밀어도 다음 사진이 안 나온다」.
   1.6.0 에 넘기기를 넣었지만 그때 시험은 «코드에 PageView 가 있나»만 봤고
   **실제로 밀어 보지는 않았다.** 사진 한 장 한 장에 확대(InteractiveViewer)와
   «사진 누르면 안 닫힘»(GestureDetector)이 겹쳐 있어, 그것들이 손짓을 먼저 가져가면
   넘기는 판(PageView)까지 손짓이 안 온다. 그래서 여기서는 **진짜로 민다.** */
/* ⚠️ 진짜 그림(40×30 빨간 PNG)을 쓴다. 가짜 주소를 넣으면 「깨진 사진」 표시가
      화면을 꽉 채워 «사진 바깥»이 아예 없어진다 — 그러면 바깥 누르기를 잴 수 없다.
      (실제 사진은 비율대로 가운데에 놓여 위아래에 까만 데가 남는다) */
const _png = 'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAACgAAAAeCAIAAADRv8uKAAAAK0lEQVR4nO3NMQ0AAAgDsHmafweIQgYcTfo3056IWCwWi8VisVgsFov/xguuIJqsWNdF6AAAAABJRU5ErkJggg==';

void main() {
  Future<void> openGallery(WidgetTester t, {int count = 3, int start = 0}) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showPhotoPages(
                c,
                [for (var i = 0; i < count; i++) const PhotoShot(src: _png)],
                start,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    /* ⚠️ 그림 풀기(해독)는 시험 시계 밖에서 돈다 — 안 기다리면 그림 크기가 0 이라
          «사진을 눌렀다»가 실제로는 까만 바깥을 누른 것이 된다(한 번 속았다). */
    await t.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await t.pumpAndSettle();
    expect(t.getSize(find.byType(Image).first).width, greaterThan(0),
        reason: '그림이 아직 안 그려졌다 — 아래 누르기 시험이 뜻이 없다');
  }

  String counter(WidgetTester t) {
    final f = find.textContaining(' / ');
    return f.evaluate().isEmpty ? '' : (t.widget<Text>(f.first).data ?? '');
  }

  // 사람이 사진 위에서 옆으로 쓱 미는 것 — 화면 가운데(=사진 위)에서 민다
  Future<void> swipe(WidgetTester t, {required bool left}) async {
    final c = t.getCenter(find.byType(PageView));
    await t.flingFrom(c, Offset(left ? -300 : 300, 0), 800);
    await t.pumpAndSettle();
  }

  testWidgets('사진 위에서 왼쪽으로 밀면 다음 사진', (t) async {
    await openGallery(t);
    expect(counter(t), '1 / 3');
    await swipe(t, left: true);
    expect(counter(t), '2 / 3', reason: '밀었는데 다음 사진으로 안 넘어갔다');
    await swipe(t, left: true);
    expect(counter(t), '3 / 3');
  });

  testWidgets('오른쪽으로 밀면 이전 사진', (t) async {
    await openGallery(t, start: 2);
    expect(counter(t), '3 / 3', reason: '누른 사진부터 열려야 한다');
    await swipe(t, left: false);
    expect(counter(t), '2 / 3', reason: '밀었는데 이전 사진으로 안 넘어갔다');
  });

  testWidgets('사진 «바깥» 까만 데서 밀어도 넘어간다', (t) async {
    await openGallery(t);
    // 왼쪽 아래 구석 — 사진이 아닌 곳
    await t.flingFrom(const Offset(300, 700), const Offset(-280, 0), 800);
    await t.pumpAndSettle();
    expect(counter(t), '2 / 3');
  });

  testWidgets('민다고 닫히지는 않는다', (t) async {
    await openGallery(t);
    await swipe(t, left: true);
    expect(find.byType(PageView), findsOneWidget, reason: '넘기다가 창이 닫혔다');
  });

  testWidgets('사진 «자체»를 누르면 안 닫힌다 — 확대하려다 잘못 닫히지 않게', (t) async {
    await openGallery(t);
    await t.tap(find.byType(Image).first);
    // 두 번 치기(확대)를 기다리느라 한 번 누르기는 0.3초 뒤에 알린다
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(find.byType(PageView), findsOneWidget, reason: '사진을 눌렀는데 창이 닫혔다');
  });

  testWidgets('바깥을 톡 누르면 닫힌다 (넘기기를 넣어도 그대로)', (t) async {
    await openGallery(t);
    await t.tapAt(const Offset(20, 760));
    // 두 번 치기(확대)를 기다리느라 한 번 누르기는 0.3초 뒤에 알린다
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(find.byType(PageView), findsNothing);
  });
}
