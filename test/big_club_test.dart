import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/board.dart';
import 'package:woorimoim/ui/calendar.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/fee_sheet_screen.dart';
import 'package:woorimoim/ui/home.dart';
import 'package:woorimoim/ui/members.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 👥 「회원이 많은 큰 모임」 — 40명, 이름이 길고, 기록이 1200건.

   지금까지는 6명짜리 체험 모임으로만 봤다. 실제로 팔리면 40~50명 모임이 온다.
   그때 무엇이 무너지는가:
     · 이름이 길면 줄이 넘친다 (동호회에는 「김민수(수요일반)」 같은 이름이 흔하다)
     · 회원 줄이 40개면 한 화면에 안 들어간다 — 밀어서 끝까지 닿아야 한다
     · 셈이 느려지면 화면이 끊긴다 */
void main() {
  final st = AppState.i;

  Widget host(Widget child) => MaterialApp(
        theme: buildTheme('sky'),
        home: Scaffold(body: child),
      );

  /// 회원 40명 · 장부 1200건 · 이름이 긴 모임
  void seedBig({int people = 40, bool longNames = true}) {
    final members = <String, dynamic>{};
    for (var i = 0; i < people; i++) {
      members['u$i'] = {
        'uid': 'u$i',
        'name': longNames ? '김민수$i (수요일 초보반 · 총무보조)' : '회원$i',
        'role': i == 0 ? 'owner' : (i == 1 ? 'admin' : 'member'),
        'joinedAt': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'title': longNames ? '경기이사 겸 총무보조' : null,
      };
    }
    st.profile = {'code': 'C', 'slot': 'u0', 'name': '김민수0'};
    st.setCouple(Store.tidyCouple({
      'title': '앞산 배드민턴 수요일 저녁 초보반 모임',
      'free': true,
      'fee': {'amount': 20000, 'day': 5},
      'members': members,
    }));

    final items = <Map<String, dynamic>>[];
    var n = 0;
    for (var i = 0; i < people; i++) {
      for (var m = 0; m < 24; m++) {
        final y = 2024 + (m ~/ 12);
        final mm = (m % 12) + 1;
        items.add({
          'id': 'i${n++}', 'type': 'ledger', 'kind': 'in', 'payer': 'u$i',
          'amount': 20000, 'date': '$y-${mm.toString().padLeft(2, '0')}-05',
        });
      }
    }
    for (var i = 0; i < 40; i++) {
      items.add({
        'id': 'i${n++}', 'type': 'msg', 'by': 'u${i % people}',
        'text': '이번 주 모임 참석합니다 잘 부탁드립니다', 'createdAt': i,
      });
      items.add({
        'id': 'i${n++}', 'type': 'diary', 'by': 'u${i % people}',
        'title': '겨울 체육관 대관 안내드립니다 꼭 읽어주세요 $i',
        'text': '내용입니다', 'date': '2026-08-28',
      });
    }
    items.add({
      'id': 'ev1', 'type': 'event', 'by': 'u0',
      'title': '정기 모임 — 앞산 체육관 3코트 초보 레슨 먼저',
      'date': '2026-09-02', 'time': '19:00', 'place': '앞산 체육관 3코트',
    });
    st.setItems(Store.tidy(items));
  }

  final screens = <String, Widget Function()>{
    '홈': () => const HomeTab(),
    '대화방': () => const ChatTab(active: true),
    '일정': () => const CalendarTab(),
    '회비': () => const WalletTab(),
    '게시판': () => const BoardTab(),
  };

  group('40명 · 긴 이름 · 1200건', () {
    for (final e in screens.entries) {
      testWidgets('${e.key} 이 넘치지 않는다 (360px)', (t) async {
        t.view.physicalSize = const Size(360, 640);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);
        seedBig();
        await t.pumpWidget(host(e.value()));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '${e.key} 이 큰 모임에서 넘친다');
      });
    }

    testWidgets('회원 관리 — 40명이 다 나오고 넘치지 않는다', (t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      seedBig();
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: const MembersScreen(),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      // 밀어서 마지막 회원까지 닿는가 — 못 닿으면 그 사람은 관리할 수 없다
      await t.dragUntilVisible(
        find.textContaining('김민수39'),
        find.byType(Scrollable).first,
        const Offset(0, -300),
        maxIteration: 60,
      );
      expect(find.textContaining('김민수39'), findsWidgets,
          reason: '마지막 회원까지 못 닿으면 그 사람은 관리할 수 없다');
    });

    testWidgets('회비 표 — 40명이 다 나온다', (t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      seedBig();
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: const FeeSheetScreen(),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '회비 표가 큰 모임에서 넘친다');
    });
  });

  group('가장 가혹한 조합 — 40명 · 긴 이름 · 좁은 폰 · 글자 2배', () {
    /* 실제로 있을 수 있는 조합이다: 회원 40명인 동호회의 어르신 회원이
       값싼 폰(360px)에서 글자를 키워 쓴다. 여기서 넘치면 그 회원은 못 쓴다. */
    for (final e in screens.entries) {
      testWidgets('${e.key}', (t) async {
        t.view.physicalSize = const Size(360, 640);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);
        t.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        seedBig();
        await t.pumpWidget(host(e.value()));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull,
            reason: '${e.key} 이 40명·글자 2배에서 넘친다');
      });
    }

    testWidgets('회원 관리', (t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      t.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      seedBig();
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: const MembersScreen(),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '회원 관리가 40명·글자 2배에서 넘친다');
    });

    testWidgets('회비 표', (t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      t.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      seedBig();
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: const FeeSheetScreen(),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '회비 표가 40명·글자 2배에서 넘친다');
    });
  });

  group('큰 모임에서도 빠른가', () {
    test('회비 탭을 한 번 그리는 셈이 40명에서도 값싸다', () {
      seedBig();
      final sw = Stopwatch()..start();
      for (final m in st.memberList) {
        Logic.unpaidMonths(m['uid'] as String);
        Logic.prepaidLeft(m['uid'] as String);
      }
      sw.stop();
      // ignore: avoid_print
      print('▶ 40명 미납 셈: ${sw.elapsedMilliseconds}㎳');
      expect(sw.elapsedMilliseconds, lessThan(60),
          reason: '회비 탭은 IndexedStack 안에 살아 있어 대화 한 줄만 와도 이 값을 치른다');
    });

    test('출석·순위 셈도 값싸다', () {
      seedBig();
      final sw = Stopwatch()..start();
      Logic.attendStats();
      Logic.monthRank();
      Logic.nextEvent();
      sw.stop();
      // ignore: avoid_print
      print('▶ 40명 출석·순위: ${sw.elapsedMilliseconds}㎳');
      expect(sw.elapsedMilliseconds, lessThan(60), reason: '홈 화면이 끊긴다');
    });
  });

  tearDown(() => st.setItems([]));
}
