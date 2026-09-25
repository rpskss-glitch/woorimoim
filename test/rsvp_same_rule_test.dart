import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 🙆 참석 «숫자»와 «얼굴 줄»이 같은 사람들을 센다.

   2026-09-25 조사: 홈 「다음 모임」 카드의 단추는 「🙆 참석 2」인데, 바로 아래 줄은 「참석 4명」이었다.
   얼굴 줄만 원자료(rsvp 열쇠)를 그대로 세어, 탈퇴한 사람과 폰 바꾼 사람의 옛 번호까지 들어갔다. */
void main() {
  const date = '2026-10-03';
  final ev = <String, dynamic>{
    'id': 'e1',
    'type': 'event',
    'date': date,
    'rsvp': {
      '${date}_u1': 'yes',
      '${date}_u2': 'yes',
      '${date}_old1': 'yes', // u1 이 폰을 바꾸기 전 번호 — 같은 사람
      '${date}_gone': 'yes', // 탈퇴한 사람
      '${date}_u3': 'no',
    },
  };

  setUp(() {
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'u1': {'uid': 'u1', 'name': '갑', 'role': 'member'},
        'u2': {'uid': 'u2', 'name': '을', 'role': 'member'},
        'u3': {'uid': 'u3', 'name': '병', 'role': 'member'},
      },
      'former': {
        'old1': {'uid': 'old1', 'name': '갑', 'movedTo': 'u1'},
        'gone': {'uid': 'gone', 'name': '정'},
      },
    });
  });

  test('참석한 «지금 회원»만, 사람 단위로 한 번씩', () {
    expect(Logic.rsvpUids(ev, date, 'yes')..sort(), ['u1', 'u2']);
    expect(Logic.rsvpCount(ev, date, 'yes'), 2);
    expect(Logic.rsvpNames(ev, date, 'yes')..sort(), ['갑', '을']);
  });

  test('홈의 얼굴 줄도 같은 규칙을 쓴다 (원자료를 직접 세지 않는다)', () {
    final home = File('lib/ui/home.dart').readAsStringSync();
    expect(home, contains("Logic.rsvpUids(event, date, 'yes')"));
    expect(home.contains(".where((e) => e.value == 'yes' && e.key.startsWith("), isFalse,
        reason: '원자료를 그대로 세면 단추 숫자와 다른 숫자가 나온다');
  });
}
