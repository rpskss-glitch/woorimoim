import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/board.dart';
import 'package:woorimoim/ui/calendar.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/fee_screen.dart';
import 'package:woorimoim/ui/fee_sheet_screen.dart';
import 'package:woorimoim/ui/home.dart';
import 'package:woorimoim/ui/members.dart';
import 'package:woorimoim/ui/settings.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 👆 「화면의 단추를 **하나씩 눌러 본다**」

   2026-08-29 하루에 세 번, 시험 950개가 다 통과하는데도 살아 있던 버그가 나왔다.
   전부 **눌러 보지 않아서** 놓친 것들이다:
     · 설정에서 「월 회비」 저장 → 빨간 화면 (둥근 단추 이름 충돌 · 입력 그릇 조기 폐기)
     · 「다시 시도」 → 아무 일도 안 일어남 (context 를 잘못 잡아 그 자리에서 터짐)

   그래서 여기서는 **누른다.** 화면마다 눌러 보고, 터지는 자리가 있으면 잡는다.
   ⚠️ 한 번 누르면 화면이 바뀔 수 있으므로 **누를 때마다 화면을 새로 세운다.** */
void main() {
  setUp(() => Demo.start());
  tearDown(() => Demo.stop());

  /* 탭 화면들은 실제로 ShellScreen 의 Scaffold 안에서 돈다 —
     그 자리를 안 만들어 주면 「No Material widget found」로 화면이 아예 안 뜬다.
     ⚠️ Scaffold 를 «두 겹»으로 씌우면 안 되는 화면(스스로 Scaffold 를 세우는 것)도 있어
     그런 화면은 그대로 둔다. */
  Widget host(Widget child, {bool wrap = true}) => MaterialApp(
        theme: buildTheme('sky'),
        home: wrap ? Scaffold(body: child) : child,
      );

  /// 이 화면에서 «눌러 볼 만한 것»을 찾는다
  Finder tappables() => find.byWidgetPredicate((w) =>
      w is FilledButton ||
      w is ElevatedButton ||
      w is OutlinedButton ||
      w is TextButton ||
      w is IconButton ||
      w is FloatingActionButton ||
      w is PopupMenuButton ||
      // 설정·회비 자세히 같은 화면은 단추가 아니라 «줄»을 누른다
      (w is ListTile && w.onTap != null) ||
      (w is InkWell && w.onTap != null) ||
      w is SwitchListTile ||
      w is Switch);

  /// 화면 하나를 세우고, 눌러 볼 것들을 «하나씩» 눌러 본다.
  Future<void> tapEveryButton(WidgetTester t, Widget Function() screen,
      String label, {bool wrap = true, bool needButtons = true}) async {
    // 몇 개가 있는지 먼저 센다
    await t.pumpWidget(host(screen(), wrap: wrap));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: '$label 을 그리다 터진다');
    final n = tappables().evaluate().length;
    if (needButtons) {
      expect(n, greaterThan(0), reason: '$label 에 눌러 볼 것이 하나도 없다 — 화면이 안 떴다');
    }

    for (var i = 0; i < n; i++) {
      // ⚠️ 누를 때마다 새로 세운다 — 앞서 누른 것 때문에 자리가 바뀌면 엉뚱한 걸 누른다
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(host(screen(), wrap: wrap));
      await t.pumpAndSettle();
      final all = tappables();
      if (all.evaluate().length <= i) break; // 화면이 줄었으면 그만
      await t.tap(all.at(i), warnIfMissed: false);
      await t.pump(); // 한 프레임 — 누르자마자 터지는 것을 잡는다
      final e = t.takeException();
      expect(e, isNull, reason: '$label 의 ${i + 1}번째 단추를 누르니 터진다: $e');
      // 창이 열렸을 수 있으니 정리한다
      await t.pumpAndSettle(const Duration(milliseconds: 300));
      final e2 = t.takeException();
      expect(e2, isNull, reason: '$label 의 ${i + 1}번째 단추 — 창이 열리다 터진다: $e2');
    }
  }

  testWidgets('홈', (t) async => tapEveryButton(t, () => const HomeTab(), '홈'));

  testWidgets('회비', (t) async => tapEveryButton(t, () => const WalletTab(), '회비'));

  testWidgets('게시판', (t) async => tapEveryButton(t, () => const BoardTab(), '게시판'));

  testWidgets('일정', (t) async => tapEveryButton(t, () => const CalendarTab(), '일정'));

  testWidgets('대화방', (t) async => tapEveryButton(t, () => const ChatTab(active: true), '대화방'));

  testWidgets('설정', (t) async =>
      tapEveryButton(t, () => const SettingsScreen(), '설정'));

  testWidgets('회원 관리', (t) async =>
      tapEveryButton(t, () => const MembersScreen(), '회원 관리'));

  testWidgets('회비 표', (t) async =>
      tapEveryButton(t, () => const FeeSheetScreen(), '회비 표'));

  /* 체험 모드에서는 이용권을 살 일이 없어(무료로 친다) 살 단추가 없다 — 그게 맞다.
     여기서는 «그리다 터지지 않는지»만 본다. */
  testWidgets('회비 자세히', (t) async =>
      tapEveryButton(t, () => const FeeScreen(), '회비 자세히', needButtons: false));

  tearDownAll(() => AppState.i.setItems([]));
}
