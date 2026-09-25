import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 💵 여러 명 회비 받기 — «이미 다 낸 사람»은 실패가 아니다. (2026-09-25 조사)
   건너뛴 사람(앞으로까지 다 채워져 있음)도 `!done` 이라 「3명 기록, 2명 못 함」으로 떴다 —
   총무는 무언가 잘못된 줄 알고 그 두 사람을 다시 누른다. 따로 말한다. */
void main() {
  final s = File('lib/ui/wallet.dart').readAsStringSync();
  final at = s.indexOf('Future<void> _receiveMany(');
  final body = s.substring(at, s.indexOf('// ── 내역', at));

  test('건너뛴 사람은 «못 함»에서 뺀다', () {
    expect(body, contains('r.skipped'));
    expect(body.contains("final bad = res.where((r) => !r.done).toList();"), isFalse,
        reason: '건너뛴 사람까지 실패로 센다');
  });

  test('건너뛴 사람은 «이미 다 냈어요»로 따로 알린다', () {
    expect(body, contains('이미 다 냈어요'));
  });
}
