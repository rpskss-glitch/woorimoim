import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/ui/album.dart';

/* 🗑 사진 여러 장 지우기 — 못 지운 장을 말하지 않았다 (2026-09-26 78회차).

   연결이 끊겨 몇 장이 안 지워져도 「2장 지웠어요」만 떴다 — 고른 3장이 다 지워진 줄 안다.
   하나도 못 지우면 「0장 지웠어요」에 까닭도 없었다(잠긴 모임이면 잠긴 까닭을 말해야 한다). */
void main() {
  test('못 지운 장을 센다', () {
    expect(bulkDeleteLine(done: 2, denied: 0, failed: 1), contains('1장은 지우지 못했어요'));
    expect(bulkDeleteLine(done: 3, denied: 0, failed: 0), '3장 지웠어요');
    final both = bulkDeleteLine(done: 1, denied: 2, failed: 1);
    expect(both, contains('2장은 남이 올린 사진'));
    expect(both, contains('1장은 지우지 못했어요'));
  });

  test('하나도 못 지웠으면 «0장 지웠어요»가 아니라 실패 안내(잠긴 까닭)', () {
    final s = File('lib/ui/album.dart').readAsStringSync();
    final at = s.indexOf('Future<void> _delPicked(');
    final body = s.substring(at, s.indexOf('class PhotoPage', at));
    expect(body, contains('failed++'));
    expect(body, contains('saveFailToast('));
    expect(body, contains('bulkDeleteLine('));
  });
}
