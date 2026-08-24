// 직책이 «회비 장부»를 여는 것을 방장이 아는가 (142회차).
//
// 서버는 role 뿐 아니라 «직책»만 맞아도 회비 장부를 열어 준다.
// 권한을 «내릴» 때는 앱이 이미 알려 주고 있었다:
//   「직책이 있으면 권한과 상관없이 회비 장부를 쓰고 고칠 수 있어요」
// 그런데 직책을 «줄» 때는 아무 말이 없었다 — 짝이 안 맞았다.
// 특히 「총무보·회계」는 「권한도 드릴까요?」조차 안 묻는 직책이라(adminTitles 에 없다)
// 방장은 회비 장부를 넘겼다는 사실을 **알 길이 아예 없었다.**
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/config.dart';
import 'package:woorimoim/logic.dart';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

/// 함수 몸통만 — 매개변수 괄호를 짝 맞춰 닫은 «뒤»의 `{` 부터 (120회차 함정).
String bodyOf(String src, String decl) {
  final at = src.indexOf(decl);
  if (at < 0) return '';
  var i = src.indexOf('(', at), d = 0;
  for (; i < src.length; i++) {
    if (src[i] == '(') d++;
    if (src[i] == ')') {
      d--;
      if (d == 0) break;
    }
  }
  final open = src.indexOf('{', i);
  d = 0;
  for (var j = open; j < src.length; j++) {
    if (src[j] == '{') d++;
    if (src[j] == '}') {
      d--;
      if (d == 0) return src.substring(open, j + 1);
    }
  }
  return src.substring(open);
}

void main() {
  final members = stripComments(File('lib/ui/members.dart').readAsStringSync());

  test('어느 직책이 회비를 여는지', () {
    for (final t in ['총무', '재무이사', '총무보', '회계']) {
      expect(Logic.keepsMoneyByTitle(t), isTrue, reason: '$t 는 회비를 연다');
    }
    for (final t in ['회장', '부회장', '경기이사', '섭외이사', '코치', '주장']) {
      expect(Logic.keepsMoneyByTitle(t), isFalse);
    }
    expect(Logic.keepsMoneyByTitle(null), isFalse);
    expect(Logic.keepsMoneyByTitle(''), isFalse);
  });

  test('«묻지도 않는데» 회비가 열리는 직책이 있다 — 그래서 알려야 한다', () {
    /* 이 겹치지 않는 부분이 이 회차의 까닭이다. 목록이 바뀌어 겹침이 사라지면
       이 시험이 알려 준다 — 그때는 알림 문구를 손볼지 다시 생각해야 한다. */
    final silent =
        treasurerTitles.where((t) => !adminTitles.contains(t)).toSet();
    expect(silent, {'총무보', '회계'},
        reason: '「권한도 드릴까요?」를 안 묻는데 회비가 열리는 직책');
  });

  test('직책을 «줄» 때 회비가 열리는 것을 알린다', () {
    final body = bodyOf(members, 'Future<void> _setTitle(');
    expect(body, isNotEmpty);
    expect(body.contains('Logic.keepsMoneyByTitle('), isTrue,
        reason: '방장이 회비 장부를 넘긴 줄 모른다');
    expect(body.contains('회비 장부를 쓰고 고칠 수 있어요'), isTrue);
  });

  test('이미 방장·운영진이면 새삼 알리지 않는다', () {
    // 권한으로도 열리는 사람에게 매번 알리면 시끄럽기만 하다
    final body = bodyOf(members, 'Future<void> _setTitle(');
    expect(body.contains('!nowStaff'), isTrue);
    expect(body.contains("nowStaff = true"), isTrue,
        reason: '권한을 같이 준 경우도 «이미 열린 사람»으로 봐야 한다');
  });

  test('권한을 «내릴» 때 알리던 것은 그대로다 (짝을 지킨다)', () {
    final body = bodyOf(members, 'Future<void> _setRole(');
    expect(body.contains('Logic.keepsMoneyByTitle('), isTrue);
    expect(body.contains('직책도 같이 뗄까요?'), isTrue);
  });
}
