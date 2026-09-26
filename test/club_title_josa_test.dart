import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/ui/common.dart';

/* ✍️ 모임 이름 뒤 토씨를 박아 두었다 (2026-09-26 91회차).

   「「하나회」을 만드셨습니다」·「「하나회」은 이용료를…」 — 받침 없는 이름이면 틀린다.
   모임 이름은 방장이 짓는 것이라 받침이 있을지 없을지 모른다 → josa() 로 고른다. */
void main() {
  test('받침 따라 고른다', () {
    expect(josa('하나회', '을', '를'), '를');
    expect(josa('앞산 배드민턴', '을', '를'), '을');
    expect(josa('하나회', '은', '는'), '는');
  });

  for (final (path, bad) in const [
    ('lib/ui/owner_guide.dart', '」을 만드셨습니다'),
    ('lib/ui/fee_screen.dart', '」은 이용료를'),
    ('lib/ui/settings.dart', '」을 알려주면 됩니다'),
  ]) {
    test('$path — 모임 이름 뒤 토씨를 박지 않는다', () {
      final s = File(path).readAsStringSync();
      expect(s.contains(bad), isFalse, reason: '받침 없는 이름이면 토씨가 틀린다: «$bad»');
    });
  }
}
