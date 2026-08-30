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
import 'package:woorimoim/ui/post_screen.dart';
import 'package:woorimoim/ui/settings.dart';
import 'package:woorimoim/ui/wait.dart';
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

  /* 📸 사진첩은 게시판 «안»에 있는데 기본이 「글」쪽이라 위 그물에 안 걸린다.
     그런데 여기가 제일 잘 넘친다 — 딱지(전체·즐겨찾기·최신순·#태그)가 한 줄에 몰리고,
     사진 격자 한 칸에 설명까지 얹힌다. 따로 그려 본다. */
  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('사진첩 — 360px · 글자 ${scale}배', (t) async {
      small(t, scale);
      seed();
      // 태그가 붙은 사진도 있어야 «태그 띠»까지 그려진다
      st.setItems([
        ...st.items,
        {
          'id': 'ph1', 'type': 'photo', 'by': 'u_yj', 'photoId': 'p1',
          'date': '2026-08-28', 'fav': true,
          'caption': '앞산 체육관 정기모임 단체사진 #대회 #단체복',
          'createdAt': 11,
        },
      ]);
      await t.pumpWidget(host(AlbumView(onChanged: () {})));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull,
          reason: '사진첩이 360px·${scale}배에서 넘친다 — 딱지나 단추를 못 누른다');
    });

    testWidgets('사진 크게 보기 — 360px · 글자 ${scale}배', (t) async {
      small(t, scale);
      seed();
      final rows = [
        {
          'id': 'ph1', 'type': 'photo', 'by': 'u_yj', 'photoId': 'p1',
          'date': '2026-08-28',
          'caption': '앞산 체육관 정기모임 단체사진 #대회 #단체복',
          'reacts': {'u_sh': '❤️', 'u_mj': '😂', 'u_dh': '👍', 'u_jh': '😍'},
          'createdAt': 11,
        },
      ];
      await t.pumpWidget(
          MaterialApp(theme: buildTheme('sky'), home: PhotoPage(rows: rows, start: 0)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull,
          reason: '사진 크게 보기가 360px·${scale}배에서 넘친다 — 반응을 못 누른다');
    });
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
