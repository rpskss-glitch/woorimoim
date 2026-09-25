import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/billing.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/settings.dart';

/* 💳 돈을 내고 있는 모임이 «매달 잠기지» 않게.

   2026-09-25 조사:
   ① 스토어 소식(결제·자동 갱신)을 **결제 화면에서만** 들었다. 그 화면은 모임이 잠긴 뒤에야
      열려서, 아이폰이 매달 갱신한 영수증이 서버에 안 넘어가 **돈을 내는 모임도 매달 잠겼다.**
   ② 결제 화면이 뜨자마자 누르면 스토어 연결 전이라 멀쩡한 아이폰에서도
      「이 기기에서는 스토어 결제를 쓸 수 없어요」가 떴다.
   ③ 이용권 화면의 입구가 «잠김 막대» 하나뿐이라, 잠기기 전에는 만료일 확인·복원·해지 안내를 볼 길이 없었다. */

/// 주석을 걷어낸 코드만 본다.
String codeOf(String path) => File(path)
    .readAsStringSync()
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

String bodyOf(String src, String head) {
  final at = src.indexOf(head);
  expect(at, greaterThanOrEqualTo(0), reason: '$head 을 못 찾았다');
  var depth = 0;
  for (var i = src.indexOf('{', at + head.length); i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}' && --depth == 0) return src.substring(at, i + 1);
  }
  return src.substring(at);
}

Map<String, dynamic> club({String role = 'owner', bool free = false}) => {
      'title': '수요일 딩크반',
      if (free) 'free': true,
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': role},
      },
    };

void main() {
  group('① 누가 스토어 소식을 듣나', () {
    test('면제 아닌 모임의 방장은 듣는다', () {
      expect(Billing.shouldListen(club(), 'me'), isTrue);
    });
    test('회원·운영진은 안 듣는다 — 살 것이 없다', () {
      expect(Billing.shouldListen(club(role: 'member'), 'me'), isFalse);
      expect(Billing.shouldListen(club(role: 'admin'), 'me'), isFalse);
    });
    test('면제 모임(총괄이 만든 방)은 안 듣는다', () {
      expect(Billing.shouldListen(club(free: true), 'me'), isFalse);
    });
    test('모르면 안 듣는다 (모임 정보 전·로그인 전)', () {
      expect(Billing.shouldListen(null, 'me'), isFalse);
      expect(Billing.shouldListen(club(), ''), isFalse);
    });

    test('모임에 들어오면 곧바로 듣기 시작한다 — 결제 화면을 기다리지 않는다', () {
      final main = codeOf('lib/main.dart');
      expect(main, contains('Billing.shouldListen(c, Store.i.myUid)'));
      expect(main, contains('Billing.i.start()'));
      final start = main.indexOf('Billing.i.start()');
      final lite = main.indexOf('if (_onlyLive(before, c))');
      expect(start, lessThan(lite),
          reason: '«가벼운 갱신»으로 빠지는 스냅샷 뒤에 두면 영영 안 불릴 수 있다');
      final notMember = main.indexOf('if (!isMember) {');
      expect(start, greaterThan(notMember), reason: '회원 확인 전에 스토어를 붙인다');
    });
  });

  group('② 너무 빨리 눌러도 «쓸 수 없다»고 하지 않는다', () {
    final billing = codeOf('lib/billing.dart');
    for (final head in ['Future<void> buy()', 'Future<void> restore()']) {
      test('$head 는 연결을 기다린 뒤 판단한다', () {
        final body = bodyOf(billing, head);
        final wait = body.indexOf('await _ensureStarted()');
        final judge = body.indexOf('if (!available)');
        expect(wait, greaterThan(0), reason: '연결을 안 기다린다');
        expect(wait, lessThan(judge), reason: '판단한 «뒤에» 기다리면 소용없다');
      });
    }
  });

  group('③ 설정에서 이용권 화면에 들어갈 수 있다', () {
    final st = AppState.i;

    Future<void> open(WidgetTester t, Map<String, dynamic> c) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3.0;
      addTearDown(t.view.reset);
      st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
      st.setCouple(c);
      await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: const SettingsScreen()));
      await t.pumpAndSettle();
    }

    Future<bool> hasPassRow(WidgetTester t) async {
      final f = find.text('💳 모임 이용권');
      try {
        await t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
      } catch (_) {
        return false; // 끝까지 내려도 없다
      }
      return f.evaluate().isNotEmpty;
    }

    tearDown(() => st.setCouple({}));

    testWidgets('방장은 잠기기 «전에도» 이용권 줄이 보인다', (t) async {
      final soon = DateTime.now().add(const Duration(days: 20)).millisecondsSinceEpoch;
      await open(t, {...club(), 'paidUntil': soon});
      expect(await hasPassRow(t), isTrue, reason: '돈 내는 방장이 만료일·복원을 볼 길이 없다');
      expect(find.textContaining('까지'), findsWidgets, reason: '언제까지인지 안 보인다');
    });

    testWidgets('회원에게는 안 보인다', (t) async {
      await open(t, club(role: 'member'));
      expect(await hasPassRow(t), isFalse);
    });

    testWidgets('면제 모임에는 안 보인다', (t) async {
      await open(t, club(free: true));
      expect(await hasPassRow(t), isFalse);
    });
  });
}
