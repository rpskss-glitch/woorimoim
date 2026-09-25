import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/shell.dart';

/* 🪟 대화 탭 «위에» 설정·회원 화면을 띄워 둔 동안 온 대화는 «읽은 것»이 아니다.

   2026-09-25 조사: 읽음 판정이 «탭 번호 + 앱이 앞에 있는가»만 봤다.
   대화 탭에서 ⚙️ 설정을 열어 둔 채 새 대화가 오면
     · 보낸 사람에게 「읽음 1」이 찍히고
     · 내 안읽음 배지가 사라지고
     · 알림도 «대화를 보는 중»이라며 삼켰다 — 돌아와도 온 줄 몰랐다.
   또 🔒 운영진 방으로 바꿔도 읽음을 안 찍어 배지가 남았다. */
void main() {
  final st = AppState.i;

  int? myRead() => ((st.couple?['lastRead'] as Map?)?[Demo.uid] as num?)?.toInt();

  Future<void> openChat(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start();
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: ShellScreen(onTouch: () {}),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('채팅'));
    await t.pumpAndSettle();
  }

  int sendFromOther(String text, {String room = ''}) {
    final at = DateTime.now().millisecondsSinceEpoch + 60000;
    Demo.addItem({
      'type': 'msg',
      'coupleId': Demo.code,
      'by': 'u_sh',
      'text': text,
      'createdAt': at,
      if (room.isNotEmpty) 'room': room,
    });
    return at;
  }

  tearDown(() {
    Demo.stop();
    st.chatCovered = false;
    st.setItems([]);
  });

  test('덮여 있으면 읽음이 아니다 (판정 자체)', () {
    expect(countsAsRead(true, AppLifecycleState.resumed, onTop: false), isFalse);
    expect(countsAsRead(true, AppLifecycleState.resumed, onTop: true), isTrue);
  });

  testWidgets('설정을 띄워 둔 동안 온 대화는 읽음으로 안 찍고, 닫고 돌아오면 찍는다', (t) async {
    await openChat(t);
    expect(st.chatOnScreen, isTrue, reason: '전제: 대화를 보고 있다');

    // 위쪽 ⚙️ 처럼 대화 위에 화면 하나를 띄운다
    t.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('설정 화면')))));
    await t.pumpAndSettle();
    expect(st.chatCovered, isTrue, reason: '덮였는데 모른다');
    expect(st.chatOnScreen, isFalse, reason: '덮였는데 «보는 중»이라 알림을 삼킨다');

    final before = myRead();
    final at = sendFromOther('설정 보는 동안 온 말');
    await t.pumpAndSettle();
    expect(myRead(), before, reason: '설정을 보는 동안 온 대화를 읽음으로 찍었다');

    // 닫고 돌아오면 그때 읽은 것이다
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await t.pumpAndSettle();
    expect(st.chatCovered, isFalse);
    expect(myRead(), at, reason: '돌아왔는데 읽음이 안 찍혀 배지가 남는다');
  });

  testWidgets('🔒 운영진 방으로 바꾸면 그 방 대화를 읽음으로 찍는다', (t) async {
    await openChat(t);
    // 대화 탭에 있는 동안 «운영진 방»에 새 말이 온다 — 지금은 모두의 방을 보고 있다
    final at = sendFromOther('운영진 회의 안건', room: 'staff');
    await t.pumpAndSettle();
    expect(myRead() ?? 0, lessThan(at), reason: '전제: 안 보는 방의 말은 아직 안 읽었다');

    await t.tap(find.textContaining('운영진'));
    await t.pumpAndSettle();
    expect(myRead(), at, reason: '운영진 방을 열었는데 읽음이 안 찍힌다');
  });

  test('알림은 «눈앞에 보이는지»로 삼킨다 (탭 번호만 보면 안 된다)', () {
    final src = File('lib/push.dart').readAsStringSync();
    expect(src.contains('AppState.i.chatOnScreen'), isTrue);
    expect(src.contains('if (AppState.i.currentTab == 1) return;'), isFalse,
        reason: '탭 번호만 보면 설정을 띄워 둔 동안 알림을 삼킨다');
  });
}
