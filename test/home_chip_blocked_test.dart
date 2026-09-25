import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🚫 홈 「최근 게시판」 칩 숫자 — 차단한 회원 것은 안 센다. (2026-09-26 조사)
   사진첩·대화방은 차단한 회원의 사진·말을 가리는데, 홈 칩은 그대로 세어
   「사진첩 3장」인데 들어가면 2장뿐이었다(에뮬에서 차단 뒤 사진첩은 3→2장). */
void main() {
  test('사진·대화 수를 셀 때 차단한 회원 것을 뺀다', () {
    final s = File('lib/ui/home.dart').readAsStringSync();
    final at = s.indexOf("final photos = ");
    final part = s.substring(at, at + 700);
    expect(part, contains("Moderation.hide(st.by('photo'))"));
    expect(part, contains("Moderation.hide(st.by('msg'))"));
  });
}
