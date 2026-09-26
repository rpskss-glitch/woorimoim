import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 👑💳 방장이 탈퇴하면 방장 자리가 저절로 넘어가는데, 이용권 갱신이 끊긴다는 말이 없었다 (2026-09-26 86회차).

   77회차에 «방장 넘기기» 확인창에는 넣었다(Fee.handoverNote) — 이용권은 넘기는 방장의 스토어 계정으로
   청구되고, 넘긴 뒤에는 갱신 영수증이 아무 데로도 안 들어가 끝나는 날 + 사흘 뒤 모임이 잠긴다.
   탈퇴도 «자동으로 넘기는» 길인데 「스토어에서 해지하라」만 있고 «모임이 곧 잠긴다»는 말이 없었다. */
void main() {
  test('방장 탈퇴 확인창도 넘기기와 같은 이용권 안내를 싣는다', () {
    final s = File('lib/ui/settings.dart').readAsStringSync();
    final at = s.indexOf('Future<void> _deleteMyData()');
    final body = s.substring(at, s.indexOf('confirmSheet(', at));
    expect(body, contains('Fee.handoverNote()'), reason: '넘겨받은 새 방장이 결제해야 한다는 말이 없다');
  });
}
