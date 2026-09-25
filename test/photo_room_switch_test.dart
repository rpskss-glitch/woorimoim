import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🔒 사진 여러 장을 보내는 도중 방을 바꾸면 — 남은 사진이 «바꾼 방»으로 갔다. (2026-09-25 조사)
   운영진 방에서 5장을 고르고, 올라가는 사이 「모두」 방으로 넘어가면
   남은 장들은 방 표시 없이 올라가 **운영진끼리 보던 사진이 회원 모두에게** 보였다.
   (방 표시를 한 장마다 «그때의 방»에서 새로 읽었기 때문) */
String _strip(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

void main() {
  final src = _strip(File('lib/ui/chat.dart').readAsStringSync());
  final at = src.indexOf('Future<void> _sendPhoto(');
  final body = src.substring(at, src.indexOf('Future<void> _newPoll(', at));
  final loopAt = body.indexOf('for (var i = 0; i < picked.length');

  test('방 표시는 고르기 전에 한 번만 잡는다', () {
    expect(loopAt, greaterThan(0));
    final head = body.substring(0, loopAt);
    expect(head, contains('= _roomTag;'), reason: '보내기를 시작한 방을 잡아 두지 않는다');
    expect(head.indexOf('= _roomTag;'), lessThan(head.indexOf('pickManyPhotos')),
        reason: '고르는 사이에 방을 바꿔도 «누른 방»으로 가야 한다');
  });

  test('한 장씩 올릴 때 «지금 방»을 다시 읽지 않는다', () {
    expect(body.substring(loopAt).contains('_roomTag'), isFalse,
        reason: '도중에 방을 바꾸면 남은 사진이 다른 방으로 간다');
  });

  test('사진 파일을 못 읽어도 화면이 터지지 않고 «못 보낸 장»으로 센다', () {
    final loop = body.substring(loopAt);
    final r = loop.indexOf('readAsBytes()');
    expect(loop.lastIndexOf('try {', r), greaterThanOrEqualTo(0));
  });
}
