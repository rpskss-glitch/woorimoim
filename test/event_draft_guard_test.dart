import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/calendar.dart';

/* 📅 모임 만들기 창도 — 적은 것이 «한 번 톡»에 사라지지 않게. (2026-09-26, 70회차 게시판과 같은 고침) */
void main() {
  tearDown(() {
    Demo.stop();
    AppState.i.setItems([]);
  });

  testWidgets('이름을 적었으면 바깥을 눌러도 안 닫히고 묻는다', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start();
    await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: const Scaffold(body: CalendarTab())));
    await t.pumpAndSettle();
    await t.tap(find.text('모임 만들기'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, '가을 대회');
    await t.pump();
    await t.tapAt(const Offset(20, 20));
    await t.pumpAndSettle();
    expect(find.text('쓰던 글을 버릴까요?'), findsOneWidget);
    expect(find.text('가을 대회'), findsOneWidget);
  });
}
