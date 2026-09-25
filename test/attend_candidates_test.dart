import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';

/* ✅ 지난 모임의 출석 칸 — 그 모임 «뒤에» 들어온 회원은 싣지 않는다. (2026-09-26 조사)
   지금 회원 전원을 칩으로 늘어놓아, 1년 전 모임에 어제 가입한 사람도 나왔다.
   운영진이 잘못 누르면 없던 출석이 붙어 배지·순위가 틀어진다.
   ⚠️ 이미 출석이 찍혀 있으면(옛 기록·다시 들어온 사람) 그대로 보여 준다 — 끌 수 있어야 한다.
   ⚠️ 들어온 때를 모르면(옛 판) 뺄 근거가 없으니 보여 준다. */
void main() {
  final st = AppState.i;
  final day = DateTime(2026, 9, 1);

  setUp(() {
    st.profile = {'code': 'C', 'slot': 'a', 'name': '가'};
    st.setCouple({
      'members': {
        'a': {'uid': 'a', 'name': '가', 'role': 'owner', 'joinedAt': DateTime(2025, 1, 1).millisecondsSinceEpoch},
        'same': {'uid': 'same', 'name': '당일', 'role': 'member', 'joinedAt': DateTime(2026, 9, 1, 21).millisecondsSinceEpoch},
        'late': {'uid': 'late', 'name': '늦게', 'role': 'member', 'joinedAt': DateTime(2026, 9, 10).millisecondsSinceEpoch},
        'lateOn': {'uid': 'lateOn', 'name': '늦게찍힘', 'role': 'member', 'joinedAt': DateTime(2026, 9, 10).millisecondsSinceEpoch},
        'old': {'uid': 'old', 'name': '옛판', 'role': 'member'},
      },
    });
  });

  test('모임 날까지 들어온 사람 + 이미 찍힌 사람 + 들어온 때 모르는 사람', () {
    final e = {'id': 'e', 'type': 'event', 'date': '2026-09-01', 'attend': {Logic.rkey('2026-09-01', 'lateOn'): true}};
    final uids = Logic.attendCandidates(e, '2026-09-01').map((m) => m['uid']).toSet();
    expect(uids, {'a', 'same', 'lateOn', 'old'});
    expect(uids.contains('late'), isFalse, reason: '모임 뒤에 가입한 사람');
    expect(day.year, 2026);
  });

  test('일정 화면이 이 목록을 쓴다', () {
    final s = File('lib/ui/calendar.dart').readAsStringSync();
    expect(s, contains('Logic.attendCandidates(event, date)'));
  });
}
