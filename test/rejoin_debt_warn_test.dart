import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 💵 밀린 채 나갔던 사람이 다시 가입해 «승인»하면 — 옛 밀린 회비가 표에서 사라진다. (2026-09-26 조사)
   승인은 탈퇴 기록(former)을 지우고 새 가입일을 적는다. 그러면 나가기 전 밀린 달이 회비 표·현황에서 안 보인다.
   받을 돈을 챙길 가장 좋은 때가 바로 다시 들어올 때인데, 운영진은 그 사실을 모른 채 승인했다.
   → 승인 «전에» 밀린 달을 보여 주고 확인받는다(먼저 받아 적거나, 그대로 승인). */
void main() {
  test('다시 가입하는 사람의 밀린 회비를 승인 전에 알린다', () {
    final s = File('lib/ui/members.dart').readAsStringSync();
    final at = s.indexOf('Future<void> _approve(');
    final body = s.substring(at, s.indexOf('List<Widget> _reports(', at));
    final debt = body.indexOf('Logic.unpaidMonths(');
    expect(debt, greaterThan(0));
    final ask = body.indexOf('confirmSheet(', debt);
    expect(ask, greaterThan(0), reason: '모른 채 승인하면 옛 밀린 회비가 사라진다');
    expect(ask, lessThan(body.indexOf('mutateCouple(')), reason: '승인한 «뒤»에 알리면 늦다');
    expect(body, contains('그대로 승인'));
  });
}
