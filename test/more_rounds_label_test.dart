import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/calendar.dart';

/* 📅 「더 보기」 단추가 «어느 쪽»을 더 보여 주는지 바로 말하는가

   반복 모임은 회차가 금방 마흔 개를 넘는다. 그때 목록을 자르고 단추를 하나 놓는데,
   두 목록은 차례가 서로 **반대**다:
     · 다가오는 모임 — 가까운 날부터. 잘린 것은 **뒤에 올** 회차.
     · 지난 모임    — 최근 것부터. 잘린 것은 **더 예전** 회차.

   그런데 단추는 양쪽 다 「이전 회차 …개 더 보기」라고 했다.
   다가오는 목록에서 그 말은 «지난 모임을 보여 준다»로 읽혀 아무도 안 누른다 —
   정작 다음 달 모임이 그 안에 있다. */
void main() {
  final st = AppState.i;

  Widget host(Widget child) =>
      MaterialApp(theme: buildTheme('sky'), home: Scaffold(body: child));

  /// 매주 모임 하나 — 몇 해 전에 시작해 회차가 넉넉히 마흔을 넘는다
  void seedWeekly() {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'title': '앞산 배드민턴',
      'free': true,
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': 'owner'},
      },
    });
    st.setItems(Store.tidy([
      {
        'id': 'e1', 'type': 'event', 'by': 'me', 'title': '정기 모임',
        'date': '2023-01-04', 'time': '19:00', 'repeat': 'week',
        'createdAt': 1672790400000,
      },
    ]));
  }

  setUp(seedWeekly);

  testWidgets('다가오는 목록에서는 «다음» 회차를 더 본다고 말한다', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    // 앞선 시험이 남긴 표를 비운다 — 회차 펼치기는 값을 기억해 둔다
    Logic.eventRows(past: false);

    await t.pumpWidget(host(const CalendarTab()));
    await t.pumpAndSettle();

    /* 자르고 남은 것이 있어야 단추가 나온다 — 매주 모임이면 넉넉하다.
       (앞으로 볼 수 있는 회차가 마흔 개를 안 넘으면 이 시험은 의미가 없다) */
    expect(Logic.eventRows(past: false).length, greaterThan(40),
        reason: '회차가 안 잘려 「더 보기」가 아예 안 나온다 — 시험이 헛돈다');

    await t.scrollUntilVisible(find.textContaining('더 보기'), 400);
    final label = t.widget<Text>(find.textContaining('더 보기')).data!;

    expect(label.contains('다음 회차'), isTrue,
        reason: '다가오는 목록인데 «$label» 라고 한다 — '
            '잘린 것은 뒤에 올 회차인데 지난 모임을 보여 준다는 뜻으로 읽힌다');
  });

  testWidgets('지난 목록에서는 «이전» 회차를 더 본다고 말한다', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    Logic.eventRows(past: true);

    await t.pumpWidget(host(const CalendarTab()));
    await t.pumpAndSettle();

    await t.tap(find.text('지난 모임 · 출석'));
    await t.pumpAndSettle();

    expect(Logic.eventRows(past: true).length, greaterThan(40),
        reason: '지난 회차가 안 잘려 「더 보기」가 안 나온다 — 시험이 헛돈다');

    await t.scrollUntilVisible(find.textContaining('더 보기'), 400);
    final label = t.widget<Text>(find.textContaining('더 보기')).data!;

    expect(label.contains('이전 회차'), isTrue,
        reason: '지난 목록인데 «$label» 라고 한다 — 잘린 것은 더 예전 회차다');
  });
}
