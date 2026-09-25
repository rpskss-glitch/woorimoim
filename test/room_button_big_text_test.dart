import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/shell.dart';

/* 🔒 방 단추에 숫자가 붙어도(「🔒 운영진 12」) 좁은 폰·큰 글자에서 넘치지 않는다. (2026-09-26)
   중장년 회원은 폰 글자를 키워 쓴다 — 넘치면 노란 줄무늬가 뜨고 단추 일부를 못 누른다. */
void main() {
  tearDown(() {
    Demo.stop();
    AppState.i.setItems([]);
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('360px · 글자 ${scale}배 · 운영진 방 12개 안 읽음', (t) async {
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      Demo.start();
      await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: ShellScreen(onTouch: () {})));
      await t.pumpAndSettle();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < 12; i++) {
        Demo.addItem({'type': 'msg', 'coupleId': Demo.code, 'by': 'u_sh', 'text': 's$i', 'room': 'staff', 'createdAt': now + 60000 + i});
      }
      AppState.i.openTab.value = 1;
      await t.pumpAndSettle();
      expect(find.text('🔒 운영진 12'), findsOneWidget);
      expect(t.takeException(), isNull, reason: '방 단추가 넘친다');
    });
  }
}
