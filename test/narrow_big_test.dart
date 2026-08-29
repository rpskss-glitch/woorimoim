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
import 'package:woorimoim/ui/post_screen.dart';
import 'package:woorimoim/ui/settings.dart';
import 'package:woorimoim/ui/shell.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 📏 「좁은 화면 + 큰 글자」로 모든 화면을 그려 본다.

   이 앱을 쓰는 사람은 중장년이 많다 — 폰 설정에서 글자를 키워 둔 회원이 흔하다.
   그리고 값싼 폰은 아직도 360px 폭이다. 그 조합에서 화면이 오른쪽으로 넘치면
   노란 줄무늬가 뜨고, 넘친 자리의 단추는 **아예 못 누른다.**

   ⚠️ 글자 크기는 `MediaQuery` 가 아니라 **폰 설정 수준**으로 키워야 창까지 닿는다
      (2026-08-22에 이걸로 헛짚었다).
   ⚠️ 기존 `big_font_test` 는 창 하나만 본다 — 여기서는 **탭 화면 전부**를 본다. */
void main() {
  final st = AppState.i;

  Widget host(Widget child) => MaterialApp(
        theme: buildTheme('sky'),
        home: Scaffold(body: child),
      );

  /// 실제 모임처럼 — 이름이 길고, 회원이 여럿이고, 글이 길다
  void seed() {
    Demo.start();
    final c = Map<String, dynamic>.from(st.couple ?? {});
    c['title'] = '앞산 배드민턴 수요일 저녁 초보반';
    st.setCouple(c);
    st.setItems([
      ...st.items,
      {
        'id': 'x1', 'type': 'msg', 'by': 'u_yj',
        'text': '이번 주 토요일 번개 어떠세요 라켓 없으셔도 빌려드립니다',
        'createdAt': 9,
      },
      {
        'id': 'x2', 'type': 'diary', 'by': 'u_yj',
        'title': '겨울 체육관 대관 안내드립니다 꼭 읽어주세요',
        'text': '12월부터 2월까지는 3코트에서 5코트로 늘립니다. 회비는 그대로예요.',
        'date': '2026-08-28',
      },
      {
        'id': 'x3', 'type': 'reply', 'replyTo': 'x2', 'by': 'u_sh',
        'text': '알겠습니다 감사합니다', 'date': '2026-08-28', 'createdAt': 10,
      },
      {
        'id': 'x4', 'type': 'event', 'by': 'u_yj',
        'title': '정기 모임 — 앞산 체육관 3코트 초보 레슨 먼저',
        'date': '2026-09-02', 'time': '19:00', 'place': '앞산 체육관 3코트',
      },
    ]);
  }

  /// 좁은 화면·큰 글자로 맞춘다
  void small(WidgetTester t, double scale) {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  }

  final screens = <String, Widget Function()>{
    '홈': () => const HomeTab(),
    '대화방': () => const ChatTab(active: true),
    '일정': () => const CalendarTab(),
    '회비': () => const WalletTab(),
    '게시판': () => const BoardTab(),
    '글 안': () => const PostScreen(postId: 'x2'),
  };

  for (final scale in [1.0, 1.5, 2.0]) {
    for (final e in screens.entries) {
      testWidgets('${e.key} — 360px · 글자 ${scale}배', (t) async {
        small(t, scale);
        seed();
        await t.pumpWidget(host(e.value()));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull,
            reason: '${e.key} 이 360px·${scale}배에서 넘친다 — '
                '넘친 자리의 단추는 아예 못 누른다');
      });
    }
  }

  // 스스로 Scaffold 를 세우는 화면들은 따로 (두 겹으로 씌우면 안 된다)
  final full = <String, Widget Function()>{
    '설정': () => const SettingsScreen(),
    '회원 관리': () => const MembersScreen(),
    '회비 표': () => const FeeSheetScreen(),
  };

  for (final scale in [1.0, 2.0]) {
    for (final e in full.entries) {
      testWidgets('${e.key} — 360px · 글자 ${scale}배', (t) async {
        small(t, scale);
        seed();
        await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: e.value()));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull,
            reason: '${e.key} 이 360px·${scale}배에서 넘친다');
      });
    }
  }

  testWidgets('꺼풀(탭 다섯) — 360px · 글자 2배', (t) async {
    /* 아래쪽 탭 막대가 가장 먼저 넘친다 — 이름 다섯이 한 줄에 들어가야 한다. */
    small(t, 2.0);
    seed();
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: ShellScreen(onTouch: () {}),
    ));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: '탭 막대가 넘친다 — 탭을 못 누른다');
  });

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });
}
