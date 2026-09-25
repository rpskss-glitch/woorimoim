import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 💗 사진첩 정리 — 즐겨찾기 한꺼번에 넣기의 안내. (2026-09-26 조사)
   하나도 안 되면 「0장만 됐어요」라는 이상한 말이 나왔고, 잠긴 모임이어도 까닭을 안 말했다. */
void main() {
  final s = File('lib/ui/album.dart').readAsStringSync();
  final at = s.indexOf('Future<void> _favPicked(');
  final body = s.substring(at, s.indexOf('Future<void> _tagPicked(', at));

  test('하나도 안 되면 «0장만»이 아니라 실패 안내(잠겼으면 잠긴 까닭)', () {
    expect(body, contains('ok == 0'));
    expect(body, contains('saveFailToast('));
  });
}
