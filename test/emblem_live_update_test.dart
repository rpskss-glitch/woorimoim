import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/common.dart';
import 'package:woorimoim/ui/home.dart';

/* 🎨 모임 꾸미기를 바꾸면 홈 상징이 «바로» 바뀐다. (2026-09-26 에뮬)
   ⚽로 바꾸고 「모임 상징을 바꿨어요」까지 떴는데 홈은 여전히 🏸였다.
   Emblem 이 `const` 로 박혀 있어 부모가 다시 그려도 Flutter 가 «같은 것»으로 보고 건너뛰었다. */
void main() {
  testWidgets('꾸미기 값이 바뀌면 홈 상징이 따라 바뀐다', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    final st = AppState.i;
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'free': true,
      'emblem': {'kind': 'emoji', 'emoji': '🏸'},
      'members': {'me': {'uid': 'me', 'name': '나', 'role': 'owner'}},
    });
    st.setItems(Store.tidy(const []));
    await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: const Scaffold(body: HomeTab())));
    await t.pumpAndSettle();
    // 방장 안내서가 펼쳐져 있으면 상징이 화면 아래다 — 거기까지 내려간다
    await t.scrollUntilVisible(find.byType(Emblem), 300,
        scrollable: find.descendant(of: find.byType(HomeTab), matching: find.byType(Scrollable)).first);
    expect(find.text('🏸'), findsWidgets);
    expect(find.text('⚽'), findsNothing);

    st.setCouple({...?st.couple, 'emblem': {'kind': 'emoji', 'emoji': '⚽'}});
    await t.pumpAndSettle();
    expect(find.text('⚽'), findsWidgets, reason: '저장했는데 홈 상징이 그대로다');
  });
}
