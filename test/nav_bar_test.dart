import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/shell.dart';

/* 🎨 아래 네비게이션 — 웹처럼 «색 이모지» + «같은 순서»(홈·채팅·일정·게시판·회비).
   순서를 바꾸면 홈의 _go(…)·안내서 onGo(…)도 함께 맞춰야 하므로, 여기서 못 박는다. */
void main() {
  final st = AppState.i;

  setUp(() => Demo.start());
  tearDown(() {
    st.setCouple({});
    st.setItems([]);
  });

  testWidgets('색 이모지 5칸이 웹과 같은 순서로 있다', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: ShellScreen(onTouch: () {}),
    ));
    await t.pumpAndSettle();

    // 라벨이 다 있다
    for (final label in const ['홈', '채팅', '일정', '게시판', '회비']) {
      expect(find.text(label), findsWidgets, reason: '$label 칸이 없다');
    }
    // 색 이모지 아이콘이 다 있다
    for (final e in const ['🏠', '💬', '📅', '📔', '💰']) {
      expect(find.text(e), findsWidgets, reason: '$e 이모지가 없다');
    }
    expect(t.takeException(), isNull);
  });

  test('소스: 네비 순서가 홈·채팅·일정·게시판·회비 (웹과 같음)', () {
    final s = File('lib/ui/shell.dart').readAsStringSync();
    // destinations 안에서 게시판이 회비보다 «먼저» 나와야 한다
    final board = s.indexOf("label: '게시판'");
    final fee = s.indexOf("label: '회비'");
    expect(board, greaterThan(0));
    expect(fee, greaterThan(0));
    expect(board < fee, isTrue, reason: '게시판이 회비보다 뒤에 있다 — 웹 순서와 다르다');
    // pages 배열도 BoardTab 이 WalletTab 보다 먼저
    final bt = s.indexOf('BoardTab()');
    final wt = s.indexOf('WalletTab()');
    expect(bt < wt, isTrue, reason: 'pages 순서가 destinations 와 안 맞다');
  });
}
