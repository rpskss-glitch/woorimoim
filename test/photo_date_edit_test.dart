import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/album.dart';

/* 📅 사진의 «찍은 날짜»를 바꿀 수 있다.

   2026-09-25 조사: 사진 메뉴가 「설명·날짜 고치기」였는데 누르면 **설명만** 물었다.
   지난 모임 사진을 늦게 올리면 오늘 달로 묶여, 그 달 사진을 찾을 때 안 보였다. */
void main() {
  final st = AppState.i;

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });

  Future<Map<String, dynamic>> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start();
    final rows = [...st.by('photo')];
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: PhotoPage(rows: rows, start: 0),
    ));
    await t.pumpAndSettle();
    return rows.first;
  }

  testWidgets('메뉴 이름과 하는 일이 같다 — 설명 따로, 날짜 따로', (t) async {
    await open(t);
    await t.tap(find.byTooltip('더 보기'));
    await t.pumpAndSettle();
    expect(find.textContaining('설명·날짜'), findsNothing, reason: '날짜를 못 바꾸는데 날짜라고 적혀 있다');
    expect(find.text('✏️ 설명 고치기'), findsOneWidget);
    expect(find.text('📅 찍은 날짜 바꾸기'), findsOneWidget);
  });

  /* 🗑 보고 있는 사이 다른 회원이 이 사진을 지웠다 (2026-09-25 조사 — 같은 화면이라 여기 둔다).
     예전에는 옛 값을 그대로 보여 줘, 즐겨찾기·반응을 누르면 「바꾸지 못했어요」만 나왔다. */
  testWidgets('보는 사이 지워진 사진 — 지워졌다고 말하고 단추를 잠근다', (t) async {
    final first = await open(t);
    expect(find.textContaining('지워졌어요'), findsNothing, reason: '전제: 아직 있다');

    Demo.deleteItem(first['id'] as String); // 다른 회원이 지운 것처럼
    await t.pumpAndSettle();

    expect(find.textContaining('이 사진은 지워졌어요'), findsOneWidget);
    final more = t.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.more_vert));
    expect(more.onPressed, isNull, reason: '지워진 사진의 메뉴가 살아 있다');
    expect(find.text('❤️'), findsNothing, reason: '반응 단추가 그대로 떠 있다');
  });

  testWidgets('날짜를 고르면 그 사진의 날짜가 바뀐다', (t) async {
    final first = await open(t);
    final before = first['date'] as String;
    await t.tap(find.byTooltip('더 보기'));
    await t.pumpAndSettle();
    await t.tap(find.text('📅 찍은 날짜 바꾸기'));
    await t.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget, reason: '날짜 고르는 창이 안 뜬다');

    // 그 달의 1일을 고른다 — 원래 날짜가 1일이면 2일
    final day = before.endsWith('-01') ? '2' : '1';
    await t.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text(day)).first);
    await t.pumpAndSettle();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();

    final after = st.by('photo').firstWhere((p) => p['id'] == first['id'])['date'] as String;
    expect(after, isNot(before), reason: '골랐는데 날짜가 그대로다');
    expect(after.substring(0, 7), before.substring(0, 7), reason: '같은 달 안에서 골랐다');
    expect(after.endsWith('-0$day'), isTrue);
  });
}
