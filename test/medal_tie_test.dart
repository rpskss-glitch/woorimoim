import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/home.dart';

/* 🥇 같은 횟수면 같은 메달 — 공동 순위.

   2026-09-25 에뮬레이터 홈에서 직접 봤다: 셋 다 이번 달 1회인데 🥇🥈🥉로 갈렸다.
   메달을 «줄 차례»대로 붙였기 때문이다. 누가 금메달인지는 자료가 온 차례가 정했다. */
void main() {
  MapEntry<String, int> e(String k, int v) => MapEntry(k, v);

  test('순위는 같은 횟수끼리 같다', () {
    expect(Logic.ranks([e('a', 3), e('b', 3), e('c', 2)]), [1, 1, 3]);
    expect(Logic.ranks([e('a', 1), e('b', 1), e('c', 1)]), [1, 1, 1]);
    expect(Logic.ranks([e('a', 5), e('b', 4), e('c', 4), e('d', 1)]), [1, 2, 2, 4]);
    expect(Logic.ranks([]), isEmpty);
  });

  testWidgets('홈 카드 — 모두 1회면 모두 🥇', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start();
    addTearDown(() {
      Demo.stop();
      AppState.i.setItems([]);
    });
    final rank = Logic.monthRank();
    expect(rank.length, greaterThanOrEqualTo(2), reason: '전제: 둘러보기 모임에 이번 달 출석이 있다');
    final allSame = rank.every((x) => x.value == rank.first.value);

    await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: const Scaffold(body: HomeTab())));
    await t.pumpAndSettle();
    final card = find.text('✅ 이번 달 출석');
    await t.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();

    if (allSame) {
      expect(find.text('🥈'), findsNothing, reason: '횟수가 같은데 은메달이 붙었다');
      expect(find.text('🥇'), findsNWidgets(rank.length.clamp(0, 5)));
    }
  });
}
