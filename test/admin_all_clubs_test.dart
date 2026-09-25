import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/ui/admin.dart';

/* 🗂 총괄 콘솔 — «앱에서 방장이 직접 만든 모임»도 보여야 한다. (2026-09-25 조사)
   콘솔은 총괄 목록(META)만 읽는데, 가입 화면의 「새 모임 만들기」는 META 에 못 적는다
   (방장에게 그 권한이 없다). 그래서 **돈 내는 손님이 만든 모임이 콘솔에 하나도 안 보였다** —
   방장이 폰을 잃어도 「방장 해제」를 못 하고, 지울 수도 없었다.
   모임 목록은 로그인한 누구나 읽을 수 있다(규칙 allow list) — 콘솔이 직접 읽어 합친다. */
void main() {
  test('META 에 없는 방을 합치고 «앱에서 만든 방»으로 표시한다', () {
    final out = mergeClubs(
      {'AAA111': {'title': '총괄이 만든 방', 'members': 3}},
      [
        {'code': 'AAA111', 'title': '총괄이 만든 방', 'members': {'a': {}, 'b': {}, 'c': {}}},
        {'code': 'BBB222', 'title': '손님이 만든 방', 'members': {'x': {}, 'y': {}}},
      ],
    );
    expect(out.keys, ['AAA111', 'BBB222'], reason: 'META 차례는 그대로, 새 방은 뒤에');
    expect(out['BBB222']!['title'], '손님이 만든 방');
    expect(out['BBB222']!['members'], 2);
    expect(out['BBB222']!['self'], true);
    expect(out['AAA111']!['self'], isNull, reason: 'META 에 있던 방은 그대로');
  });

  test('모임 목록 자체(META)·체험 자료는 방으로 치지 않는다', () {
    final out = mergeClubs({}, [
      {'code': 'META', 'isMeta': true, 'clubs': {}},
    ]);
    expect(out, isEmpty);
  });

  test('콘솔이 실제로 모든 방을 읽어 합친다', () {
    final s = File('lib/ui/admin.dart').readAsStringSync();
    expect(s, contains('Store.i.allClubs()'));
    expect(s, contains('mergeClubs('));
  });
  /* 2026-09-26 잡음: 「(앱에서 만든 방)」 표시를 이름에 붙여 카드에 넘겨서,
     「👥 회원용 이름」 복사에 그 표시까지 들어갔다 — 회원이 그 이름으로는 못 찾는다. */
  test('회원용 이름 복사에는 표시 없는 «진짜 이름»만 들어간다', () {
    final s = File('lib/ui/admin.dart').readAsStringSync();
    expect(s.contains(r"title: row['self'] == true ? '$name (앱에서 만든 방)' : name"), isFalse,
        reason: '표시를 이름에 붙이면 복사에도 들어간다');
    expect(s, contains("self: row['self'] == true"));
    expect(s, contains('Clipboard.setData(ClipboardData(text: title))'));
  });
}
