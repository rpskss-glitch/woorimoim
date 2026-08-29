import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/admin.dart';
import 'package:woorimoim/ui/fee_sheet_screen.dart';
import 'package:woorimoim/ui/home.dart';
import 'package:woorimoim/ui/members.dart';
import 'package:woorimoim/ui/settings.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 두 번째 두드리기 — 회비·회원·설정·총괄·홈·회비표.

   앞 회차에서 게시판·대화창·댓글·일정을 두드려 셋을 잡았다. 같은 방식으로 나머지를 본다.
   ⚠️ 여기서는 «모임 문서»(couple)가 이상할 때도 본다 — members·fee·emblem 이
      백업 복원이나 웹앱 때문에 다른 모양일 수 있다. 그때 화면이 통째로 안 뜨면
      회원은 앱이 고장난 줄 안다. */
void main() {
  final st = AppState.i;

  Widget host(Widget child) => MaterialApp(
        theme: buildTheme('sky'),
        home: Scaffold(body: child),
      );

  List<Object?> weirdValues() => <Object?>[
        null, '', ' ', 0, -1, 3.14, true,
        <Object?>[], <String, Object?>{}, <Object?>['a'], <String, Object?>{'x': 1},
        'ㄱ' * 3000, '<script>',
      ];

  /// 실제 앱이 지나는 길과 똑같이 — 모임 문서도 기록도 다듬기를 거친다
  void seedCouple(Map<String, dynamic> couple, [List<Map<String, dynamic>>? items]) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple(Store.tidyCouple(couple));
    st.setItems(Store.tidy(items ?? []));
  }

  Map<String, dynamic> okCouple() => <String, dynamic>{
        'title': '앞산 배드민턴',
        'free': true,
        'fee': {'amount': 20000, 'day': 5},
        'members': {
          'me': {'uid': 'me', 'name': '나', 'role': 'owner'},
          'u2': {'uid': 'u2', 'name': '남', 'role': 'member'},
        },
      };

  Future<void> hammer(
    WidgetTester t,
    String label,
    Map<String, dynamic> Function(Object? w) make,
    Widget Function() screen, {
    List<Map<String, dynamic>> Function(Object? w)? items,
  }) async {
    for (final w in weirdValues()) {
      seedCouple(make(w), items?.call(w));
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(host(screen()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '$label 이 $w 일 때 터진다');
    }
  }

  group('모임 문서가 이상할 때', () {
    testWidgets('회비 칸', (t) async =>
        hammer(t, 'fee', (w) => {...okCouple(), 'fee': w}, () => const WalletTab()));

    testWidgets('회원 칸', (t) async => hammer(
        t, 'members', (w) => {...okCouple(), 'members': w},
        () => const MembersScreen()));

    testWidgets('회원 한 사람', (t) async => hammer(
        t,
        '회원 하나',
        (w) => {
              ...okCouple(),
              'members': {
                'me': {'uid': 'me', 'name': '나', 'role': 'owner'},
                'u2': w,
              },
            },
        () => const MembersScreen()));

    testWidgets('꾸미기·목표 칸', (t) async => hammer(
        t,
        '꾸미기',
        (w) => {...okCouple(), 'emblem': w, 'goal': w, 'budget': w, 'subs': w},
        () => const HomeTab()));

    testWidgets('설정 화면', (t) async => hammer(
        t,
        '설정',
        (w) => {...okCouple(), 'fee': w, 'emblem': w, 'theme': w, 'push': w},
        () => const SettingsScreen()));
  });

  group('회비 — 돈이 걸린 자리', () {
    testWidgets('장부 칸', (t) async => hammer(
        t,
        '장부',
        (w) => okCouple(),
        () => const WalletTab(),
        items: (w) => [
              {
                'id': 'l1', 'type': 'ledger', 'kind': 'in', 'payer': w,
                'amount': w, 'date': w, 'feeMonths': w, 'cat': w, 'title': w,
              },
              {'id': 'l2', 'type': 'ledger', 'kind': 'out', 'amount': w, 'cat': w},
            ]));

    test('돈 셈이 이상한 값에도 터지지 않는다', () {
      for (final w in weirdValues()) {
        seedCouple(okCouple(), [
          {
            'id': 'l1', 'type': 'ledger', 'kind': 'in', 'payer': 'me',
            'amount': w, 'date': w, 'feeMonths': w,
          },
        ]);
        expect(() => Logic.balance(), returnsNormally,
            reason: '통장 셈이 $w 일 때 터진다');
        expect(() => Logic.unpaidMonths('me'), returnsNormally,
            reason: '미납 셈이 $w 일 때 터진다');
        expect(() => Logic.prepaidLeft('me'), returnsNormally);
      }
    });

    testWidgets('회비 표', (t) async => hammer(
        t,
        '회비 표',
        (w) => {
              ...okCouple(),
              'members': {
                'me': {'uid': 'me', 'name': '나', 'role': 'owner', 'joinedAt': w},
              },
            },
        () => const FeeSheetScreen(),
        items: (w) => [
              {
                'id': 'l1', 'type': 'ledger', 'kind': 'in',
                'payer': 'me', 'amount': w, 'date': w,
              },
            ]));
  });

  group('총괄 콘솔', () {
    testWidgets('방 목록이 이상해도 뜬다', (t) async => hammer(
        t,
        '총괄',
        (w) => {...okCouple(), 'clubs': w, 'isMeta': w, 'adminUid': w},
        () => const AdminConsole()));
  });

  group('코드가 지켜야 하는 것', () {
    test('모임 문서도 «다듬기»를 거쳐서 온다', () {
      /* 기록(items)만 다듬고 모임 문서를 그냥 두면, members·fee 가 이상할 때
         화면이 통째로 안 뜬다 — 회원은 앱이 고장난 줄 안다. */
      final store = File('lib/store.dart').readAsStringSync();
      expect(store.contains('tidyCouple('), isTrue);
      final n = RegExp(r'tidyCouple\(').allMatches(store).length;
      expect(n, greaterThanOrEqualTo(3),
          reason: '모임 문서를 다듬지 않고 넘기는 길이 있다 (읽는 자리는 여럿이다)');
    });
  });

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });
}
