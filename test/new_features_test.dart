import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woorimoim/config.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/fee_sheet.dart';
import 'package:woorimoim/logic.dart';
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

    test('접었다 폈다 할 수 있다', () async {
      /* 「닫았다」는 표시는 이 기기의 저장소에 남는다 —
         시험틀에는 그 저장소가 없으니 «가짜 저장소»를 깔고 진짜처럼 확인한다.
         (안 깔면 setInt 가 조용히 무시돼 시험이 늘 실패한다) */
      SharedPreferences.setMockInitialValues({});
      await Store.i.loadPrefsForTest();
      seed(role: 'owner');
      OwnerGuideCard.reset();
      /* ⚠️ **접어도 카드는 남는다** — 제목 줄이 남아 있어야 다시 펼 수 있다.
         예전에는 «닫기»라 카드가 통째로 사라졌고, 설정에 「다시 보기」가 있는 줄
         모르는 방장은 영영 못 봤다(2026-08-30 사장님이 접기로 바꾸라고 하셨다). */
      OwnerGuideCard.unfold();
      expect(OwnerGuideCard.folded, isFalse);
      expect(OwnerGuideCard.shouldShow(), isTrue);

      OwnerGuideCard.fold();
      expect(OwnerGuideCard.folded, isTrue, reason: '접힌 것이 안 기억된다');
      expect(OwnerGuideCard.shouldShow(), isTrue,
          reason: '접었다고 카드가 통째로 사라지면 다시 펼 길이 없다');

      OwnerGuideCard.unfold();
      expect(OwnerGuideCard.folded, isFalse, reason: '다시 못 편다');
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
  group('⑦ 총괄 모드 — 이미 허락된 기기는 안 묻는다', () {
    test('기기 확인 → 곧장 콘솔, 처음이면 그때만 묻는다', () {
      final s = File('lib/ui/admin.dart').readAsStringSync();
      expect(s.contains('Future<bool> alreadyAdminDevice()'), isTrue,
          reason: '이미 허락된 기기인지 볼 길이 없다 — 들어갈 때마다 암호를 친다');
      final at = s.indexOf('Future<void> openAdminByTaps(');
      expect(at, greaterThan(0), reason: '다섯 번 두드리는 입구가 없다');
      final body = s.substring(at, at + 700);
      expect(body.contains('alreadyAdminDevice()'), isTrue);
      expect(body.indexOf('alreadyAdminDevice()'), lessThan(body.indexOf('askText')),
          reason: '기기를 확인하기 «전»에 먼저 묻는다 — 건너뛰기가 안 된다');
    });

    test('못 읽으면 «거짓»으로 본다 — 아무나 열리면 안 된다', () {
      final s = File('lib/ui/admin.dart').readAsStringSync();
      final at = s.indexOf('Future<bool> alreadyAdminDevice()');
      final body = s.substring(at, s.indexOf('Future<void> openAdminByTaps(', at));
      expect(RegExp(r'catch[\s\S]{0,80}return false').hasMatch(body), isTrue,
          reason: '연결이 끊겼을 때 참으로 보면 아무 기기나 총괄 콘솔이 열린다');
    });

    test('모임 «안»(홈)에서도 열린다', () {
      final s = File('lib/ui/home.dart').readAsStringSync();
      expect(s.contains('openAdminByTaps'), isTrue,
          reason: '모임에 들어와 있으면 설정까지 내려가야 한다');
      expect(s.contains('_emblemTaps < 5'), isTrue, reason: '다섯 번이 아니다');
    });

    test('암호를 물을 때 «무엇인지» 알려 주지 않는다', () {
      /* 숨은 입구인데 「이름」·「생년월일 8자리」라고 적으면
         어깨너머로 보는 사람에게 무엇을 알아내야 하는지 그대로 알려 주는 셈이다. */
      final s = File('lib/ui/admin.dart').readAsStringSync();
      expect(s.contains("hint: '첫 번째 암호'"), isTrue);
      expect(s.contains("hint: '두 번째 암호'"), isTrue);
      expect(s.contains("hint: '생년월일 8자리'"), isFalse,
          reason: '무엇을 넣는지 화면에 적혀 있다');
      // 치는 글자는 가린다 — 어깨너머로 보인다
      expect(RegExp(r'obscure: true').allMatches(s).length, greaterThanOrEqualTo(2),
          reason: '암호가 화면에 그대로 보인다');
    });
  });

  group('⑧ 투표 기간', () {
    Map<String, dynamic> poll({int? until, bool closed = false}) => {
          'kind': 'poll',
          'poll': {'q': '언제 만날까요', 'opts': ['토', '일'], 'closed': closed,
                   if (until != null) 'until': until},
        };

    test('기한이 지나면 «저절로» 닫힌다', () {
      const now = 1000000;
      expect(Logic.poll(poll(until: now + 1000), now: now).closed, isFalse);
      expect(Logic.poll(poll(until: now - 1), now: now).closed, isTrue,
          reason: '기한이 지났는데 아직 열려 있다 — 사람이 마감하기를 기다리면 몇 달씩 남는다');
    });

    test('기한이 없으면 손으로 마감할 때까지 열려 있다', () {
      expect(Logic.poll(poll()).closed, isFalse);
      expect(Logic.poll(poll()).until, isNull);
      expect(Logic.poll(poll(closed: true)).closed, isTrue);
    });

    test('남은 시간을 셀 수 있다 — 지났으면 없다', () {
      const now = 1000000;
      expect(Logic.pollLeftMs(poll(until: now + 5000), now: now), 5000);
      expect(Logic.pollLeftMs(poll(until: now - 1), now: now), isNull);
      expect(Logic.pollLeftMs(poll(), now: now), isNull);
    });

    test('🔴 다듬기를 지나도 기한이 «살아 있다»', () {
      /* 실기기에서 잡았다 — 「3시간」을 골라 올렸는데 남은 시간이 안 뜨고
         기한이 지나도 안 닫혔다. `Store.tidy` 가 투표를 «다시 만들면서»
         적지 않은 칸(until)을 통째로 버리고 있었다.
         ⚠️ 앱이 지나는 길과 똑같이 tidy 를 거쳐서 봐야 잡힌다. */
      final out = Store.tidy([
        {
          'id': 'p1', 'type': 'msg', 'kind': 'poll', 'by': 'me',
          'text': '언제 만날까요', 'createdAt': 1756400000000,
          'poll': {'q': '언제 만날까요', 'opts': ['토', '일'],
                   'closed': false, 'until': 1756500000000},
        }
      ]);
      expect((out.first['poll'] as Map)['until'], 1756500000000,
          reason: '다듬기가 기한을 버린다 — 고른 기한이 통째로 사라진다');
      expect(Logic.poll(out.first).until, 1756500000000);
    });

    test('망가진 기한 값에도 안 죽는다', () {
      expect(Logic.poll({'poll': {'until': '글자'}}).closed, isFalse);
      expect(Logic.pollLeftMs({'poll': {'until': null}}), isNull);
    });

    test('끝나면 «종료되었습니다»라고 말한다', () {
      final s = File('lib/ui/chat.dart').readAsStringSync();
      expect(s.contains('투표가 종료되었습니다'), isTrue,
          reason: '끝난 것을 안 알려 주면 회원이 계속 눌러 본다');
      expect(s.contains('남음'), isTrue, reason: '남은 시간을 안 알려 준다');
      // 기한이 되는 «그 순간» 스스로 다시 그려야 한다
      expect(s.contains('_armDueTick'), isTrue,
          reason: '아무도 안 눌러도 종료가 보여야 한다');
    });

    test('투표 «중»에도 누가 골랐는지 바로 보인다', () {
      final s = File('lib/ui/chat.dart').readAsStringSync();
      expect(s.contains('faces:'), isTrue,
          reason: '「누가 골랐나」를 눌러야만 알 수 있으면 판을 못 읽는다');
      // 큰 모임에서 얼굴이 화면을 덮지 않게 끊어야 한다
      expect(s.contains('faces.take(6)'), isTrue, reason: '얼굴 수를 안 끊는다');
    });
  });
}
