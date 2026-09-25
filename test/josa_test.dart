import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/ui/common.dart';

/* 🔤 토씨를 받침에 맞게. (2026-09-25 조사)
   직책을 회장·총무로 정하면 「총무 이라 운영진 권한도 함께 드렸어요」라고 떴다 —
   띄어쓰기도 틀리고, 받침 없는 「총무」에는 «라»가 맞다. */
void main() {
  test('이라/라', () {
    expect(josa('회장', '이라', '라'), '이라');
    expect(josa('총무', '이라', '라'), '라');
  });

  test('으로/로 — ㄹ 받침은 «로»', () {
    expect(josa('회장', '으로', '로', rieulAsNone: true), '으로');
    expect(josa('총무', '으로', '로', rieulAsNone: true), '로');
    expect(josa('기획실', '으로', '로', rieulAsNone: true), '로');
  });

  test('한글이 아니면 받침 있는 쪽(어느 쪽도 크게 어색하지 않다)', () {
    expect(josa('MC', '이라', '라'), '이라');
    expect(josa('', '이라', '라'), '이라');
  });

  test('회원 화면이 이 규칙을 쓴다', () {
    final s = File('lib/ui/members.dart').readAsStringSync();
    expect(s.contains(r"'$picked 이라 운영진"), isFalse);
    expect(s, contains("josa(picked, '이라', '라')"));
  });
}
