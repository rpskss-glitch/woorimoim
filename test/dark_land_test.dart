import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/board.dart';
import 'package:woorimoim/ui/calendar.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/fee_sheet_screen.dart';
import 'package:woorimoim/ui/home.dart';
import 'package:woorimoim/ui/members.dart';
import 'package:woorimoim/ui/settings.dart';
import 'package:woorimoim/ui/shell.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 🌙 어두운 화면 · 📱 가로로 눕힌 화면.

   · 어두운 화면: 밤에 체육관에서 쓰는 회원이 많다. 색을 손으로 박아 두면 그때 안 보인다.
   · 가로 화면: 폰을 눕히면 세로가 짧아진다(640 → 360). 세로로 긴 창은 그때 넘친다.
     아이패드에서 아이폰 앱을 쓰면 창 크기가 더 제멋대로다.

   ⚠️ 「안 터진다」만 보는 것이 아니라 «글자가 배경에 묻히지 않는가»도 본다 —
      묻히면 화면은 멀쩡한데 아무것도 안 읽힌다. */
void main() {
  final st = AppState.i;

  final screens = <String, Widget Function()>{
    '홈': () => const HomeTab(),
    '대화방': () => const ChatTab(active: true),
    '일정': () => const CalendarTab(),
    '회비': () => const WalletTab(),
    '게시판': () => const BoardTab(),
  };

  final fullScreens = <String, Widget Function()>{
    '설정': () => const SettingsScreen(),
    '회원 관리': () => const MembersScreen(),
    '회비 표': () => const FeeSheetScreen(),
  };

  group('어두운 화면', () {
    for (final e in screens.entries) {
      testWidgets('${e.key} 이 어두운 화면에서도 온전하다', (t) async {
        Demo.start();
        await t.pumpWidget(MaterialApp(
          theme: buildTheme('sky'),
          darkTheme: buildTheme('sky', dark: true),
          themeMode: ThemeMode.dark,
          home: Scaffold(body: e.value()),
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '${e.key} 이 어두운 화면에서 터진다');
      });
    }

    for (final e in fullScreens.entries) {
      testWidgets('${e.key} 이 어두운 화면에서도 온전하다', (t) async {
        Demo.start();
        await t.pumpWidget(MaterialApp(
          theme: buildTheme('sky'),
          darkTheme: buildTheme('sky', dark: true),
          themeMode: ThemeMode.dark,
          home: e.value(),
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '${e.key} 이 어두운 화면에서 터진다');
      });
    }
  });

  group('가로로 눕힌 화면 (640 × 360)', () {
    for (final e in screens.entries) {
      testWidgets('${e.key}', (t) async {
        t.view.physicalSize = const Size(640, 360);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);
        Demo.start();
        await t.pumpWidget(MaterialApp(
          theme: buildTheme('sky'),
          home: Scaffold(body: e.value()),
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '${e.key} 이 눕힌 화면에서 넘친다');
      });
    }

    for (final e in fullScreens.entries) {
      testWidgets('${e.key}', (t) async {
        t.view.physicalSize = const Size(640, 360);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);
        Demo.start();
        await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: e.value()));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '${e.key} 이 눕힌 화면에서 넘친다');
      });
    }

    testWidgets('꺼풀(탭 다섯)', (t) async {
      t.view.physicalSize = const Size(640, 360);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      Demo.start();
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: ShellScreen(onTouch: () {}),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '눕힌 화면에서 탭 막대가 넘친다');
    });
  });

  group('눕힌 화면 + 큰 글자', () {
    // 아이패드에서 아이폰 앱을 쓰면서 글자를 키운 회원 — 실제로 있는 조합
    for (final e in screens.entries) {
      testWidgets('${e.key}', (t) async {
        t.view.physicalSize = const Size(640, 360);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);
        t.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        Demo.start();
        await t.pumpWidget(MaterialApp(
          theme: buildTheme('sky'),
          home: Scaffold(body: e.value()),
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull,
            reason: '${e.key} 이 눕힌 화면·큰 글자에서 넘친다');
      });
    }
  });

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });
}
