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
import 'package:woorimoim/ui/wallet.dart';

/* 👆 「누르는 자리가 손가락에 닿는가」

   애플은 44×44pt, 구글은 48×48dp를 최소로 본다. 그보다 작으면
     · 어르신 회원이 계속 헛누른다 (이 앱을 쓰는 사람은 중장년이 많다)
     · 애플이 4.0(디자인)으로 되돌려보낼 수 있다
     · 옆 단추를 잘못 눌러 «지우기» 같은 되돌릴 수 없는 일이 벌어진다

   ⚠️ 아이콘이 작아도 «누를 수 있는 넓이»가 크면 된다 — 여기서는 그 넓이를 잰다.
   ⚠️ 화면 밖에 있는 것은 재지 않는다(크기가 0으로 잡힌다). */
void main() {
  final st = AppState.i;

  /// 이보다 작으면 손가락이 자꾸 빗나간다
  const minSide = 40.0; // 애플 44 · 구글 48 이지만, 겹침 여백을 감안해 조금 눅인다

  Future<List<String>> tooSmall(WidgetTester t, String label) async {
    final bad = <String>[];
    final found = find.byWidgetPredicate((w) =>
        w is IconButton ||
        w is FilledButton ||
        w is OutlinedButton ||
        w is TextButton ||
        w is FloatingActionButton ||
        w is PopupMenuButton);
    for (final e in found.evaluate()) {
      final box = e.renderObject;
      if (box is! RenderBox || !box.hasSize) continue;
      final s = box.size;
      if (s.width <= 0 || s.height <= 0) continue; // 안 그려진 것
      // 화면 밖으로 나간 것은 세지 않는다
      final pos = box.localToGlobal(Offset.zero);
      if (pos.dy < -200 || pos.dy > 2000) continue;
      if (s.height < minSide) {
        bad.add('$label · ${e.widget.runtimeType} '
            '${s.width.toStringAsFixed(0)}×${s.height.toStringAsFixed(0)}');
      }
    }
    return bad;
  }

  final screens = <String, Widget Function()>{
    '홈': () => const HomeTab(),
    '대화방': () => const ChatTab(active: true),
    '일정': () => const CalendarTab(),
    '회비': () => const WalletTab(),
    '게시판': () => const BoardTab(),
  };

  for (final e in screens.entries) {
    testWidgets('${e.key} — 누르는 자리가 손가락에 닿는다', (t) async {
      Demo.start();
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: Scaffold(body: e.value()),
      ));
      await t.pumpAndSettle();
      final bad = await tooSmall(t, e.key);
      expect(bad, isEmpty,
          reason: '${minSide.toInt()}px 보다 낮은 단추가 있다 — '
              '어르신 회원이 헛누르고, 옆 단추를 잘못 누른다: $bad');
    });
  }

  final full = <String, Widget Function()>{
    '설정': () => const SettingsScreen(),
    '회원 관리': () => const MembersScreen(),
    '회비 표': () => const FeeSheetScreen(),
  };

  for (final e in full.entries) {
    testWidgets('${e.key} — 누르는 자리가 손가락에 닿는다', (t) async {
      Demo.start();
      await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: e.value()));
      await t.pumpAndSettle();
      final bad = await tooSmall(t, e.key);
      expect(bad, isEmpty, reason: '작은 단추가 있다: $bad');
    });
  }

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });
}
