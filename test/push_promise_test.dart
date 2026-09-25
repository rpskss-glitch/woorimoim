import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🔔 알림 안내는 «서버가 실제로 보내는 것»만 약속한다. (2026-09-26 조사)
   서버 알림 함수는 대화방 메시지(msgs)에만 걸려 있다 — 게시판 공지는 알림이 안 간다.
   그런데 홈 카드가 「새 대화·공지가 올라오면 알려드려요」라고 했고,
   설정의 이름은 「공지만」인데 홈은 「공지만 받기」라고 불렀다. */
void main() {
  test('홈 알림 카드가 게시판 공지 알림을 약속하지 않는다', () {
    final s = File('lib/ui/home.dart').readAsStringSync();
    expect(s.contains('새 대화·공지가 올라오면 알려드려요'), isFalse);
    expect(s.contains('「공지만 받기」'), isFalse, reason: '설정의 이름은 「공지만」이다');
  });

  test('서버 알림은 여전히 대화(msgs)에만 걸려 있다 — 바뀌면 안내도 다시 본다', () {
    final f = File('../앞산배드민턴/functions/index.js');
    if (!f.existsSync()) return markTestSkipped('서버 파일이 없는 기기');
    final s = f.readAsStringSync();
    final triggers = RegExp(r'onDocumentCreated\(\s*\{\s*document:\s*`\$\{BASE\}/(\w+)/').allMatches(s)
        .map((m) => m[1]).toList();
    expect(triggers, ['msgs'], reason: '게시판 알림이 생겼다면 홈 안내를 다시 고쳐라');
  });
}
