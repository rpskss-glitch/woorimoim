// 회원 «전원에게 내려가는» 글은 길이를 막아 둔다 (95회차).
//
// 앱의 다른 칸은 모두 막혀 있었는데(모임 이름 14 · 제목 40 · 일정 30 …)
// 하필 대화와 게시판 글만 열려 있었다 — 이 둘이 회원 수만큼 곱해지는 값이다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 그 파일에서 «길이를 안 막은» 여러 줄 입력칸을 찾는다.
List<String> uncapped(String src, String name) {
  final bad = <String>[];
  final re = RegExp(r'TextField\(');
  for (final m in re.allMatches(src)) {
    // 그 TextField 하나의 괄호 안만 본다
    var d = 0;
    var end = m.end;
    for (var k = m.end - 1; k < src.length; k++) {
      if (src[k] == '(') d++;
      if (src[k] == ')') {
        d--;
        if (d == 0) {
          end = k;
          break;
        }
      }
    }
    final body = src.substring(m.start, end);
    if (!body.contains('maxLines')) continue; // 한 줄짜리는 화면이 알아서 막는다
    if (body.contains('maxLength')) continue;
    final line = String.fromCharCode(10).allMatches(src.substring(0, m.start)).length + 1;
    bad.add('$name:$line');
  }
  return bad;
}

void main() {
  test('회원 전원에게 내려가는 글은 모두 길이가 막혀 있다', () {
    final bad = <String>[];
    for (final f in Directory('lib/ui').listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      bad.addAll(uncapped(f.readAsStringSync(), f.path.split(RegExp(r'[\/]')).last));
    }
    expect(bad, isEmpty,
        reason: '막아 두지 않으면 붙여 넣은 긴 글이 «회원 수만큼» 곱해진다: ${bad.join(', ')}');
  });

  test('대화는 2000자, 게시판 글은 4000자', () {
    final chat = File('lib/ui/chat.dart').readAsStringSync();
    expect(chat.contains('maxLength: 2000'), isTrue);
    expect(chat.contains("counterText: ''"), isTrue, reason: '입력 줄이 좁다 — 숫자까지 보이면 답답하다');
    final board = File('lib/ui/board.dart').readAsStringSync();
    expect(board.contains('maxLength: 4000'), isTrue);
  });

  testWidgets('한도를 넘겨 붙여 넣으면 잘린다', (t) async {
    final c = TextEditingController();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          controller: c,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(counterText: ''),
        ),
      ),
    ));
    // 사람이 손으로 치는 대신 «붙여 넣기»처럼 한 번에 넣는다
    await t.enterText(find.byType(TextField), 'ㅋ' * 3000);
    await t.pump();
    expect(c.text.length, 2000, reason: '한도를 넘겨도 그대로 들어가면 막은 뜻이 없다');
  });

  testWidgets('한도 안쪽은 그대로 들어간다', (t) async {
    final c = TextEditingController();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: TextField(controller: c, maxLines: 4, maxLength: 2000)),
    ));
    await t.enterText(find.byType(TextField), '오늘 7시에 체육관에서 봬요');
    expect(c.text, '오늘 7시에 체육관에서 봬요');
  });

  test('막는 방식이 «글자 수»다 (바이트가 아니라)', () {
    // 한글은 1글자가 3바이트다 — 바이트로 막으면 한글이 3분의 1만 들어간다
    expect(LengthLimitingTextInputFormatter(5).formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(text: '가나다라마바사'),
    ).text, '가나다라마');
  });
}
