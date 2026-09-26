import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🏷 사진 여러 장에 태그 달기 안내 — 「3장에 #모임 를 붙였어요」 (2026-09-26 92회차).

   태그 뒤에 「를」을 박아 두어 받침 있는 태그(모임·대회전·단체복…)면 토씨가 틀렸다.
   태그는 회원이 짓는 것이라 받침을 모른다 → 「#모임 태그를」로 토씨가 늘 맞게. */
void main() {
  test('태그 뒤에 토씨를 박지 않는다', () {
    final s = File('lib/ui/album.dart').readAsStringSync();
    expect(s.contains("#\$tag 를"), isFalse, reason: '「#모임 를」');
    expect(s, contains("#\$tag 태그를 붙였어요"));
  });
}
