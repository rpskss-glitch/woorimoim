import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/chat.dart';

/* ⏳ 「대화를 여는 순간」 — 첫 묶음이 오기 전에 «빈 첫 인사» 화면을 띄우면,
   대화가 뒤늦게 툭 나타나 바닥으로 튄다. 회원은 「자꾸 아래로 내려간다」고 느꼈다.
   이제 첫 스냅샷 전에는 «불러오는 중» 스피너를 보여, 한 번에 자리 잡는다.

   ⚠️ «불러오는 중»은 실제 대화 구독(_msgsSub)이 도는 중일 때만이다 — 시험은 구독 없이
      자료를 직접 넣으므로 로딩이 아니다(안 그러면 모든 빈-채팅 시험이 스피너로 깨진다). */
void main() {
  final st = AppState.i;

  Widget host() => MaterialApp(
      theme: buildTheme('sky'), home: const Scaffold(body: ChatTab(active: true)));

  test('구독이 없으면(시험처럼 자료를 직접 넣으면) 로딩이 아니다', () {
    Demo.stop();
    expect(Store.i.chatLoading, isFalse,
        reason: '구독도 없는데 로딩이라 하면 빈 채팅이 영영 스피너로 남는다');
  });

  test('체험 모드에서는 로딩을 안 띄운다 (자료가 바로 있다)', () {
    Demo.start();
    expect(Store.i.chatLoading, isFalse);
    Demo.stop();
  });

  testWidgets('구독 없는 빈 채팅은 스피너가 아니라 「첫 인사」를 보여준다', (t) async {
    Demo.stop();
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({'title': '모임', 'members': {'me': {'uid': 'me', 'name': '나'}}});
    st.setItems([]);
    await t.pumpWidget(host());
    await t.pump();
    expect(find.textContaining('불러오는 중'), findsNothing);
    st.setItems([]);
  });

  test('소스: 첫 묶음 전 로딩 스피너 갈래가 있고 chatLoading 을 본다', () {
    final chat = File('lib/ui/chat.dart').readAsStringSync();
    expect(chat.contains('Store.i.chatLoading'), isTrue,
        reason: '로딩 여부를 안 보고 늘 빈 화면을 띄운다');
    expect(chat.contains('대화를 불러오는 중'), isTrue,
        reason: '불러오는 중 표시가 없다');
    final store = File('lib/store.dart').readAsStringSync();
    // 로딩은 «구독이 도는 중 + 첫 묶음 아직»일 때만
    expect(store.contains('_msgsSub != null && !_msgsIn'), isTrue,
        reason: '로딩 조건이 구독 여부를 안 본다 — 시험·빈 채팅이 스피너로 굳는다');
  });
}
