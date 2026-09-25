import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/calendar.dart';
import 'package:woorimoim/ui/home.dart';

/* 📅 날짜가 망가진 모임(백업을 손으로 고쳤거나 옛 자료) — 홈·일정 화면이 터지지 않는다. (2026-09-26 점검)
   홈·일정은 `DateTime.parse(date)` 로 D-day 를 센다. 망가진 날짜가 거기까지 오면 화면이 빨갛게 된다. */
void main() {
  final st = AppState.i;
  for (final bad in ['2026-13-40', '2026-2-30', '어제', '', '20261001']) {
    testWidgets('날짜 «$bad» 모임이 있어도 홈·일정이 뜬다', (t) async {
      st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
      st.setCouple({'free': true, 'members': {'me': {'uid': 'me', 'name': '나', 'role': 'owner'}}});
      st.setItems(Store.tidy([
        {'id': 'e1', 'type': 'event', 'title': '망가진 날', 'date': bad, 'repeat': 'weekly'},
        {'id': 'e2', 'type': 'event', 'title': '멀쩡한 날', 'date': '2026-12-01'},
      ]));
      for (final w in [const HomeTab(), const CalendarTab()]) {
        await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: Scaffold(body: w)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '«$bad» 에서 ${w.runtimeType} 이 터진다');
      }
    });
  }
}
