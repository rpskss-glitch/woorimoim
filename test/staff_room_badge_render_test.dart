import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/shell.dart';

/* 🔒 운영진 방 단추의 숫자를 «실제로 그려» 본다 — 체험 자료에는 남이 쓴 운영진 방 말이 없어 에뮬레이터로는 못 본다.
   모두의 방을 보고 있는데 운영진 방에 남이 말하면 → 「🔒 운영진 1」,
   그다음 모두의 방에 새 말이 와서 읽어도 → 운영진 방 숫자는 그대로(예전에는 같이 읽음이 됐다). */
void main() {
  tearDown(() {
    Demo.stop();
    AppState.i.setItems([]);
  });

  testWidgets('운영진 방 새 말 → 단추 숫자, 모두의 방을 읽어도 안 사라진다', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start();
    await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: ShellScreen(onTouch: () {})));
    await t.pumpAndSettle();
    await t.tap(find.text('채팅'));
    await t.pumpAndSettle();

    final now = DateTime.now().millisecondsSinceEpoch;
    Demo.addItem({'type': 'msg', 'coupleId': Demo.code, 'by': 'u_sh', 'text': '운영진끼리', 'room': 'staff', 'createdAt': now + 60000});
    await t.pumpAndSettle();
    expect(find.text('🔒 운영진 1'), findsOneWidget);

    Demo.addItem({'type': 'msg', 'coupleId': Demo.code, 'by': 'u_sh', 'text': '모두에게', 'createdAt': now + 120000});
    await t.pumpAndSettle();
    expect(find.text('🔒 운영진 1'), findsOneWidget, reason: '모두의 방을 읽었다고 운영진 방 말까지 읽음이 되면 안 된다');

    await t.tap(find.text('🔒 운영진 1'));
    await t.pumpAndSettle();
    expect(find.text('🔒 운영진'), findsOneWidget, reason: '운영진 방을 열면 숫자가 사라진다');
  });
}
