import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/ui/shell.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 🔠 오늘 새로 넣은 줄들이 좁은 폰·큰 글자에서 안 넘치는지 (2026-09-26)
   · 회비 현황 「나간 회원 — 밀린 회비」 줄: 긴 이름 + 「(나간 회원)」 + 회비 등록 단추 */
void main() {
  final st = AppState.i;
  final now = DateTime.now();
  int ms(int monthsAgo) => DateTime(now.year, now.month - monthsAgo, 5).millisecondsSinceEpoch;

  for (final scale in [1.3, 2.0]) {
    testWidgets('나간 회원 줄 · 360px · 글자 ${scale}배', (t) async {
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      st.profile = {'code': 'C', 'slot': 'u1', 'name': '김총무'};
      st.setCouple({
        'fee': {'amount': 20000},
        'members': {'u1': {'uid': 'u1', 'name': '김총무', 'role': 'owner', 'joinedAt': ms(12)}},
        'former': {
          'g': {'uid': 'g', 'name': '박나감(수요일 초보반 총무보조)', 'joinedAt': ms(6), 'leftAt': ms(2)},
        },
      });
      st.setItems(Store.tidy(const []));
      await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: const Scaffold(body: WalletTab())));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.textContaining('(나간 회원)'), 200);
      expect(t.takeException(), isNull, reason: '나간 회원 줄이 넘친다');
    });
  }
  for (final scale in [1.3, 2.0]) {
    testWidgets('유예 띠 · 360px · 글자 ${scale}배', (t) async {
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      Demo.stop();
      st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
      st.setCouple({
        'title': '시험 모임',
        'paidUntil': DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        'members': {'me': {'uid': 'me', 'name': '나', 'role': 'owner'}},
      });
      st.setItems([]);
      await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: ShellScreen(onTouch: () {})));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('모임이 잠겨요'), findsOneWidget);
      expect(t.takeException(), isNull, reason: '유예 띠가 넘친다');
    });
  }
}
