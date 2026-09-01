import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/home.dart';

/* 🔒 「운영진 방이 새지 않는가」

   방 하나를 나누는 일은 «화면 한 곳»만 고쳐서 끝나지 않는다.
   2026-08-30 운영진 방을 넣은 직후, 곧바로 네 군데가 새고 있었다:

     ① 사진 — 운영진 방에서 올린 사진에 방 표시가 안 붙어 모두의 방으로 갔다
     ② 투표 — 같은 까닭으로 회원 전체가 봤다
     ③ 안읽음 배지 — 평회원 폰에 «볼 수 없는 글»이 안읽음으로 잡혔다
        (배지에 3이 떠서 들어가 보면 아무것도 없다)
     ④ 알림 — 운영진끼리 나눈 말이 **회원 모두의 폰에 알림 글로 떴다.**
        서버 규칙이 읽기를 막아도, 알림은 내용을 그대로 실어 나른다.

   ④가 제일 나쁘다 — 규칙만 고치고 알림을 잊으면 «막았다고 믿는 채로» 다 새어 나간다. */
void main() {
  final st = AppState.i;

  Widget host(Widget child) =>
      MaterialApp(theme: buildTheme('sky'), home: Scaffold(body: child));

  void seed({required String role, List<Map<String, dynamic>>? items}) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'title': '앞산 배드민턴',
      'free': true,
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': role},
        'u2': {'uid': 'u2', 'name': '남', 'role': 'admin'},
      },
    });
    st.setItems(Store.tidy(items ?? const []));
  }

  tearDown(() => st.setItems([]));

  group('올릴 때 — 세 갈래 모두 방 표시를 붙인다', () {
    final chat = File('lib/ui/chat.dart').readAsStringSync();

    test('글·사진·투표가 «같은 자리»에서 방 표시를 받는다', () {
      /* 셋에 따로 적으면 하나를 빠뜨린다 — 실제로 사진·투표를 빠뜨렸다.
         한 곳(_roomTag)에서 만들어 세 곳이 그걸 쓴다. */
      expect(chat.contains('get _roomTag'), isTrue,
          reason: '방 표시를 한 자리에서 만들지 않는다 — 또 빠뜨린다');
      expect(RegExp(r'\.\.\._roomTag').allMatches(chat).length, 3,
          reason: '글·사진·투표 셋 다 붙여야 한다 (지금 붙은 곳이 셋이 아니다)');
    });

    test('사진 올리는 자리에 붙어 있다', () {
      final at = chat.indexOf("'kind': 'img'");
      expect(at, greaterThan(0));
      expect(chat.substring(at, at + 260).contains('_roomTag'), isTrue,
          reason: '운영진 방에서 올린 사진이 모두의 방으로 샌다');
    });

    test('투표 올리는 자리에 붙어 있다', () {
      final at = chat.indexOf("'kind': 'poll'");
      expect(at, greaterThan(0));
      expect(chat.substring(at, at + 260).contains('_roomTag'), isTrue,
          reason: '운영진 방에서 만든 투표가 모두의 방으로 샌다');
    });
  });

  group('셀 때 — 못 보는 글은 안 센다', () {
    final rows = [
      {'id': 'm1', 'type': 'msg', 'by': 'u2', 'text': '모두', 'createdAt': 10},
      {'id': 'm2', 'type': 'msg', 'by': 'u2', 'text': '운영진만',
       'room': 'staff', 'createdAt': 20},
    ];

    test('평회원 안읽음 셈이 운영진 방을 안 센다', () {
      /* 배지에 「2」가 뜨면 안 된다 — 평회원은 그중 하나를 «영영 볼 수 없다».
         들어가 봐야 아무것도 없어서, 회원은 앱이 고장 난 줄 안다.

         ⚠️ 화면에서 «숫자 글자»를 찾는 방식은 안 쓴다 — 배지가 안 뜨는 조건
            (지금 채팅 탭을 보고 있으면 숨긴다)에 걸려 헛짚는다.
            셈하는 규칙을 소스에서 직접 확인하는 편이 흔들리지 않는다. */
      final shell = File('lib/ui/shell.dart').readAsStringSync();
      final at = shell.indexOf('int get _unreadChat');
      expect(at, greaterThan(0));
      final body = shell.substring(at, at + 700);
      expect(body.contains("m['room']"), isTrue,
          reason: '평회원 배지가 못 보는 글까지 센다 — 들어가면 아무것도 없다');
      expect(body.contains('isAdmin'), isTrue,
          reason: '운영진에게는 세야 하는데 무조건 빼고 있다');
    });

    testWidgets('홈의 「대화 N개」도 안 센다', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3.0;
      addTearDown(t.view.reset);

      seed(role: 'member', items: [
        ...rows,
        {'id': 'd1', 'type': 'diary', 'by': 'u2', 'title': '글', 'text': '내용',
         'date': '2026-08-30', 'createdAt': 5},
      ]);
      await t.pumpWidget(host(const HomeTab()));
      await t.pumpAndSettle();

      expect(find.text('💬 대화 1개'), findsOneWidget,
          reason: '홈에 「대화 2개」라 해놓고 들어가면 1개면 사라진 줄 안다');
    });

    testWidgets('운영진에게는 둘 다 보인다', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3.0;
      addTearDown(t.view.reset);

      seed(role: 'admin', items: rows);
      await t.pumpWidget(host(const ChatTab(active: true)));
      await t.pumpAndSettle();

      expect(find.text('모두'), findsOneWidget);
      // 운영진 방으로 옮기면 그쪽 글이 보인다
      await t.tap(find.text('🔒 운영진'));
      await t.pumpAndSettle();
      expect(find.text('운영진만'), findsOneWidget);
      expect(find.text('모두'), findsNothing, reason: '두 방이 안 갈렸다');
    });
  });

  group('🔔 알림 — 가장 크게 새는 자리', () {
    test('서버가 운영진 방 알림을 «운영진에게만» 보낸다', () {
      final f = File('../앞산배드민턴/functions/index.js');
      if (!f.existsSync()) {
        markTestSkipped('서버 함수 파일을 못 찾았다 — 폴더 밖에 있다');
        return;
      }
      final code = f.readAsStringSync();
      final at = code.indexOf('exports.pushOnMsgApsan');
      expect(at, greaterThan(0));
      final next = code.indexOf('exports.', at + 10);
      final body = code.substring(at, next > 0 ? next : code.length);

      expect(body.contains('isStaffRoom'), isTrue,
          reason: '알림이 방을 모른다 — 운영진끼리 한 말이 회원 모두의 폰에 뜬다');
      /* 규칙이 읽기를 막아도 알림은 «내용»을 그대로 실어 나른다.
         그래서 대상을 고르는 자리에서 직접 빼야 한다. */
      expect(RegExp(r"isStaffRoom[\s\S]{0,200}continue").hasMatch(body), isTrue,
          reason: '평회원을 알림 대상에서 빼지 않는다');
      // 옛 대화(room 칸 없음)까지 막으면 알림이 통째로 끊긴다
      expect(body.contains("String(m.room || '') === 'staff'"), isTrue,
          reason: 'room 칸이 없는 옛 대화를 안 챙긴다');
    });
  });
}
