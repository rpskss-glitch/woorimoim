import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 💵 월 회비를 «끄는» 것은 한 번 더 묻는다. (2026-09-25 조사)
   입력칸을 지우고 「저장」하면 0원 = 회비를 쓰지 않는 모임이 된다 —
   회원들의 «밀린 회비»가 전부 안 보이고 홈의 회비 카드도 사라진다.
   숫자를 고쳐 쓰려고 지운 채 저장을 눌러도 알림 한 줄로 끝났다. */
void main() {
  final s = File('lib/ui/settings.dart').readAsStringSync();
  final at = s.indexOf('Future<void> _editFee(');
  final body = s.substring(at, s.indexOf('Future<void> _editEmblem(', at));

  test('켜져 있던 회비를 0으로 만들 때 확인을 받는다', () {
    expect(body, contains('cur > 0 && amount == 0'));
    final ask = body.indexOf('confirmSheet(');
    expect(ask, greaterThan(0));
    expect(ask, lessThan(body.indexOf('Store.i.setCouple(')), reason: '저장한 «뒤»에 물으면 소용없다');
  });
}
