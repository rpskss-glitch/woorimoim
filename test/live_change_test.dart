import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
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

/* 🔄 「보고 있는 동안 자료가 바뀌면」

   이 앱은 서버를 실시간으로 듣는다. 그래서 화면을 보는 중에 밑바닥이 바뀐다:
     · 다른 총무가 회비를 기록한다
     · 누가 글을 지운다 — 내가 그 글을 «열어 놓고» 있다
     · 방장이 나를 탈퇴 처리한다 — 내 회원 기록이 사라진다
     · 모임 문서가 통째로 사라진다 (방이 지워졌다)

   그때 화면이 터지면 회원은 앱이 고장난 줄 안다. 빈 화면에 갇혀도 안 된다. */
void main() {
  final st = AppState.i;

  Widget host(Widget child) => MaterialApp(
        theme: buildTheme('sky'),
        home: Scaffold(body: child),
      );

  final tabs = <String, Widget Function()>{
    '홈': () => const HomeTab(),
    '대화방': () => const ChatTab(active: true),
    '일정': () => const CalendarTab(),
    '회비': () => const WalletTab(),
    '게시판': () => const BoardTab(),
  };

  group('보는 중에 기록이 사라진다', () {
    for (final e in tabs.entries) {
      testWidgets('${e.key} — 기록이 전부 사라져도 안 터진다', (t) async {
        Demo.start();
        await t.pumpWidget(host(e.value()));
        await t.pumpAndSettle();

        // 다른 사람이 전부 지웠다 (또는 연결이 끊겨 빈 목록이 왔다)
        st.setItems([]);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull,
            reason: '${e.key} 이 기록이 사라지는 순간 터진다');
      });
    }
  });

  group('보는 중에 모임 문서가 바뀐다', () {
    for (final e in tabs.entries) {
      testWidgets('${e.key} — 모임 문서가 사라져도 안 터진다', (t) async {
        Demo.start();
        await t.pumpWidget(host(e.value()));
        await t.pumpAndSettle();

        // 방이 지워졌다 — 서버가 null 을 보낸다
        st.setCouple(null);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull,
            reason: '${e.key} 이 모임 문서가 사라지는 순간 터진다');
      });

      testWidgets('${e.key} — 내가 탈퇴 처리돼도 안 터진다', (t) async {
        Demo.start();
        await t.pumpWidget(host(e.value()));
        await t.pumpAndSettle();

        // 방장이 나를 뺐다 — 회원 목록에서 내가 사라진다
        final c = Map<String, dynamic>.from(st.couple ?? {});
        final members = Map<String, dynamic>.from(c['members'] as Map? ?? {});
        members.remove(Demo.uid);
        c['members'] = members;
        st.setCouple(Store.tidyCouple(c));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull,
            reason: '${e.key} 이 내가 빠지는 순간 터진다');
      });
    }
  });

  group('열어 놓은 화면 밑이 빠질 때', () {
    testWidgets('보고 있던 글이 지워지면 «지워졌다»고 알려 준다', (t) async {
      Demo.start();
      // 글 하나를 만들고 그 글을 연다
      st.setItems(Store.tidy([
        ...st.items,
        {'id': 'p1', 'type': 'diary', 'by': Demo.uid, 'title': '글', 'text': '내용'},
      ]));
      await t.pumpWidget(host(const PostScreen(postId: 'p1')));
      await t.pumpAndSettle();
      expect(find.textContaining('내용'), findsWidgets);

      // 다른 사람이 그 글을 지웠다
      st.setItems(st.items.where((x) => x['id'] != 'p1').toList());
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '열어 놓은 글이 지워지는 순간 터진다');
      expect(find.textContaining('지워졌'), findsWidgets,
          reason: '빈 화면에 갇히면 나갈 길을 못 찾는다');
    });

    testWidgets('회비 표를 보는 중에 회원이 사라져도 안 터진다', (t) async {
      Demo.start();
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: const FeeSheetScreen(),
      ));
      await t.pumpAndSettle();

      st.setCouple(Store.tidyCouple({
        ...?st.couple,
        'members': <String, dynamic>{},
      }));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '회비 표에서 회원이 사라지면 터진다');
    });

    testWidgets('회원 관리를 보는 중에 모두 사라져도 안 터진다', (t) async {
      Demo.start();
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: const MembersScreen(),
      ));
      await t.pumpAndSettle();

      st.setCouple(Store.tidyCouple({
        ...?st.couple,
        'members': <String, dynamic>{},
        'pending': <String, dynamic>{},
      }));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '회원 관리에서 모두 사라지면 터진다');
    });
  });

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });
}
