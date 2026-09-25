import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/board.dart';

/* ✍️ 게시판 글 쓰기 — 쓰던 글이 «한 번 톡»에 사라지지 않게. (2026-09-26 조사)
   긴 공지를 쓰다가 창 바깥을 건드리거나 뒤로 가기를 누르면 묻지도 않고 창이 닫혀 글이 통째로 사라졌다.
   → 쓴 것이 있으면 「쓰던 글을 버릴까요?」를 묻는다. 끌어 내리기는 막는다(묻지 못하고 닫힌다). */
void main() {
  tearDown(() {
    Demo.stop();
    AppState.i.setItems([]);
  });

  Future<void> openForm(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start();
    await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: const Scaffold(body: BoardTab())));
    await t.pumpAndSettle();
    await t.tap(find.text('글 쓰기'));
    await t.pumpAndSettle();
  }

  testWidgets('쓴 게 있으면 바깥을 눌러도 안 닫히고 묻는다', (t) async {
    await openForm(t);
    await t.enterText(find.byType(TextField).last, '회칙 안내 — 아주 긴 글');
    await t.pump(); // 글자를 치면 한 번 다시 그려져야 «닫아도 되는지»가 바뀐다
    await t.tapAt(const Offset(20, 20)); // 창 바깥
    await t.pumpAndSettle();
    expect(find.text('쓰던 글을 버릴까요?'), findsOneWidget);
    expect(find.text('회칙 안내 — 아주 긴 글'), findsOneWidget, reason: '글이 사라졌다');
  });

  testWidgets('아무것도 안 썼으면 그냥 닫힌다', (t) async {
    await openForm(t);
    await t.tapAt(const Offset(20, 20));
    await t.pumpAndSettle();
    expect(find.text('쓰던 글을 버릴까요?'), findsNothing);
    expect(find.text('올리기'), findsNothing, reason: '빈 창은 바로 닫혀야 한다');
  });
}
