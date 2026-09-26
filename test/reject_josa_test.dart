import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* ✍️ 가입 신청 거절 확인창 — 「김민수을 거절할까요?」 (2026-09-26 90회차).

   이름 뒤에 「을」을 박아 두어, 받침 없는 이름(민수·지우·하나…)이면 토씨가 틀렸다.
   게다가 사람을 거절하는 것처럼 읽혔다 — 거절하는 것은 «신청»이다. 「○○님의 신청을」로. */
void main() {
  final s = File('lib/ui/members.dart').readAsStringSync();
  final at = s.indexOf('Future<void> _reject(');
  final body = s.substring(at, s.indexOf('okLabel:', at));

  test('이름 뒤에 토씨를 박지 않는다', () {
    expect(body.contains("}을 거절"), isFalse, reason: '「김민수을 거절할까요?」');
    expect(body, contains('님의 신청을 거절할까요?'));
  });
}
