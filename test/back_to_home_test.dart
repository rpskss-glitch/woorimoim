import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/common.dart';
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

  /* ◀ 2026-09-26 사장님: 「앱 종료 전에 한 번 물어보게 해줘」 — 홈에서 뒤로 가기를 누르면 바로 꺼지던 것을
     «종료할까요?»로 묻는다. 「취소」면 그대로, 「종료」면 그때 닫는다. */
  List<String> exits(WidgetTester t) {
    final calls = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (m) async {
      calls.add(m.method);
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    return calls;
  }

  testWidgets('홈 탭에서 뒤로 가기 → 바로 안 닫고 «종료할까요?»', (t) async {
    await open(t);
    final calls = exits(t);
    AppState.i.openTab.value = 0;
    await t.pumpAndSettle();
    final handled = await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(handled, isTrue, reason: '홈에서 뒤로 가기가 묻지도 않고 앱을 닫는다');
    expect(find.text('앱을 종료할까요?'), findsOneWidget);
    await t.tap(find.text('취소'));
    await t.pumpAndSettle();
    expect(calls.contains('SystemNavigator.pop'), isFalse, reason: '취소했는데 앱이 닫힌다');
    expect(find.byType(ShellScreen), findsOneWidget);
  });

  testWidgets('«종료»를 누르면 그때 앱을 닫는다', (t) async {
    await open(t);
    final calls = exits(t);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await t.tap(find.text('종료'));
    await t.pumpAndSettle();
    expect(calls, contains('SystemNavigator.pop'), reason: '종료를 눌렀는데 앱이 안 닫힌다');
  });

  testWidgets('가입 화면·승인 대기 화면도 뒤로 가기에 묻는다', (t) async {
    exits(t);
    await t.pumpWidget(MaterialApp(home: ExitGuard(child: const Scaffold(body: Text('가입 화면')))));
    final handled = await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.text('앱을 종료할까요?'), findsOneWidget);
  });

  test('앱의 첫 화면(가입·불러오기·승인 대기)이 모두 ExitGuard 로 감싸여 있다', () {
    final s = File('lib/main.dart').readAsStringSync();
    expect(s, contains('ExitGuard(child: OnboardingScreen('));
    expect(s, contains('ExitGuard(child: WaitScreen('));
    expect(s, contains('ExitGuard(child: _LoadingScreen('));
  });

  /* ◀◀ 「종료할까요?」가 떠 있을 때 뒤로 가기를 한 번 더 누르면 바로 닫는다(2026-09-26 사장님).
     «뒤로 두 번 = 종료»는 안드로이드 앱에서 흔한 손짓이다. */
  testWidgets('«종료할까요?»에서 뒤로 가기를 한 번 더 → 앱을 닫는다', (t) async {
    await open(t);
    final calls = exits(t);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('앱을 종료할까요?'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(calls, contains('SystemNavigator.pop'), reason: '뒤로 가기를 두 번 눌러도 안 닫힌다');
  });
}
