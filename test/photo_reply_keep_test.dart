import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* ↩️📷 답장하며 사진 여러 장을 보낼 때 «첫 장»이 실패하면 답장이 사라졌다 (2026-09-26 87회차).

   답장은 첫 장에만 붙이는데(모든 장에 붙으면 어수선하다) «첫 장 = i==0» 으로 정해 두어서,
   첫 장을 못 읽거나 못 올리면 **어느 사진에도 답장이 안 붙었다.** 입력칸의 「답장 중」 표시는
   이미 지운 뒤라, 한 장도 못 보냈을 때는 무엇에 답하던 중이었는지조차 사라졌다.
   → «처음으로 실제로 올라간 장»에 붙이고, 한 장도 못 보냈으면 답장 표시를 되살린다. */
void main() {
  final s = File('lib/ui/chat.dart').readAsStringSync();
  final at = s.indexOf('Future<void> _sendPhoto()');
  final body = s.substring(at, s.indexOf('Future<void> _newPoll()', at));

  test('답장은 «처음 올라간 장»에 붙는다 — 몇 번째 장인지로 정하지 않는다', () {
    expect(body.contains('i == 0 && reply'), isFalse, reason: '첫 장이 실패하면 답장이 사라진다');
    expect(body, contains('!replied && reply != null'));
  });

  test('한 장도 못 보냈으면 답장 표시를 되살린다', () {
    expect(body, contains('_replyTo = reply'));
  });
}
