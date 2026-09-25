import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

/* 🔁 반복 모임을 «이 회차부터 그만하기» — 지난 모임과 출석 기록은 그대로.

   2026-09-25 조사: 반복 모임은 한 회차 카드에서 「지우기」를 눌러도 반복 전체가,
   그리고 몇 년치 출석·참석 기록(배지·순위의 바탕)이 통째로 사라졌다.
   안내는 「반복 모임 전체가 사라져요」 한 줄뿐, 기록 얘기는 없었다. */
void main() {
  final weekly = <String, dynamic>{
    'id': 'e1',
    'type': 'event',
    'title': '정기모임',
    'date': '2026-01-07', // 수요일마다
    'repeat': 'week',
    'attend': {'2026-01-07_u1': true, '2026-01-14_u1': true, '2026-01-21_u2': true},
    'rsvp': {'2026-10-07_u1': 'yes'},
  };

  test('«이 회차부터» 멈추면 그 전날까지만 남는다', () {
    final stop = Logic.stopBefore(weekly, '2026-09-30');
    expect(stop, '2026-09-29');
    final after = {...weekly, 'until': stop};
    expect(Logic.occursOn(after, '2026-09-23'), isTrue, reason: '지난 회차가 사라졌다');
    expect(Logic.occursOn(after, '2026-01-14'), isTrue, reason: '지난 출석 날이 사라졌다');
    expect(Logic.occursOn(after, '2026-09-30'), isFalse, reason: '멈춘 회차가 아직 있다');
    expect(Logic.occursOn(after, '2026-10-07'), isFalse);
  });

  test('멈춰도 지난 출석 기록은 하나도 안 빠진다', () {
    final after = {...weekly, 'until': Logic.stopBefore(weekly, '2026-09-30')};
    // 빠지는 것은 멈춘 뒤의 참석 표시(10/7) 한 건뿐 — 출석 셋은 그대로 센다
    expect(Logic.recordsDropped(weekly, after), 1);
  });

  test('첫 회차에서는 «멈추기»를 안 준다 — 회차가 하나도 안 남아 유령 일정이 된다', () {
    expect(Logic.stopBefore(weekly, '2026-01-07'), isNull);
    expect(Logic.stopBefore(weekly, '2026-01-01'), isNull);
    expect(Logic.stopBefore({'title': '날짜 없음'}, '2026-05-01'), isNull);
  });

  test('통째로 지울 때 함께 사라지는 기록 수를 센다', () {
    expect(Logic.recordsIn(weekly), 4);
    expect(Logic.recordsIn({'id': 'x'}), 0);
  });

  test('일정 카드의 지우기가 반복 모임에 «멈추기»를 먼저 내놓는다', () {
    final s = File('lib/ui/calendar.dart').readAsStringSync();
    expect(s, contains('Logic.stopBefore(event, date)'));
    expect(s, contains("'until': stop"));
    final stopAt = s.indexOf("['stop',");
    final allAt = s.indexOf("['all',");
    expect(stopAt, greaterThan(0));
    expect(stopAt, lessThan(allAt), reason: '지난 기록을 지키는 쪽이 먼저 보여야 한다');
    // ⚠️ 주석은 걷어내고 본다 — 고친 이유를 적은 설명에 옛 문구가 들어 있다
    final code = s
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//.*'), '');
    expect(code.contains('반복 모임 전체가 사라져요'), isFalse,
        reason: '기록이 같이 사라진다는 말 없이 지우는 옛 안내가 남아 있다');
  });
}
