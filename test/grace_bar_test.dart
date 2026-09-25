import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* ⏳ 유예 3일 동안 방장 화면 맨 위에 «곧 잠겨요» 띠. (2026-09-25 조사)
   빨간 띠(_LockBar)는 잠긴 «뒤»에만 떴다 — 방장은 이용권 화면에 들어가 보지 않는 한
   잠기기 전에 알 길이 없었다. ⚠️ 회원에게는 안 띄운다 — 낼 수도 없는 사람에게 겁만 준다. */
void main() {
  final s = File('lib/ui/shell.dart').readAsStringSync();

  test('방장에게만, 유예 중에 띠를 띄운다', () {
    expect(s, contains('Fee.inGrace && Fee.iPay'));
  });

  test('띠는 몇 일 남았는지 말하고 이용권 화면으로 데려간다', () {
    expect(s, contains('Fee.graceLeft'));
  });
}
