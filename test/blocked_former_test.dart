import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/moderation.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/board.dart';
import 'package:woorimoim/ui/calendar.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/fee_sheet_screen.dart';
import 'package:woorimoim/ui/home.dart';
import 'package:woorimoim/ui/members.dart';
import 'package:woorimoim/ui/post_screen.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 🚫 차단한 사람 · 나간 사람이 섞인 화면.

   애플 1.2 는 회원이 쓴 글이 있는 앱에 «차단»을 요구한다. 그런데 차단은 미묘하다:
     · 차단한 사람의 «옛 글»도 안 보여야 한다 (한 화면에만 숨기면 차단이 거짓말이 된다)
     · 나간 사람의 옛 글은 «이름»이 남아야 한다 — 안 그러면 「누가 쓴 글인지 모를 글」이 된다
     · 나간 사람이 낸 회비는 «통장에 그대로» 있어야 한다 — 돈을 지우면 안 된다
     · 차단했다고 그 사람이 낸 회비까지 사라지면 총무의 장부가 틀어진다 */
void main() {
  final st = AppState.i;

  Widget host(Widget child) => MaterialApp(
        theme: buildTheme('sky'),
        home: Scaffold(body: child),
      );

  /// 차단한 사람(u2)·나간 사람(u3)이 섞인 모임
  void seedMixed({bool blockU2 = true}) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple(Store.tidyCouple({
      'title': '앞산 배드민턴',
      'free': true,
      'fee': {'amount': 20000},
      'members': {
        'me': {
          'uid': 'me', 'name': '나', 'role': 'owner',
          if (blockU2) 'blocked': ['u2'],
        },
        'u2': {'uid': 'u2', 'name': '차단된사람', 'role': 'member'},
      },
      // u3 는 나갔다 — 이름만 남는다
      'former': {
        'u3': {'uid': 'u3', 'name': '나간사람', 'emoji': '🏸', 'leftAt': 1},
      },
    }));
    st.setItems(Store.tidy([
      {'id': 'm1', 'type': 'msg', 'by': 'u2', 'text': '차단된 사람의 말', 'createdAt': 1},
      {'id': 'm2', 'type': 'msg', 'by': 'u3', 'text': '나간 사람의 말', 'createdAt': 2},
      {'id': 'm3', 'type': 'msg', 'by': 'me', 'text': '내 말', 'createdAt': 3},
      {'id': 'd1', 'type': 'diary', 'by': 'u2', 'title': '차단된 사람의 글', 'text': '내용'},
      {'id': 'd2', 'type': 'diary', 'by': 'u3', 'title': '나간 사람의 글', 'text': '내용'},
      {'id': 'c1', 'type': 'reply', 'replyTo': 'd2', 'by': 'u2',
       'text': '차단된 사람의 댓글', 'createdAt': 4},
      {
        'id': 'l1', 'type': 'ledger', 'kind': 'in', 'payer': 'u3',
        'amount': 20000, 'date': '2026-08-05', 'title': '나간 사람 회비',
      },
      {
        'id': 'l2', 'type': 'ledger', 'kind': 'in', 'payer': 'u2',
        'amount': 20000, 'date': '2026-08-05', 'title': '차단된 사람 회비',
      },
    ]));
  }

  group('차단은 «모든 화면»에서 지켜진다 (애플 1.2)', () {
    testWidgets('대화방에서 차단한 사람의 말이 안 보인다', (t) async {
      seedMixed();
      await t.pumpWidget(host(const ChatTab(active: true)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.textContaining('차단된 사람의 말'), findsNothing,
          reason: '차단해 놓고 그 사람 말이 보이면 차단이 거짓말이 된다');
      expect(find.textContaining('내 말'), findsWidgets, reason: '내 말까지 사라졌다');
    });

    testWidgets('게시판에서 차단한 사람의 글이 안 보인다', (t) async {
      seedMixed();
      await t.pumpWidget(host(const BoardTab()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.textContaining('차단된 사람의 글'), findsNothing);
      expect(find.textContaining('나간 사람의 글'), findsWidgets,
          reason: '나간 사람의 글까지 숨기면 안 된다 — 차단과 탈퇴는 다르다');
    });

    testWidgets('글 안의 댓글에서도 차단이 지켜진다', (t) async {
      seedMixed();
      await t.pumpWidget(host(const PostScreen(postId: 'd2')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.textContaining('차단된 사람의 댓글'), findsNothing,
          reason: '댓글에만 차단이 안 닿으면 그 자리로 반려된다');
    });
  });

  group('돈은 «차단·탈퇴와 무관하게» 그대로 있다', () {
    test('나간 사람이 낸 회비가 통장에 남는다', () {
      seedMixed();
      final bal = Logic.balance();
      expect(bal, greaterThanOrEqualTo(40000),
          reason: '나가거나 차단했다고 낸 돈을 빼면 총무의 장부가 틀어진다 (지금 $bal원)');
    });

    testWidgets('회비 화면에 그 기록이 보인다', (t) async {
      seedMixed();
      await t.pumpWidget(host(const WalletTab()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('나간 사람의 이름은 «남는다»', () {
    test('옛 글의 글쓴이 이름을 찾을 수 있다', () {
      seedMixed();
      expect(st.nameOf('u3'), isNot(''),
          reason: '이름이 없으면 「누가 쓴 글인지 모를 글」이 된다');
      expect(st.nameOf('u3'), contains('나간'),
          reason: '탈퇴 기록(former)에 남긴 이름을 못 읽는다');
    });
  });

  group('섞인 채로 화면이 터지지 않는다', () {
    final screens = <String, Widget Function()>{
      '홈': () => const HomeTab(),
      '대화방': () => const ChatTab(active: true),
      '일정': () => const CalendarTab(),
      '회비': () => const WalletTab(),
      '게시판': () => const BoardTab(),
    };
    for (final e in screens.entries) {
      testWidgets(e.key, (t) async {
        seedMixed();
        await t.pumpWidget(host(e.value()));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '${e.key} 이 섞인 자료에서 터진다');
      });
    }

    testWidgets('회원 관리 — 나간 사람·차단한 사람이 섞여도 뜬다', (t) async {
      seedMixed();
      await t.pumpWidget(
          MaterialApp(theme: buildTheme('sky'), home: const MembersScreen()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('회비 표 — 나간 사람이 낸 돈이 있어도 뜬다', (t) async {
      seedMixed();
      await t.pumpWidget(
          MaterialApp(theme: buildTheme('sky'), home: const FeeSheetScreen()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('차단을 풀면 다시 보인다', () {
    testWidgets('풀고 나면 그 사람 말이 돌아온다', (t) async {
      seedMixed(blockU2: false);
      await t.pumpWidget(host(const ChatTab(active: true)));
      await t.pumpAndSettle();
      expect(find.textContaining('차단된 사람의 말'), findsWidgets,
          reason: '차단을 안 했는데도 안 보인다 — 풀 길이 없는 셈이다');
    });

    test('차단 목록이 비면 아무도 안 가려진다', () {
      seedMixed(blockU2: false);
      expect(Moderation.blocked(), isEmpty);
      expect(Moderation.isBlocked('u2'), isFalse);
    });
  });

  tearDown(() => st.setItems([]));
}
