import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';

/* 👥 같은 이름 두 사람 — 얼굴 없이 이름만 늘어놓는 곳에서 구별이 되게. (2026-09-26 조사)
   이 앱은 아바타만 다르면 같은 이름 가입을 허락한다. 그런데 참석 명단·미납 명단·출석 칸은
   이름만 보여 「김민수, 김민수」가 되어 누가 누군지 알 수 없었다.
   → 이름이 겹칠 때만 아바타를 붙인다(겹치지 않으면 예전 그대로). */
void main() {
  final st = AppState.i;
  setUp(() {
    st.profile = {'code': 'C', 'slot': 'a', 'name': '김민수'};
    st.setCouple({
      'members': {
        'a': {'uid': 'a', 'name': '김민수', 'emoji': '🧑', 'role': 'owner'},
        'b': {'uid': 'b', 'name': '김민수', 'emoji': '😎', 'role': 'member'},
        'c': {'uid': 'c', 'name': '이서현', 'emoji': '👩', 'role': 'member'},
      },
    });
  });

  test('겹치는 이름에만 아바타를 붙인다', () {
    expect(st.listName('a'), '김민수🧑');
    expect(st.listName('b'), '김민수😎');
    expect(st.listName('c'), '이서현');
  });

  test('참석 명단이 이 이름을 쓴다', () {
    final e = {'rsvp': {Logic.rkey('2026-10-01', 'a'): 'yes', Logic.rkey('2026-10-01', 'b'): 'yes'}};
    expect(Logic.rsvpNames(e, '2026-10-01', 'yes').toSet(), {'김민수🧑', '김민수😎'});
  });

  test('홈 미납 명단·출석 칸도 이 이름을 쓴다', () {
    expect(File('lib/ui/home.dart').readAsStringSync(), contains('st.listName('));
    expect(File('lib/ui/calendar.dart').readAsStringSync(), contains('listName('));
    expect(File('lib/ui/fee_sheet_screen.dart').readAsStringSync(), contains('listName('), reason: '회비 표 이름 칸');
  });
}
