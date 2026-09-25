import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/home.dart';
import 'package:woorimoim/ui/shell.dart';

/* 📸 홈 「사진첩」에서 사진을 «올릴» 수 있어야 한다. (2026-09-26 에뮬)
   홈 바로가기는 사진첩만 따로 띄워 「사진 올리기」 단추가 없었다 — 사진을 올리러 누른 회원이 길을 못 찾았다.
   → 게시판 탭의 「사진」 칸(올리기 단추가 있는 자리)으로 보낸다. */
void main() {
  tearDown(() {
    Demo.stop();
    AppState.i.setItems([]);
  });

  testWidgets('홈 「사진첩」 → 게시판 탭 사진 칸, 「사진 올리기」 단추가 보인다', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start();
    await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: ShellScreen(onTouch: () {})));
    await t.pumpAndSettle();
    final f = find.descendant(of: find.byType(HomeTab), matching: find.text('사진첩'));
    await t.scrollUntilVisible(f, 200,
        scrollable: find.descendant(of: find.byType(HomeTab), matching: find.byType(Scrollable)).first);
    await t.pumpAndSettle();
    await t.tap(f.first);
    await t.pumpAndSettle();
    expect(AppState.i.currentTab, 3, reason: '게시판 탭으로 가야 한다');
    expect(find.text('사진 올리기'), findsOneWidget, reason: '올리기 단추가 없다');
  });
}
