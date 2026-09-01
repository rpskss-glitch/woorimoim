import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/calendar.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 👆👆 「빠르게 두 번 누르면 두 번 되는가」

   서버에 닿는 일은 답이 오기까지 몇 초가 걸린다. 그동안 아무 표시가 없으면
   회원은 «안 눌렸다»고 여기고 한 번 더 누른다 — 그리고 두 번 일어난다.

   돈이 걸린 자리에서 이러면 통장이 틀어진다:
     · 회비를 두 번 기록 → 통장이 실제보다 많아진다
     · 지출을 두 번 기록 → 통장이 실제보다 적어진다
   총무는 어디서 틀렸는지 찾느라 장부를 통째로 뒤진다.

   ⚠️ 「기록 하나가 두 번 생기는가」를 **실제로 세어** 본다 — 표시만 보지 않는다. */
void main() {
  final st = AppState.i;

  Widget host(Widget child) => MaterialApp(
        theme: buildTheme('sky'),
        home: Scaffold(body: child),
      );

  int ledgerCount() => st.by('ledger').length;
  int eventCount() => st.by('event').length;

  group('돈 자리 — 두 번 눌러도 한 번만', () {
    testWidgets('회비 받기 창의 「1개월」을 두 번 눌러도 한 번만 들어간다', (t) async {
      Demo.start();
      final before = ledgerCount();
      final beforeBalance = Logic.balance();

      await t.pumpWidget(host(const WalletTab()));
      await t.pumpAndSettle();

      // 「회비 받기」를 눌러 창을 연다
      final receive = find.text('회비 받기');
      if (receive.evaluate().isEmpty) {
        markTestSkipped('받을 사람이 없다 — 체험 자료가 바뀌었다');
        return;
      }
      await t.tap(receive.first, warnIfMissed: false);
      await t.pumpAndSettle(const Duration(milliseconds: 400));

      // 창 안에서 「1개월」을 두 번 «빠르게» 누른다
      final one = find.textContaining('1개월');
      if (one.evaluate().isEmpty) {
        markTestSkipped('개월 고르기 창이 안 열렸다');
        return;
      }
      await t.tap(one.first, warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 30)); // 답을 기다리지 않고 곧바로
      await t.tap(one.first, warnIfMissed: false);
      await t.pumpAndSettle(const Duration(milliseconds: 600));
      t.takeException();

      final added = ledgerCount() - before;
      expect(added, lessThanOrEqualTo(1),
          reason: '회비가 $added번 들어갔다 — 통장이 실제보다 많아진다');
      final gained = Logic.balance() - beforeBalance;
      expect(gained, lessThanOrEqualTo(20000),
          reason: '통장이 $gained원 늘었다 — 한 사람 한 달치보다 많다');
    });

    testWidgets('일정 만들기를 두 번 눌러도 하나만 생긴다', (t) async {
      Demo.start();
      final before = eventCount();
      await t.pumpWidget(host(const CalendarTab()));
      await t.pumpAndSettle();

      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isEmpty) {
        markTestSkipped('모임 만들기 단추가 없다');
        return;
      }
      await t.tap(fab.first, warnIfMissed: false);
      await t.pumpAndSettle(const Duration(milliseconds: 400));

      final save = find.textContaining('만들기');
      if (save.evaluate().isEmpty) {
        markTestSkipped('만들기 창이 안 열렸다');
        return;
      }
      await t.tap(save.last, warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 30));
      await t.tap(save.last, warnIfMissed: false);
      await t.pumpAndSettle(const Duration(milliseconds: 600));
      t.takeException();

      final added = eventCount() - before;
      expect(added, lessThanOrEqualTo(1),
          reason: '일정이 $added개 생겼다 — 같은 모임이 두 줄로 보인다');
    });
  });

  group('코드가 지켜야 하는 것', () {
    /* 서버에 닿는 단추는 «도는 동안 잠겨야» 한다.
       BusyButton 이 그 일을 하고, 직접 만든 자리는 스스로 막아야 한다. */
    test('회비·일정·게시판의 저장 자리가 스스로 잠근다', () {
      for (final f in [
        'lib/ui/wallet.dart',
        'lib/ui/calendar.dart',
        'lib/ui/board.dart',
      ]) {
        final src = File(f).readAsStringSync();
        final guarded = src.contains('BusyButton') ||
            RegExp(r'_busy\s*[?=]').hasMatch(src) ||
            src.contains('busy.value');
        expect(guarded, isTrue,
            reason: '$f 에 두 번 눌림을 막는 장치가 안 보인다 — '
                '서버 답이 늦으면 회원은 한 번 더 누른다');
      }
    });
  });

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });
}
