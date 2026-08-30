import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/album.dart';
import 'package:woorimoim/ui/admin.dart';
import 'package:woorimoim/ui/board.dart';
import 'package:woorimoim/ui/fee_screen.dart';
import 'package:woorimoim/ui/calendar.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/fee_sheet_screen.dart';
import 'package:woorimoim/ui/home.dart';
import 'package:woorimoim/ui/members.dart';
import 'package:woorimoim/ui/onboarding.dart';
import 'package:woorimoim/ui/owner_guide.dart';
import 'package:woorimoim/ui/settings.dart';
import 'package:woorimoim/ui/wait.dart';
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
    /* 🔴 아래 셋은 그물에 아예 안 걸려 있었다.
         · 가입 화면  — **회원이 제일 처음 보는 곳**이자 스토어 심사원이 첫 화면으로 본다
         · 이용권 화면 — 애플이 반드시 눌러 보는 곳(3.1.1·3.1.2)
         · 대기 화면  — 승인 기다리는 회원이 며칠씩 보는 곳
       빠져 있으면 여기가 깨져도 아무도 모른다. */
    '가입 화면': () => OnboardingScreen(onJoined: () {}),
    '이용권': () => const FeeScreen(),
    '승인 대기': () => const WaitScreen(),
    /* 총괄 콘솔은 사장님만 보는 곳이지만, 여기가 깨지면 **모임을 만들 수가 없다.**
       (새 모임 만들기·방장 코드 내주기가 전부 여기 있다) */
    '총괄 콘솔': () => const AdminConsole(),
    /* 📖 방장 안내서 — 홈 맨 위에 얹히는 «큰 카드»라 좁은 화면에서 제일 위험하다.
       여섯 걸음 × 여러 줄이라 글자를 키우면 금방 넘친다. */
    /* ⚠️ 실제로는 홈의 «밀리는 목록» 안에 있다 — 그냥 두면 카드 하나가 화면보다
       길다고 «넘쳤다»고 나온다(그건 이 카드의 탈이 아니다).
       세로로 밀 수 있는 자리에 넣어, 실제와 같은 조건에서 «가로 넘침»과 단추 크기를 본다. */
    '방장 안내서': () => SingleChildScrollView(
          child: OwnerGuideCard(onClosed: () {}, onGo: (_) {}),
        ),
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

  /* 📸 사진첩은 게시판 «안»(사진 쪽)이라 위 그물에 안 걸린다 — 따로 잰다.
     여기가 특히 위험하다: 반응 다섯이 나란히 붙어 있어, 작으면 옆의 다른 반응을 누른다. */
  testWidgets('사진첩 — 누르는 자리가 손가락에 닿는다', (t) async {
    Demo.start();
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: Scaffold(body: AlbumView(onChanged: () {})),
    ));
    await t.pumpAndSettle();
    final bad = await tooSmall(t, '사진첩');
    expect(bad, isEmpty, reason: '작은 단추가 있다: $bad');
  });

  testWidgets('사진 크게 보기 — 반응 단추가 손가락에 닿는다', (t) async {
    Demo.start();
    final rows = [
      {
        'id': 'ph1', 'type': 'photo', 'by': 'u_yj', 'photoId': 'p1',
        'date': '2026-08-28', 'caption': '단체사진', 'createdAt': 11,
      },
    ];
    await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'), home: PhotoPage(rows: rows, start: 0)));
    await t.pumpAndSettle();

    final bad = await tooSmall(t, '사진 크게 보기');
    expect(bad, isEmpty, reason: '작은 단추가 있다: $bad');

    /* 반응은 InkWell 이라 위 그물(단추 종류)에 안 걸린다 — 직접 잰다.
       다섯이 나란히 붙어 있어 작으면 «옆 반응»을 누른다. */
    final small = <String>[];
    for (final e in photoReactions) {
      final f = find.ancestor(
          of: find.text(e), matching: find.byType(InkWell));
      if (f.evaluate().isEmpty) continue;
      final box = t.renderObject<RenderBox>(f.first);
      if (box.size.height < minSide || box.size.width < minSide) {
        small.add('$e ${box.size.width.toStringAsFixed(0)}×'
            '${box.size.height.toStringAsFixed(0)}');
      }
    }
    expect(small, isEmpty, reason: '반응 단추가 작다 — 옆 것을 잘못 누른다: $small');
  });

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });
}
