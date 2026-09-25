import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 💬 알림(toast)을 «연달아» 띄우면 앞의 것이 곧바로 덮인다 — 사람은 뒤의 것만 본다. (2026-09-25 에뮬)
   대화 사진 6장 이상을 고르면 「한 번에 5장까지…」 바로 뒤 「사진 5장 올리는 중…」이 떠서
   «뒤 사진은 안 갔다»는 말을 아무도 못 봤다. 한 줄로 합친다. */
void main() {
  test('대화 사진 5장 제한 안내가 «올리는 중» 알림에 덮이지 않는다', () {
    final s = File('lib/ui/chat.dart').readAsStringSync();
    final at = s.indexOf('await pickManyPhotos(context)', s.indexOf('Future<void> _sendPhoto('));
    expect(at, greaterThan(0));
    final part = s.substring(at, s.indexOf('// 답장 중', at));
    expect(RegExp(r'toast\(').allMatches(part).length, 1,
        reason: '두 번 띄우면 첫 안내(5장 제한)가 곧바로 덮인다');
    expect(part, contains('5장까지'));
  });
}
