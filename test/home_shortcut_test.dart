import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/calendar.dart';
import 'package:woorimoim/ui/board.dart';
import 'package:woorimoim/ui/home.dart';
import 'package:woorimoim/ui/shell.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 🏠 홈의 「일정 · 글 쓰기 · 회비 장부」를 누르면 «화면이 실제로» 넘어가는가.

   2026-09-25 사장님: 「홈에서 일정·글쓰기·회비장부 눌러도 아무 반응이 없다」.
   원인: 홈은 «몇 번 탭으로 가라»는 신호(openTab)만 보내는데, 받는 쪽이
         번호(_tab)만 바꾸고 **넘기는 판(PageView)은 그대로 두었다.**
         아래 단추의 불만 옮겨 가고 화면은 홈에 머물렀다.
         옆으로 밀기(PageView)를 넣은 9/3 부터 쭉 그랬다.
   ⚠️ 같은 신호를 «알림 눌러 대화방 열기»와 «스크린샷 자동 촬영»도 쓴다 — 셋 다 막혀 있었다.

   ⚠️ 그래서 «아래 단추 번호»로만 보면 안 된다 — 그건 예전에도 바뀌었다.
      **그 탭 화면이 손에 닿는 자리에 있는지**(hitTestable)로 본다. */
void main() {
  final st = AppState.i;

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
    st.openTab.value = null;
    st.setCouple({});
    st.setItems([]);
  });

  bool showing<T>(WidgetTester t) => find.byType(T).hitTestable().evaluate().isNotEmpty;

  /// 홈은 길다 — 빠른 단추가 화면 아래에 있으면 아직 안 그려져 있다. 내려가며 찾는다.
  Future<Finder> homeButton(WidgetTester t, String label) async {
    final f = find.descendant(of: find.byType(HomeTab), matching: find.text(label));
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find
          .descendant(of: find.byType(HomeTab), matching: find.byType(Scrollable))
          .first,
    );
    await t.pumpAndSettle();
    return f.first;
  }

  testWidgets('탭 옮기기 신호를 받으면 «화면이» 넘어간다', (t) async {
    await open(t);
    expect(showing<HomeTab>(t), isTrue);

    for (final (n, name) in [(4, '회비'), (2, '일정'), (3, '게시판'), (0, '홈')]) {
      st.openTab.value = n;
      await t.pumpAndSettle();
      final ok = switch (n) {
        4 => showing<WalletTab>(t),
        2 => showing<CalendarTab>(t),
        3 => showing<BoardTab>(t),
        _ => showing<HomeTab>(t),
      };
      expect(ok, isTrue, reason: '$name 으로 가라 했는데 화면이 안 넘어갔다');
    }
  });

  testWidgets('홈의 「회비 장부」를 누르면 회비 화면이 나온다', (t) async {
    await open(t);
    await t.tap(await homeButton(t, '회비 장부'));
    await t.pumpAndSettle();
    expect(showing<WalletTab>(t), isTrue, reason: '눌렀는데 아무 반응이 없다');
    expect(showing<HomeTab>(t), isFalse);
  });

  testWidgets('홈의 「일정」을 누르면 일정 화면이 나온다', (t) async {
    await open(t);
    await t.tap(await homeButton(t, '일정'));
    await t.pumpAndSettle();
    expect(showing<CalendarTab>(t), isTrue, reason: '일정을 눌렀는데 화면이 안 넘어갔다');
  });

  testWidgets('홈의 「글 쓰기」를 누르면 게시판이 나온다', (t) async {
    await open(t);
    await t.tap(await homeButton(t, '글 쓰기'));
    await t.pumpAndSettle();
    expect(showing<BoardTab>(t), isTrue, reason: '글 쓰기를 눌렀는데 화면이 안 넘어갔다');
  });

  testWidgets('신호로 옮긴 뒤에도 옆으로 밀기가 제자리에서 이어진다', (t) async {
    await open(t);
    st.openTab.value = 4;
    await t.pumpAndSettle();
    // 회비(4)에서 오른쪽으로 밀면 게시판(3) — 페이지가 안 따라왔으면 홈에서 밀려 엉뚱해진다
    await t.fling(find.byType(PageView), const Offset(300, 0), 500);
    await t.pumpAndSettle();
    expect(showing<BoardTab>(t), isTrue, reason: '신호로 옮긴 자리와 넘기는 판의 자리가 어긋났다');
  });
}
