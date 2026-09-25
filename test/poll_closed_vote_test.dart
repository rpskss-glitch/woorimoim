import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 📊 보는 사이 마감된 투표를 누르면 — «마감됐다»고 말한다. (2026-09-26 조사)
   마감 시각이 지났거나 만든 사람이 마감하면 서버 쪽 확인(p.closed)이 쓰기를 멈춘다.
   그런데 화면은 「투표하지 못했어요 — 다시 눌러주세요」라고만 해서, 몇 번을 다시 눌러도 같은 말만 나왔다. */
void main() {
  final s = File('lib/ui/chat.dart').readAsStringSync();
  final at = s.indexOf('Future<void> _vote(int i)');
  final body = s.substring(at, s.indexOf('Future<void> _setClosed(', at));

  test('마감돼서 못 쓴 것을 따로 잡는다', () {
    expect(body, contains('closedNow = true'));
  });

  test('마감이면 «마감됐어요»라고 말한다', () {
    expect(body, contains('투표가 마감됐어요'));
  });
}
