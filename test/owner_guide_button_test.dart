import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/home.dart';
import 'package:woorimoim/ui/members.dart';
import 'package:woorimoim/ui/owner_guide.dart';

/* 👑 방장 안내서 2단계(가입 승인)의 단추가 «실제로 어딘가로» 가는가.

   2026-09-25 조사: 단추가 「홈에서 확인」 → 홈 탭으로 옮기기였는데,
   이 안내서는 **홈에 있다** — 이미 홈인데 홈으로 가라니 눌러도 아무 일이 없었다.
   이제 승인을 실제로 하는 회원 화면을 연다(홈 카드의 「승인하러 가기 ›」와 같은 곳). */
void main() {
  tearDown(() {
    Demo.stop();
    AppState.i.setItems([]);
  });

  testWidgets('「승인하러 가기」를 누르면 회원 화면이 열린다', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start();
    OwnerGuideCard.reset();
    OwnerGuideCard.unfold();
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: const Scaffold(body: HomeTab()),
    ));
    await t.pumpAndSettle();

    final btn = find.descendant(
        of: find.byType(OwnerGuideCard), matching: find.text('승인하러 가기'));
    expect(btn, findsOneWidget, reason: '안내서에 승인 단추가 없다');
    await t.ensureVisible(btn);
    await t.pumpAndSettle();
    await t.tap(btn);
    await t.pumpAndSettle();
    expect(find.byType(MembersScreen), findsOneWidget,
        reason: '눌렀는데 아무 일도 없다 — 이미 홈인데 홈으로 가라는 단추였다');
  });

  testWidgets('「홈 맨 위」라는 틀린 설명이 없다 (승인 카드는 빠른 단추 아래에 있다)', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start();
    OwnerGuideCard.reset();
    OwnerGuideCard.unfold();
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: const Scaffold(body: HomeTab()),
    ));
    await t.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(OwnerGuideCard), matching: find.textContaining('홈 맨 위')),
        findsNothing);
  });
}
