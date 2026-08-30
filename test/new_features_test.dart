import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woorimoim/config.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/fee_sheet.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/home.dart';
import 'package:woorimoim/ui/onboarding.dart';
import 'package:woorimoim/ui/owner_guide.dart';

/* 🆕 2026-08-30 에 새로 넣은 것들이 «실제로» 그렇게 도는가.

   기능을 넣을 때는 다 되는 것처럼 보인다. 문제는 그 다음 판에서
   누가 옆을 고치다 조용히 되돌려 놓는 것이라, 그때 알아채게 여기서 못 박는다. */
void main() {
  final st = AppState.i;

  Widget host(Widget child) =>
      MaterialApp(theme: buildTheme('sky'), home: Scaffold(body: child));

  void seed({String role = 'owner', List<Map<String, dynamic>>? items}) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'title': '앞산 배드민턴',
      'free': true,
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': role},
        'u2': {'uid': 'u2', 'name': '남', 'role': 'member'},
      },
    });
    st.setItems(Store.tidy(items ?? const []));
  }

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });

  group('① 「입력 중」을 안 보여 준다', () {
    test('화면에도, 서버에도 안 나간다', () {
      /* ⚠️ 주석은 걷어낸다 — 「이제 안 그린다」는 «설명»에도 그 말이 들어 있어
         그대로 찾으면 헛짚는다(내가 그렇게 짜서 걸렸다). */
      final code = File('lib/ui/chat.dart')
          .readAsStringSync()
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
          .replaceAll(RegExp(r'//.*'), '');
      expect(code.contains('님이 입력 중'), isFalse, reason: '아직 그리고 있다');
      // 자세한 것은 typing_expire_test 가 지킨다 (여기서는 «있다/없다»만)
    });
  });

  group('② 가입 화면에서 얼굴 사진을 고른다', () {
    testWidgets('아바타 «앞»에 사진 고르기 줄이 있다', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: OnboardingScreen(onJoined: () {}),
      ));
      await t.pumpAndSettle();

      expect(find.text('내 사진'), findsOneWidget, reason: '사진 고르는 자리가 없다');
      expect(find.text('앨범에서 고르기'), findsOneWidget);

      /* 차례가 중요하다 — 사진이 있으면 아바타를 안 골라도 된다.
         아바타가 먼저 오면 회원은 아바타를 고르고 사진 칸을 못 본다. */
      expect(t.getRect(find.text('내 사진')).top,
          lessThan(t.getRect(find.text('내 아바타')).top),
          reason: '사진 칸이 아바타보다 아래에 있다');
    });

    test('방이 정해진 «뒤»에 올린다 — 그 전엔 올릴 곳이 없다', () {
      final s = File('lib/ui/onboarding.dart').readAsStringSync();
      final enterAt = s.indexOf('Future<void> enter() async {');
      expect(enterAt, greaterThan(0));
      final body = s.substring(enterAt, enterAt + 300);
      expect(body.contains('saveProfile'), isTrue);
      expect(body.contains('_uploadFaceIfAny'), isTrue,
          reason: '들어간 뒤 사진을 올리지 않는다 — 고른 사진이 그냥 사라진다');
      expect(body.indexOf('saveProfile'), lessThan(body.indexOf('_uploadFaceIfAny')),
          reason: '방이 정해지기 «전»에 올리려 한다 — 어느 방 것인지 알 수 없다');
    });
  });

  group('③ 회비 표 기간 직접 고르기', () {
    test('시작~끝 달을 그대로 펼친다', () {
      expect(FeeSheet.monthRange('2026-03', '2026-06'),
          ['2026-03', '2026-04', '2026-05', '2026-06']);
      expect(FeeSheet.monthRange('2026-08', '2026-08'), ['2026-08']);
      // 해를 넘겨도 이어진다
      expect(FeeSheet.monthRange('2025-11', '2026-02').length, 4);
    });

    test('거꾸로 골라도 «빈 표»를 주지 않는다', () {
      /* 고른 사람은 실수했는지 모르고 「자료가 없다」고 오해한다 — 뒤집어서 보여 준다 */
      expect(FeeSheet.monthRange('2026-06', '2026-03'),
          ['2026-03', '2026-04', '2026-05', '2026-06']);
    });

    test('너무 넓게 골라도 표가 안 터진다', () {
      final n = FeeSheet.monthRange('1990-01', '2026-12').length;
      expect(n, lessThanOrEqualTo(120), reason: '수백 칸이면 화면이 멈칫한다');
    });

    test('망가진 값이 와도 죽지 않는다', () {
      expect(FeeSheet.monthRange('이상한값', '2026-06'), isNotEmpty);
      expect(FeeSheet.monthRange('', ''), isNotEmpty);
    });
  });

  group('④ 직책 — 직접 입력 · 회장·총무는 자동 운영진', () {
    test('회장·총무만 «묻지 않고» 운영진이 된다', () {
      expect(autoStaffTitles, containsAll(['회장', '총무']));
      /* ⚠️ 함부로 늘리면 안 된다 — 여기 든 직책은 회원 승인·모임 설정을 연다.
         부회장·이사들은 «물어보는» 쪽에 남아 있어야 한다. */
      expect(autoStaffTitles.length, 2,
          reason: '자동으로 권한이 붙는 직책이 늘었다 — 정말 그래도 되는지 확인해라');
      for (final t in ['부회장', '경기이사', '재무이사', '섭외이사']) {
        expect(autoStaffTitles.contains(t), isFalse, reason: '$t 은 물어봐야 한다');
        expect(adminTitles.contains(t), isTrue, reason: '$t 이 물어보는 목록에서도 빠졌다');
      }
    });

    test('직접 입력하는 길이 있다', () {
      final s = File('lib/ui/members.dart').readAsStringSync();
      expect(s.contains('직접 입력'), isTrue,
          reason: '목록에 없는 직책을 못 적는다 — 모임마다 부르는 이름이 다르다');
    });

    test('자동으로 줄 때 «말해 준다»', () {
      /* 방장이 모르는 사이에 권한이 넘어가면 안 된다 */
      final s = File('lib/ui/members.dart').readAsStringSync();
      expect(s.contains('운영진 권한도 함께 드렸어요'), isTrue,
          reason: '권한을 자동으로 주면서 아무 말도 안 한다');
    });
  });

  group('⑤ 운영진 전용 대화방', () {
    testWidgets('평회원에게는 방 바꾸기가 «안 보인다»', (t) async {
      seed(role: 'member');
      await t.pumpWidget(host(const ChatTab(active: true)));
      await t.pumpAndSettle();
      expect(find.text('🔒 운영진'), findsNothing,
          reason: '평회원에게 보이면 «눌러도 안 되는 문»이 되어 오히려 궁금해진다');
    });

    testWidgets('운영진에게는 보인다', (t) async {
      seed(role: 'admin');
      await t.pumpWidget(host(const ChatTab(active: true)));
      await t.pumpAndSettle();
      expect(find.text('🔒 운영진'), findsOneWidget);
      expect(find.text('모두의 방'), findsOneWidget);
    });

    testWidgets('모두의 방에서는 운영진 대화가 «안 보인다»', (t) async {
      seed(role: 'admin', items: [
        {'id': 'm1', 'type': 'msg', 'by': 'u2', 'text': '모두 볼 말', 'createdAt': 10},
        {'id': 'm2', 'type': 'msg', 'by': 'u2', 'text': '운영진만 볼 말',
         'room': 'staff', 'createdAt': 20},
      ]);
      await t.pumpWidget(host(const ChatTab(active: true)));
      await t.pumpAndSettle();

      expect(find.text('모두 볼 말'), findsOneWidget);
      expect(find.text('운영진만 볼 말'), findsNothing,
          reason: '운영진 방 대화가 모두의 방에 섞여 나온다');
    });

    test('서버 규칙이 «직접» 막는다 — 앱만 가리면 소용없다', () {
      /* 앱을 뜯으면 자료가 그대로 읽힌다. 운영진끼리 회원 이야기를 하는 자리라
         그 방이 새면 모임이 깨진다. */
      final f = File('../데이트장부/firestore.rules');
      if (!f.existsSync()) {
        markTestSkipped('규칙 파일을 못 찾았다 — 폴더 밖에 있다');
        return;
      }
      final r = f.readAsStringSync();
      expect(r.contains('staffRoomOk'), isTrue,
          reason: '서버가 운영진 방을 안 막는다 — 앱에서만 가리는 것은 «비밀»이 아니다');
      // 칸이 없는 옛 대화까지 막아 버리면 모두의 방이 통째로 안 보인다
      expect(r.contains("resource.data.get('room', '')"), isTrue,
          reason: 'room 칸이 없는 옛 대화를 안 챙긴다');
    });
  });

  group('⑥ 방장 안내서', () {
    testWidgets('방장에게만 뜬다', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3.0;
      addTearDown(t.view.reset);

      seed(role: 'owner');
      OwnerGuideCard.reset();
      await t.pumpWidget(host(const HomeTab()));
      await t.pumpAndSettle();
      expect(find.textContaining('방장이 되셨어요'), findsOneWidget);

      seed(role: 'member');
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(host(const HomeTab()));
      await t.pumpAndSettle();
      expect(find.textContaining('방장이 되셨어요'), findsNothing,
          reason: '회원에게는 «할 수도 없는 일 목록»이라 성가심일 뿐이다');
    });

    test('닫을 수 있고, 닫으면 다시 안 뜬다', () async {
      /* 「닫았다」는 표시는 이 기기의 저장소에 남는다 —
         시험틀에는 그 저장소가 없으니 «가짜 저장소»를 깔고 진짜처럼 확인한다.
         (안 깔면 setInt 가 조용히 무시돼 시험이 늘 실패한다) */
      SharedPreferences.setMockInitialValues({});
      await Store.i.loadPrefsForTest();
      seed(role: 'owner');
      OwnerGuideCard.reset();
      expect(OwnerGuideCard.shouldShow(), isTrue);
      OwnerGuideCard.dismiss();
      expect(OwnerGuideCard.shouldShow(), isFalse,
          reason: '닫아도 계속 뜨면 «치울 수 없는 광고»가 된다');
      // 다시 볼 길이 있어야 한다 — 없으면 닫기가 곧 삭제가 된다
      OwnerGuideCard.reset();
      expect(OwnerGuideCard.shouldShow(), isTrue);
    });

    test('설정에 «다시 보기»가 있다', () {
      final s = File('lib/ui/settings.dart').readAsStringSync();
      expect(s.contains('방장 안내서 다시 보기'), isTrue,
          reason: '한 번 닫으면 영영 못 본다');
    });

    test('회원 눈에 «별표»가 새지 않는다', () {
      /* 🔴 실기기에서 잡았다 — 설명을 굵게 쓰려고 마크다운(**…**)을 적었더니
         화면에 별표가 그대로 찍혔다. Flutter 의 Text 는 마크다운을 안 읽는다.
         「**모임 이름**만 알려주시면」이 「\*\*모임 이름\*\*만」으로 보였다.
         ⚠️ 주석은 봐준다 — 그건 사람이 읽는 설명이라 별표에 뜻이 있다. */
      final code = File('lib/ui/owner_guide.dart')
          .readAsStringSync()
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
          .replaceAll(RegExp(r'//.*'), '');
      expect(code.contains('**'), isFalse,
          reason: '회원 화면에 별표가 그대로 찍힌다 — 굵게 안 되고 지저분해진다');
    });

    test('안내서가 실제 할 일을 «빠짐없이» 짚는다', () {
      final s = File('lib/ui/owner_guide.dart').readAsStringSync();
      for (final must in ['회원을 부르세요', '승인', '직책', '회비', '일정', '이용권']) {
        expect(s.contains(must), isTrue, reason: '「$must」 안내가 빠졌다');
      }
      // 초대 코드를 함부로 뿌리면 방장 자리가 넘어간다 — 그 경고가 있어야 한다
      expect(s.contains('방장을 넘길 때'), isTrue,
          reason: '초대 코드를 아무에게나 보내면 안 된다는 말이 없다');
    });
  });
}
