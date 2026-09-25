import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🗑 대화 지우기 — 한 번 더 묻는다. (2026-09-25 조사)
   메뉴에서 「지우기」를 누르면 그 자리에서 지워졌다 — 되돌리기도 없다.
   손이 미끄러지면 회원 모두의 화면에서 사라지고, 운영진은 «남의 대화»도 이렇게 지운다.
   게시판 글·댓글은 처음부터 「이 글을 지울까요?」를 묻고 있었다. */
void main() {
  final s = File('lib/ui/chat.dart').readAsStringSync();
  final at = s.indexOf("} else if (pick == 'del') {");
  final branch = s.substring(at, s.indexOf('Future<void> _report(', at));

  test('지우기 전에 확인을 받는다', () {
    expect(at, greaterThan(0));
    final ask = branch.indexOf('confirmSheet(');
    expect(ask, greaterThan(0), reason: '누르자마자 지워진다');
    expect(ask, lessThan(branch.indexOf('deleteItem(')), reason: '지운 «뒤»에 물으면 소용없다');
  });

  test('남의 대화를 지울 때는 «남의 글»이라고 알린다', () {
    expect(branch, contains('님의 대화'));
  });
}
