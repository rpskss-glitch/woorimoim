import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/shell.dart';

/* 👉 「옆으로 밀어 화면 넘기기」 (2026-09-03 사장님 지시, 안드·아이폰 공통).

   ⚠️ 틀(IndexedStack)은 그대로 둔다 — 이 앱은 «탭 다섯이 동시에 살아 있는» 구조에
      여러 곳이 기대고 있어서, PageView 로 갈아타면 각 탭의 자리를 잃는다.
      그래서 «탭이 다 살아 있는지»도 함께 지킨다. */
void main() {
  final st = AppState.i;

  int tabOf(WidgetTester t) =>
      t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start();
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: ShellScreen(onTouch: () {}),
    ));
    await t.pumpAndSettle();
  }

  tearDown(() {
    st.setCouple({});
    st.setItems([]);
  });

  /// 화면 가운데를 «홱» 민다 (느린 끌기는 일부러 안 먹는다)
  Future<void> fling(WidgetTester t, {required bool left}) async {
    await t.fling(find.byType(IndexedStack), Offset(left ? -300 : 300, 0), 1200);
    await t.pumpAndSettle();
  }

  testWidgets('왼쪽으로 밀면 다음 탭, 오른쪽으로 밀면 이전 탭', (t) async {
    await open(t);
    expect(tabOf(t), 0, reason: '홈에서 시작해야 한다');

    await fling(t, left: true);
    expect(tabOf(t), 1, reason: '왼쪽으로 밀었는데 채팅으로 안 넘어간다');

    await fling(t, left: true);
    expect(tabOf(t), 2, reason: '일정으로 안 넘어간다');

    await fling(t, left: false);
    expect(tabOf(t), 1, reason: '오른쪽으로 밀었는데 뒤로 안 간다');
  });

  testWidgets('맨 끝에서 더 밀어도 조용히 머문다', (t) async {
    await open(t);
    // 홈(0)에서 오른쪽으로 밀어도 -1 로 안 간다
    await fling(t, left: false);
    expect(tabOf(t), 0);

    // 맨 끝(회비=4)까지 간 뒤 더 밀어도 그대로
    for (var i = 0; i < 4; i++) {
      await fling(t, left: true);
    }
    expect(tabOf(t), 4, reason: '맨 끝(회비)까지 가야 한다');
    await fling(t, left: true);
    expect(tabOf(t), 4, reason: '맨 끝에서 더 밀었는데 넘어갔다');
  });

  testWidgets('살짝 스친 것으로는 안 넘어간다 (읽다가 화면이 튀면 안 된다)', (t) async {
    await open(t);
    // 아주 느리게 조금만 끈다
    await t.drag(find.byType(IndexedStack), const Offset(-40, 0));
    await t.pumpAndSettle();
    expect(tabOf(t), 0, reason: '살짝 스쳤는데 탭이 넘어갔다');
  });

  testWidgets('틀은 IndexedStack 그대로 — 탭 다섯이 «동시에 살아 있다»', (t) async {
    await open(t);
    final stack = t.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack.children.length, 5,
        reason: 'PageView 로 갈아타면 화면 밖 탭의 자리를 잃는다');
  });
}
