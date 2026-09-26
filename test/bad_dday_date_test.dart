import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/home.dart';

/* ⏳ 날짜가 망가진 «클럽 D-day»가 홈을 통째로 터뜨렸다 (2026-09-26 85회차).

   홈의 D-day 카드는 `DateTime.parse(date)` 로 남은 날을 센다. 다듬기(fixDate)는 0만 채우고
   알 수 없는 글자는 그대로 두므로, 「2026.12.25」 같은 날짜(백업을 손으로 고쳤거나 옛 자료)가
   «오늘보다 뒤»로 견줘져 카드에 올라오면 그 자리에서 FormatException — 홈 화면이 안 뜬다.
   (모임 날짜는 bad_event_date_test 가 지키는데 D-day 만 빠져 있었다) */
void main() {
  final st = AppState.i;
  for (final bad in ['2026.12.25', '2026/12/25', '내년 봄', '2099-1-1T', '9999-99-99x']) {
    testWidgets('D-day 날짜 «$bad» 가 있어도 홈이 뜬다', (t) async {
      st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
      st.setCouple({'free': true, 'members': {'me': {'uid': 'me', 'name': '나', 'role': 'owner'}}});
      st.setItems(Store.tidy([
        {'id': 'd1', 'type': 'dday', 'title': '망가진 날', 'date': bad, 'createdAt': DateTime.now().millisecondsSinceEpoch},
        {'id': 'd2', 'type': 'dday', 'title': '가을 대회', 'date': '2099-10-01', 'createdAt': DateTime.now().millisecondsSinceEpoch},
      ]));
      await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: const Scaffold(body: HomeTab())));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '«$bad» 에서 홈이 터진다');
    });
  }
}
