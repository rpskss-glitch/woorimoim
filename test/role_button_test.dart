import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/board.dart';
import 'package:woorimoim/ui/calendar.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/fee_sheet_screen.dart';
import 'package:woorimoim/ui/home.dart';
import 'package:woorimoim/ui/members.dart';
import 'package:woorimoim/ui/settings.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 🔑 「눌러도 안 되는 단추(헛단추)를 보여 주지 않는가」

   서버 규칙이 막는 일을 화면이 단추로 보여 주면, 회원은 누르고 → 거절당하고 →
   왜 안 되는지 모른 채 몇 번 더 누른다. 애플은 그런 자리를 «작동하지 않는 기능»으로
   보고 되돌려보낸다.

   이 앱에서 규칙이 갈라 놓은 것:
     · 돈(ledger) 쓰기 — 회장·총무만 (canHandleMoney)
     · 출석 체크 — 운영진만 (isStaffOf)
     · 회원 임명·탈퇴 처리 — 방장·운영진
     · 이용권 결제 — 방장만 (Fee.iPay)
     · 회비 표 열람 — 회장·총무만

   ⚠️ 평회원으로 화면을 그려 놓고 «그 단추가 있는가»를 본다. */
void main() {
  final st = AppState.i;

  Widget host(Widget child) => MaterialApp(
        theme: buildTheme('sky'),
        home: Scaffold(body: child),
      );

  /// 내 권한을 정해 모임을 세운다
  void seedAs(String role) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple(Store.tidyCouple({
      'title': '앞산 배드민턴',
      'free': true,
      'fee': {'amount': 20000, 'day': 5},
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': role},
        'boss': {'uid': 'boss', 'name': '방장', 'role': 'owner'},
        'u2': {'uid': 'u2', 'name': '남', 'role': 'member'},
      },
    }));
    st.setItems(Store.tidy([
      {
        'id': 'l1', 'type': 'ledger', 'kind': 'in', 'payer': 'u2',
        'amount': 20000, 'date': '2026-08-05',
      },
      {
        'id': 'e1', 'type': 'event', 'by': 'boss', 'title': '정기 모임',
        'date': '2026-09-02', 'time': '19:00',
      },
      {'id': 'd1', 'type': 'diary', 'by': 'boss', 'title': '공지', 'text': '내용'},
    ]));
  }

  /// 화면에 그 글자를 가진 «누를 수 있는 것»이 있는가
  bool hasTappable(WidgetTester t, String label) {
    final byText = find.textContaining(label);
    return byText.evaluate().isNotEmpty;
  }

  group('평회원에게는 총무 단추가 안 보인다', () {
    testWidgets('회비 — 「회비 받기」·「기록하기」가 없다', (t) async {
      seedAs('member');
      await t.pumpWidget(host(const WalletTab()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(hasTappable(t, '회비 받기'), isFalse,
          reason: '평회원이 눌러도 서버가 거절한다 — 헛단추다');
      expect(hasTappable(t, '기록하기'), isFalse,
          reason: '돈 기록은 회장·총무만 할 수 있다');
      expect(hasTappable(t, '여러 명 한 번에'), isFalse);
    });

    testWidgets('회비 — 「표로 보기」가 없다 (회장·총무만 열람)', (t) async {
      seedAs('member');
      await t.pumpWidget(host(const WalletTab()));
      await t.pumpAndSettle();
      expect(hasTappable(t, '표로 보기'), isFalse,
          reason: '회비 표는 회장·총무만 본다 — 눌러도 막힌다');
    });

    testWidgets('일정 — 「이름을 눌러 출석 체크」 안내가 없다', (t) async {
      seedAs('member');
      await t.pumpWidget(host(const CalendarTab()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(hasTappable(t, '이름을 눌러 출석'), isFalse,
          reason: '출석 체크는 운영진만 — 안내를 보여 주면 눌러 보고 실패한다');
    });
  });

  group('총무에게는 보인다', () {
    testWidgets('회비 — 「회비 받기」가 있다', (t) async {
      seedAs('admin');
      await t.pumpWidget(host(const WalletTab()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(hasTappable(t, '회비 받기') || hasTappable(t, '기록하기'), isTrue,
          reason: '총무인데 돈을 기록할 길이 없다');
    });

    testWidgets('회비 — 「표로 보기」가 있다', (t) async {
      seedAs('admin');
      await t.pumpWidget(host(const WalletTab()));
      await t.pumpAndSettle();
      expect(hasTappable(t, '표로 보기'), isTrue, reason: '총무인데 표를 못 본다');
    });
  });

  group('어느 권한으로도 화면이 터지지 않는다', () {
    final screens = <String, Widget Function()>{
      '홈': () => const HomeTab(),
      '대화방': () => const ChatTab(active: true),
      '일정': () => const CalendarTab(),
      '회비': () => const WalletTab(),
      '게시판': () => const BoardTab(),
    };
    for (final role in ['owner', 'admin', 'member']) {
      for (final e in screens.entries) {
        testWidgets('${e.key} · $role', (t) async {
          seedAs(role);
          await t.pumpWidget(host(e.value()));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: '${e.key} 이 $role 에게 터진다');
        });
      }

      testWidgets('설정 · $role', (t) async {
        seedAs(role);
        await t.pumpWidget(
            MaterialApp(theme: buildTheme('sky'), home: const SettingsScreen()));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });

      testWidgets('회원 관리 · $role', (t) async {
        seedAs(role);
        await t.pumpWidget(
            MaterialApp(theme: buildTheme('sky'), home: const MembersScreen()));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('회비 표 · 평회원이 억지로 열어도 안 터진다', (t) async {
      // 화면은 못 열게 막지만, 코드로 직접 열려도 터지면 안 된다
      seedAs('member');
      await t.pumpWidget(
          MaterialApp(theme: buildTheme('sky'), home: const FeeSheetScreen()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  tearDown(() => st.setItems([]));
}
