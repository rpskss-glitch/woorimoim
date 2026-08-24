// 일정을 고쳤을 때 «세어지지 않게 되는» 출석·참석 기록.
//
// 출석·투표는 「날짜_uid」로 적히고, 목록·배지·순위는 «지금 회차 목록에 있는 날짜»만 센다.
// 그래서 날짜뿐 아니라 **반복 주기·종료일만 바꿔도** 기록이 문서에 남은 채 화면에서 사라진다.
// 82회차에 찾았다 — 그전에는 «날짜»를 바꿀 때만 알렸다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

/// 2026-01-05(월)부터 매주, 다섯 회차에 두 사람씩 출석해 둔 모임
Map<String, dynamic> weekly() => {
      'type': 'event',
      'date': '2026-01-05',
      'repeat': 'week',
      'attend': {
        for (final d in ['2026-01-05', '2026-01-12', '2026-01-19', '2026-01-26', '2026-02-02'])
          for (final u in ['u1', 'u2']) '${d}_$u': true,
      },
      'rsvp': {'2026-01-12_u1': 'yes'},
    };

void main() {
  test('안 바꾸면 사라지는 것이 없다', () {
    final e = weekly();
    expect(Logic.recordsDropped(e, {...e}), 0);
    // 이름·장소만 고치는 것도 회차와 무관하다
    expect(Logic.recordsDropped(e, {...e, 'title': '새 이름', 'place': '체육관'}), 0);
  });

  test('«반복 없음»으로 바꾸면 첫 회차 빼고 다 사라진다', () {
    final e = weekly();
    final lost = Logic.recordsDropped(e, {...e, 'repeat': 'none'});
    // 출석 10건 중 첫날 2건만 남는다 + 투표 1건도 사라진다
    expect(lost, 9, reason: '3년치 매주 모임이면 이 숫자가 수백이 된다');
  });

  test('«매달»로 바꿔도 대부분 사라진다', () {
    final e = weekly();
    final lost = Logic.recordsDropped(e, {...e, 'repeat': 'month'});
    expect(lost, greaterThan(5));
  });

  test('끝나는 날을 당기면 그 뒤 기록이 사라진다', () {
    final e = weekly();
    // 남는 회차 = 1/05·1/12·1/19 → 사라지는 것은 1/26 두 건 + 2/2 두 건
    expect(Logic.recordsDropped(e, {...e, 'until': '2026-01-19'}), 4);
  });

  test('끝나는 날을 뒤로 미루면 사라지는 것이 없다', () {
    final e = weekly();
    expect(Logic.recordsDropped(e, {...e, 'until': '2030-01-01'}), 0);
  });

  test('날짜를 옮기면 옛 회차가 전부 어긋난다', () {
    final e = weekly();
    expect(Logic.recordsDropped(e, {...e, 'date': '2026-01-06'}), 11);
  });

  test('기록이 없으면 무엇을 바꿔도 0', () {
    final e = {'type': 'event', 'date': '2026-01-05', 'repeat': 'week'};
    expect(Logic.recordsDropped(e, {...e, 'repeat': 'none'}), 0);
  });

  test('망가진 열쇠가 섞여 있어도 죽지 않는다', () {
    final e = {
      'type': 'event',
      'date': '2026-01-05',
      'repeat': 'week',
      'attend': {'짧음': true, '2026-01-12_u1': true, '': true},
      'rsvp': '배열이 아님',
    };
    expect(Logic.recordsDropped(e, {...e, 'repeat': 'none'}), 1);
  });

  test('일정 고치기가 이 셈을 실제로 쓴다', () {
    final src = File('lib/ui/calendar.dart').readAsStringSync();
    final at = src.indexOf('Future<void> _save()');
    final body = src.substring(at, src.indexOf('\n  }\n', at));
    expect(body.contains('Logic.recordsDropped'), isTrue,
        reason: '날짜만 보면 반복·종료일 바꿈을 못 잡는다');
    expect(body.contains("ymd(_date) != (e['date']"), isFalse,
        reason: '옛 판단이 남아 있다');
    // 셈은 반드시 «저장할 값»이 만들어진 뒤에 해야 한다
    expect(body.indexOf('final data = <String, dynamic>{'),
        lessThan(body.indexOf('Logic.recordsDropped')));
  });
}
