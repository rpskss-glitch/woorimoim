import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/admin.dart';
import 'package:woorimoim/ui/onboarding.dart';
import 'package:woorimoim/ui/wait.dart';
import 'package:woorimoim/ui/board.dart';
import 'package:woorimoim/ui/calendar.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/fee_screen.dart';
import 'package:woorimoim/ui/fee_sheet_screen.dart';
import 'package:woorimoim/ui/home.dart';
import 'package:woorimoim/ui/members.dart';
import 'package:woorimoim/ui/settings.dart';
import 'package:woorimoim/ui/shell.dart';
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

  /* 🪟 「창을 열었다 **닫아 본다**」

     2026-08-29 아침에 잡은 크래시 둘은 모두 «창을 닫는 순간» 터졌다 —
     둥근 단추 이름이 겹치거나, 입력 그릇을 창이 닫히기 전에 버려서.
     그러니 «여는 것»만으로는 부족하다. 열고 닫는 데까지 해봐야 그 자리가 잡힌다. */
  Future<void> openAndClose(WidgetTester t, Widget Function() screen,
      String label) async {
    await t.pumpWidget(host(screen()));
    await t.pumpAndSettle();
    final n = tappables().evaluate().length;
    for (var i = 0; i < n; i++) {
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(host(screen()));
      await t.pumpAndSettle();
      final all = tappables();
      if (all.evaluate().length <= i) break;
      await t.tap(all.at(i), warnIfMissed: false);
      await t.pumpAndSettle(const Duration(milliseconds: 300));
      t.takeException(); // 여는 중의 탈은 앞 시험이 잡는다
      // 창이 열렸으면 닫아 본다 — 닫는 순간 터지는 자리를 찾는다
      final closers = find.byWidgetPredicate((w) =>
          (w is TextButton) || (w is FilledButton) || (w is IconButton));
      if (closers.evaluate().isNotEmpty) {
        await t.tap(closers.last, warnIfMissed: false);
        await t.pumpAndSettle(const Duration(milliseconds: 400));
        final e = t.takeException();
        expect(e, isNull,
            reason: '$label 의 ${i + 1}번째 에서 열린 창을 닫으니 터진다: $e');
      }
      // 닫은 뒤 몇 프레임 더 — «닫히는 동안» 터지는 것까지 본다
      await t.pump(const Duration(milliseconds: 500));
      final e2 = t.takeException();
      expect(e2, isNull,
          reason: '$label 의 ${i + 1}번째 — 창이 닫히는 동안 터진다: $e2');
    }
  }

  testWidgets('설정 — 창을 열고 닫기', (t) async =>
      openAndClose(t, () => const SettingsScreen(), '설정'));

  testWidgets('회비 — 창을 열고 닫기', (t) async =>
      openAndClose(t, () => const WalletTab(), '회비'));

  testWidgets('일정 — 창을 열고 닫기', (t) async =>
      openAndClose(t, () => const CalendarTab(), '일정'));

  testWidgets('게시판 — 창을 열고 닫기', (t) async =>
      openAndClose(t, () => const BoardTab(), '게시판'));

  /* 🏠 진짜 앱의 모양으로 — **탭 다섯이 한꺼번에 살아 있는** 화면.

     ⚠️ 화면을 하나만 띄우면 둥근 단추가 하나뿐이라 «같은 이름» 부딪힘을 못 잡는다.
        2026-08-29 아침의 크래시가 바로 그것이었다 — IndexedStack 으로 다섯이 동시에 살아
        회비·게시판·일정의 둥근 단추가 한 화면에 함께 있었고, 화면을 옮기는 순간 터졌다.
        그래서 여기서는 **진짜 꺼풀을 그대로** 세우고 탭을 옮겨 본다. */
  testWidgets('탭을 옮겼다 돌아와도 안 터진다', (t) async {
    await t.pumpWidget(host(ShellScreen(onTouch: () {}), wrap: false));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: '꺼풀을 그리다 터진다');

    // 다섯 탭을 차례로 누른다 — 옮기는 순간이 위험하다
    for (var round = 0; round < 2; round++) {
      for (var i = 0; i < 5; i++) {
        final dest = find.byType(NavigationDestination);
        if (dest.evaluate().length <= i) break;
        await t.tap(dest.at(i), warnIfMissed: false);
        await t.pumpAndSettle(const Duration(milliseconds: 400));
        final e = t.takeException();
        expect(e, isNull, reason: '${i + 1}번째 탭으로 옮기니 터진다: $e');
      }
    }
  });

  testWidgets('꺼풀 안에서 둥근 단추를 눌러도 안 터진다', (t) async {
    /* 둥근 단추를 누르면 창이 뜼고, 그 순간 Hero 가 짝을 찾는다 —
       이름이 겹치면 바로 그때 터진다. */
    for (var tab = 0; tab < 5; tab++) {
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(host(ShellScreen(onTouch: () {}), wrap: false));
      await t.pumpAndSettle();
      final dest = find.byType(NavigationDestination);
      if (dest.evaluate().length <= tab) break;
      await t.tap(dest.at(tab), warnIfMissed: false);
      await t.pumpAndSettle(const Duration(milliseconds: 400));
      t.takeException(); // 옮기다 난 탈은 위 시험이 잡는다
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isEmpty) continue;
      await t.tap(fab.first, warnIfMissed: false);
      await t.pumpAndSettle(const Duration(milliseconds: 500));
      final e = t.takeException();
      expect(e, isNull,
          reason: '${tab + 1}번째 탭의 둥근 단추를 누르니 터진다: $e');
    }
  });

  testWidgets('꺼풀 위로 화면을 밀어 넣었다 빼도 안 터진다', (t) async {
    /* 💥 2026-08-29 아침의 크래시가 바로 이 모양이었다 — 설정에서 「월 회비」를
       저장하고 창이 닫힐 때 빨간 화면이 떴다:
         There are multiple heroes that share the same tag.
       탭 다섯이 동시에 살아 있어 둥근 단추가 한 화면에 여럿인데,
       **화면을 옮길 때** Hero 가 그 이름으로 짝을 지으려다 「같은 이름이 둘」이라며 터졌다.
       그러니 탭만 옮겨서는 안 된다 — **밀어 넣고 빼야** 그 자리가 잡힌다. */
    for (var tab = 0; tab < 5; tab++) {
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(host(ShellScreen(onTouch: () {}), wrap: false));
      await t.pumpAndSettle();
      final dest = find.byType(NavigationDestination);
      if (dest.evaluate().length <= tab) break;
      await t.tap(dest.at(tab), warnIfMissed: false);
      await t.pumpAndSettle(const Duration(milliseconds: 400));
      t.takeException();

      // 꺼풀 위로 화면 하나를 밀어 넣는다 (설정·회원 같은 자리로 가는 것과 같다)
      final ctx = t.element(find.byType(NavigationBar));
      Navigator.of(ctx).push(MaterialPageRoute(
          builder: (_) => const Scaffold(body: Center(child: Text('새 화면')))));
      await t.pumpAndSettle(const Duration(milliseconds: 600));
      final e1 = t.takeException();
      expect(e1, isNull,
          reason: '${tab + 1}번째 탭에서 화면을 밀어 넣으니 터진다: $e1');

      Navigator.of(ctx).pop();
      await t.pumpAndSettle(const Duration(milliseconds: 600));
      final e2 = t.takeException();
      expect(e2, isNull,
          reason: '${tab + 1}번째 탭에서 화면을 빼니 터진다: $e2');
    }
  });

  /* 아직 안 훑은 화면들 — 총괄 콘솔·가입·승인 기다림.
     회원이 드물게 보는 자리일수록 눌러 본 적이 없어 버그가 오래 산다. */
  testWidgets('총괄 콘솔', (t) async =>
      tapEveryButton(t, () => const AdminConsole(), '총괄 콘솔',
          wrap: false, needButtons: false));

  testWidgets('승인 기다림', (t) async =>
      tapEveryButton(t, () => const WaitScreen(), '승인 기다림',
          wrap: false, needButtons: false));

  testWidgets('가입 화면', (t) async =>
      tapEveryButton(t, () => OnboardingScreen(onJoined: () {}), '가입 화면',
          wrap: false, needButtons: false));

  tearDownAll(() => AppState.i.setItems([]));
}
