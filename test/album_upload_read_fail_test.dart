import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 📸 사진첩 여러 장 올리기 — 한 장을 못 읽어도 «나머지는 올리고» 결과를 말한다. (2026-09-25 조사)
   `readAsBytes()` 가 던지면(고른 뒤 지워진 사진·클라우드에만 있는 사진) try/finally 뿐이라
   반복이 통째로 끊겼다 — 남은 사진은 안 올라가고 「몇 장 올렸어요」도 안 떴다.
   대화방 사진 보내기(7회차)와 같은 고침. */
void main() {
  test('못 읽은 장은 «실패»로 세고 다음 장으로 간다', () {
    final s = File('lib/ui/board.dart').readAsStringSync();
    final at = s.indexOf('Future<void> _addPhotos(');
    final body = s.substring(at, s.indexOf('class _PostCard', at));
    final r = body.indexOf('readAsBytes()');
    final near = body.substring(r - 200, r + 300);
    expect(near, contains('catch (_)'), reason: '못 읽으면 반복이 통째로 끊긴다');
    expect(near, contains('fail++'));
  });
}
