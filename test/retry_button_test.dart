import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/main.dart';

/* 🔁 「다시 시도」 단추가 «눌린 티»를 내는가.

   2026-08-29 에뮬에서 눌러도 1초 뒤까지 글자가 그대로 「다시 시도」였다.
   회원 눈에는 «아무 일도 안 일어난» 것이라, 앱이 고장난 줄 알고 지운다.
   눌렀으면 즉시 「연결하는 중…」으로 바뀌고 다시 안 눌려야 한다. */
void main() {
  testWidgets('누르면 곧바로 «연결하는 중…»으로 바뀐다', (t) async {
    await t.pumpWidget(const NeedNetworkApp());
    await t.pumpAndSettle();

    expect(find.text('다시 시도'), findsOneWidget);
    await t.tap(find.text('다시 시도'));
    await t.pump(); // 한 프레임만 — 「눌리자마자」를 본다

    expect(find.text('연결하는 중…'), findsOneWidget,
        reason: '눌러도 글자가 그대로면 회원은 «안 눌렸다»고 읽는다');
    expect(find.text('다시 시도'), findsNothing);

    // 「눌린 티」를 보여 주려고 걸어 둔 기다림을 흘려보낸다 (안 그러면 시험이 «타이머가 남았다»고 한다)
    await t.pump(const Duration(seconds: 60)); // 붙기 한계(45초)까지 흘려보낸다
    await t.pumpAndSettle();
  });

  testWidgets('도는 중에는 두 번 안 눌린다', (t) async {
    await t.pumpWidget(const NeedNetworkApp());
    await t.pumpAndSettle();
    await t.tap(find.text('다시 시도'));
    await t.pump();
    final btn = t.widget<FilledButton>(find.byType(FilledButton));
    expect(btn.onPressed, isNull,
        reason: '도는 중에 또 눌리면 붙기를 여러 번 시도해 더 느려진다');
    await t.pump(const Duration(seconds: 60)); // 붙기 한계(45초)까지 흘려보낸다
    await t.pumpAndSettle();
  });

  test('MaterialApp 을 «만드는» 자리에서 그 아래 것을 찾지 않는다', () {
    /* 이번 버그의 뿌리다. `build(context)` 의 context 는 **그 위젯을 가리키는 자리**라,
       그 안에서 MaterialApp 을 만들면 `ScaffoldMessenger.of(context)` 는
       자기가 방금 만든 MaterialApp 을 못 본다 — 「없다」며 터진다.
       새 화면을 만들 때 똑같은 실수를 하기 쉬워 여기서 지킨다. */
    final src = File('lib/main.dart').readAsStringSync();
    final bad = <String>[];
    for (final m in RegExp(r'return MaterialApp\(').allMatches(src)) {
      final nxt = src.indexOf('\nclass ', m.end);
      final body = src.substring(m.end, nxt > 0 ? nxt : src.length);
      final uses = RegExp(r'(ScaffoldMessenger|Scaffold|Navigator)\.of\(context\)')
          .hasMatch(body);
      if (uses && !body.contains('Builder(')) {
        bad.add(src.substring(0, m.start).split('\n').length.toString());
      }
    }
    expect(bad, isEmpty,
        reason: 'MaterialApp 을 만드는 자리에서 .of(context) 를 쓴다 — '
            '누르는 순간 터져 «죽은 단추»가 된다 (줄 $bad). Builder 로 감싸라');
  });
}
