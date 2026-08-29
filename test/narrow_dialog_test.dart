import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/board.dart';
import 'package:woorimoim/ui/calendar.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/members.dart';
import 'package:woorimoim/ui/settings.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 📐 창(대화상자)을 «좁은 폰 + 큰 글자»로 열어 본다.

   화면 본체는 앞 회차에서 봤다. 창은 따로 봐야 한다 —
   창은 화면보다 좁고(양옆 여백), 단추가 가로로 늘어서서 더 잘 넘친다.
   그리고 넘친 자리의 「저장」을 못 누르면 회원은 **아무것도 못 한다.**

   ⚠️ 글자 크기는 폰 설정 수준(platformDispatcher)으로 키워야 창까지 닿는다. */
void main() {
  final st = AppState.i;

  void small(WidgetTester t, double scale) {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }

  /// 화면을 세우고, 눌러 볼 것을 하나씩 눌러 창을 열어 본다
  Future<void> openEach(WidgetTester t, Widget Function() screen, String label,
      {bool wrap = true}) async {
    Widget host() => MaterialApp(
          theme: buildTheme('sky'),
          home: wrap ? Scaffold(body: screen()) : screen(),
        );

    Finder taps() => find.byWidgetPredicate((w) =>
        w is FilledButton ||
        w is ElevatedButton ||
        w is OutlinedButton ||
        w is TextButton ||
        w is IconButton ||
        w is FloatingActionButton ||
        (w is ListTile && w.onTap != null));

    await t.pumpWidget(host());
    await t.pumpAndSettle();
    final n = taps().evaluate().length;

    for (var i = 0; i < n; i++) {
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(host());
      await t.pumpAndSettle();
      final all = taps();
      if (all.evaluate().length <= i) break;
      await t.tap(all.at(i), warnIfMissed: false);
      await t.pumpAndSettle(const Duration(milliseconds: 400));
      final e = t.takeException();
      expect(e, isNull,
          reason: '$label 의 ${i + 1}번째를 눌러 연 창이 좁은 폰·큰 글자에서 넘친다: $e');
    }
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('회비 — 창 열기 · 글자 ${scale}배', (t) async {
      small(t, scale);
      Demo.start();
      await openEach(t, () => const WalletTab(), '회비');
    });

    testWidgets('일정 — 창 열기 · 글자 ${scale}배', (t) async {
      small(t, scale);
      Demo.start();
      await openEach(t, () => const CalendarTab(), '일정');
    });

    testWidgets('게시판 — 창 열기 · 글자 ${scale}배', (t) async {
      small(t, scale);
      Demo.start();
      await openEach(t, () => const BoardTab(), '게시판');
    });

    testWidgets('대화방 — 창 열기 · 글자 ${scale}배', (t) async {
      small(t, scale);
      Demo.start();
      await openEach(t, () => const ChatTab(active: true), '대화방');
    });

    testWidgets('설정 — 창 열기 · 글자 ${scale}배', (t) async {
      small(t, scale);
      Demo.start();
      await openEach(t, () => const SettingsScreen(), '설정', wrap: false);
    });

    testWidgets('회원 관리 — 창 열기 · 글자 ${scale}배', (t) async {
      small(t, scale);
      Demo.start();
      await openEach(t, () => const MembersScreen(), '회원 관리', wrap: false);
    });
  }

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });
}
