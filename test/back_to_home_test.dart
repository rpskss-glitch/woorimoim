import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/shell.dart';

/* ◀ 안드로이드 뒤로 가기 — 다른 탭에서는 «홈으로», 홈에서만 앱을 닫는다. (2026-09-26 에뮬)
   회비·채팅 탭에서 뒤로 가기를 누르면 앱이 그 자리에서 꺼졌다. 채팅하다 무심코 누른
   어르신 회원은 앱이 사라진 줄 안다. 다른 앱들처럼 먼저 홈 탭으로 간다. */
void main() {
  Future<void> open(WidgetTester t) async {
    Demo.start();
    await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: ShellScreen(onTouch: () {})));
    await t.pumpAndSettle();
  }

  testWidgets('회비 탭에서 뒤로 가기 → 홈 탭 (앱이 안 닫힌다)', (t) async {
    await open(t);
    AppState.i.openTab.value = 4;
    await t.pumpAndSettle();
    expect(AppState.i.currentTab, 4);
    final closed = !(await t.binding.handlePopRoute());
    await t.pumpAndSettle();
    expect(closed, isFalse, reason: '뒤로 가기가 앱을 닫는다');
    expect(AppState.i.currentTab, 0, reason: '홈 탭으로 가야 한다');
  });

  testWidgets('홈 탭에서 뒤로 가기 → 앱을 닫게 둔다', (t) async {
    await open(t);
    AppState.i.openTab.value = 0;
    await t.pumpAndSettle();
    final handled = await t.binding.handlePopRoute();
    expect(handled, isFalse, reason: '홈에서는 평소처럼 닫혀야 한다');
  });
}
