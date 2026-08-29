import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/chat.dart';

/* 📊 대화방 투표 (191회차).

   방장이 이 숫자를 보고 코트를 잡고 단체복을 주문한다 — 세는 규칙이 틀리면 돈이 든다.
   참석 투표(rsvp)에서 실제로 겪은 두 가지를 처음부터 막아 둔다:
     · 탈퇴한 회원의 옛 표가 그대로 세어져 **실제 2명인데 「참석 4」**로 보였다
     · 폰을 바꾼 회원이 옛·새 번호로 두 번 세어졌다
   그리고 자료 모양은 **웹앱과 같아야 한다** — 같은 방을 두 앱이 함께 본다. */
void main() {
  String bare(String p) => File(p)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  /// u9 → u1 로 폰을 바꾼 방. u4 는 탈퇴해서 members 에 없다.
  void seedClub() {
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'u1': {'uid': 'u1', 'name': '갑'},
        'u2': {'uid': 'u2', 'name': '을'},
        'u3': {'uid': 'u3', 'name': '병'},
      },
      'former': {
        'u9': {'uid': 'u9', 'name': '갑', 'movedTo': 'u1'},
        'u4': {'uid': 'u4', 'name': '나간이'},
      },
    });
    AppState.i.setItems([]);
  }

  Map<String, dynamic> poll({
    String q = '토요일 번개 어때요?',
    List<String> opts = const ['오전', '오후'],
    bool multi = false,
    bool closed = false,
    Map<String, dynamic>? votes,
  }) =>
      {
        'id': 'm1',
        'type': 'msg',
        'kind': 'poll',
        'text': q,
        'poll': {'q': q, 'opts': opts, 'multi': multi, 'closed': closed},
        'votes': votes ?? <String, dynamic>{},
      };

  group('투표 읽기', () {
    test('질문·항목·설정을 그대로 읽는다', () {
      final p = Logic.poll(poll(opts: ['가', '나', '다'], multi: true, closed: true));
      expect(p.q, '토요일 번개 어때요?');
      expect(p.opts, ['가', '나', '다']);
      expect(p.multi, isTrue);
      expect(p.closed, isTrue);
    });

    test('질문이 없으면 text 로 되돌려 읽는다 — 옛 앱이 적은 것도 보이게', () {
      final m = {'kind': 'poll', 'text': '단체복 색', 'poll': {'opts': ['남색', '흰색']}};
      expect(Logic.poll(m).q, '단체복 색');
    });

    test('망가진 값이 와도 안 터진다 — 여기서 터지면 대화방이 통째로 안 뜬다', () {
      expect(Logic.poll({'kind': 'poll'}).opts, isEmpty);
      expect(Logic.poll({'kind': 'poll', 'poll': '묶음아님'}).opts, isEmpty);
      expect(Logic.poll({'kind': 'poll', 'poll': {'opts': '배열아님'}}).opts, isEmpty);
      // 글자가 아닌 항목은 빼고 나머지는 살린다
      expect(Logic.poll({'kind': 'poll', 'poll': {'opts': ['가', 7, null, '나']}}).opts,
          ['가', '나']);
    });

    test('다듬기(tidy)도 같은 모양으로 고쳐 준다', () {
      final fixed = Store.tidy([
        {'id': 'x', 'type': 'msg', 'kind': 'poll', 'text': '질문', 'poll': '묶음아님', 'votes': '묶음아님'}
      ]).first;
      expect((fixed['poll'] as Map)['q'], '질문');
      expect((fixed['poll'] as Map)['opts'], isEmpty);
      expect(fixed['votes'], <String, dynamic>{});
    });
  });

  group('표 세기', () {
    test('항목마다 누가 골랐는지 센다', () {
      seedClub();
      final t = Logic.pollTally(poll(votes: {'u1': [0], 'u2': [1], 'u3': [1]}));
      expect(t.per[0], ['u1']);
      expect(t.per[1], ['u2', 'u3']);
      expect(t.voters, 3);
    });

    test('탈퇴한 회원의 표는 안 센다 — 방장이 없는 사람 몫까지 코트를 잡는다', () {
      seedClub();
      final t = Logic.pollTally(poll(votes: {'u1': [0], 'u4': [0]}));
      expect(t.per[0], ['u1']);
      expect(t.voters, 1);
    });

    test('폰을 바꾼 사람은 «한 사람»으로 센다', () {
      seedClub();
      // 옛 번호로 찍은 표가 남아 있는데 새 번호로 또 찍었다
      final t = Logic.pollTally(poll(votes: {'u9': [1], 'u1': [0]}));
      expect(t.voters, 1, reason: '한 사람인데 둘로 세어진다');
      expect(t.per[0], ['u1'], reason: '지금 번호로 찍은 표가 이겨야 한다');
      expect(t.per[1], isEmpty);
    });

    test('적힌 차례가 거꾸로여도 지금 번호로 찍은 표가 이긴다', () {
      seedClub();
      final t = Logic.pollTally(poll(votes: {'u1': [0], 'u9': [1]}));
      expect(t.voters, 1);
      expect(t.per[0], ['u1']);
      expect(t.per[1], isEmpty);
    });

    test('여러 개 고른 사람은 항목마다 세지만 «참여»는 한 번', () {
      seedClub();
      final t = Logic.pollTally(poll(opts: ['가', '나', '다'], multi: true, votes: {
        'u1': [0, 2],
        'u2': [0],
      }));
      expect(t.per[0].length, 2);
      expect(t.per[2], ['u1']);
      expect(t.voters, 2);
    });

    test('없는 항목 번호·이상한 값은 버린다', () {
      seedClub();
      final t = Logic.pollTally(poll(votes: {
        'u1': [5], // 지워진 항목을 가리키는 옛 표
        'u2': '배열아님',
        'u3': 1, // 숫자 하나만 적힌 옛 꼴은 살린다
      }));
      expect(t.per[0], isEmpty);
      expect(t.per[1], ['u3']);
      expect(t.voters, 1, reason: '고른 것이 하나도 없는 사람은 «참여»가 아니다');
    });
  });

  group('내 표', () {
    test('옛 번호로 찍은 표도 내 표다 — 안 그러면 내 단추가 안 눌린 것처럼 보인다', () {
      seedClub();
      expect(Logic.pollMine(poll(votes: {'u9': [1]}), 'u1'), [1]);
    });

    test('지금 번호로 찍은 것이 있으면 그것을 본다', () {
      seedClub();
      expect(Logic.pollMine(poll(votes: {'u9': [1], 'u1': [0]}), 'u1'), [0]);
    });

    test('옛 표 자리를 알려준다 — 찍을 때 함께 지워야 유령 표가 안 남는다', () {
      seedClub();
      expect(Logic.pollOldKeys(poll(votes: {'u9': [1], 'u2': [0]}), 'u1'), ['u9']);
      expect(Logic.pollOldKeys(poll(votes: {'u1': [1]}), 'u1'), isEmpty);
    });
  });

  group('눌렀을 때 바뀌는 표', () {
    test('하나만 고르는 투표는 갈아치운다', () {
      expect(Logic.pollNext([0], 1, false), [1]);
    });
    test('같은 것을 다시 누르면 취소', () {
      expect(Logic.pollNext([1], 1, false), isEmpty);
      expect(Logic.pollNext([0, 1], 1, true), [0]);
    });
    test('여러 개 고르는 투표는 더한다 (차례대로)', () {
      expect(Logic.pollNext([2], 0, true), [0, 2]);
    });
  });

  group('그려 보기', () {
    /// 말풍선 안(폭 260)에 든 투표 카드를 [scale]배 글자·[theme] 색으로 그려 본다
    Future<List<String>> paint(WidgetTester t, Map<String, dynamic> msg,
        {double scale = 1.0, bool dark = false, bool mine = false}) async {
      final errs = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) => errs.add(d.exception.toString());
      t.view.physicalSize = const Size(320, 700);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final theme = buildTheme('sky', dark: dark);
      await t.pumpWidget(MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            // 실제로는 «대화 목록»(스크롤) 안에 든다 — 안 감싸면 긴 투표가
            // 「화면보다 길다」는 것만으로 넘침으로 잡혀 옆으로 넘치는 진짜 버그를 못 본다
            body: SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 260),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                color: mine ? theme.colorScheme.primary : theme.cardColor,
                child: PollCard(msg: msg, mine: mine, myUid: 'u1'),
              ),
            ),
          ),
        ),
      ));
      await t.pump(const Duration(milliseconds: 200));
      FlutterError.onError = prev;
      return errs;
    }

    testWidgets('보통 크기 — 넘치지도, 화면을 다 덮지도 않는다', (t) async {
      seedClub();
      final errs = await paint(t, poll(votes: {'u1': [0], 'u2': [1]}));
      expect(errs, isEmpty);
      final size = t.getSize(find.byType(PollCard));
      // 말풍선 하나가 화면을 덮으면 대화가 안 보인다 (Column 이 남은 높이를 다 먹던 자리)
      expect(size.height, lessThan(300), reason: '투표 하나가 화면을 덮는다');
      expect(find.textContaining('2명 참여'), findsOneWidget);
    });

    testWidgets('항목 8개 · 긴 이름 · 큰 글자(2배) · 밤 화면에서도 안 넘친다', (t) async {
      seedClub();
      final errs = await paint(
        t,
        poll(
          q: '단체복 색을 골라주세요 (여러 개 고를 수 있어요)',
          opts: [
            for (var i = 1; i <= 8; i++) '$i번 — 아주 긴 항목 이름을 적어 본 것입니다'
          ],
          multi: true,
          votes: {'u1': [0, 7], 'u2': [3]},
        ),
        scale: 2.0,
        dark: true,
      );
      expect(errs.where((e) => e.contains('overflow')), isEmpty);
      expect(errs, isEmpty);
    });

    testWidgets('내 말풍선(진한 바탕) 안에서도 항목 글씨가 보인다', (t) async {
      seedClub();
      final errs = await paint(t, poll(closed: true, votes: {'u1': [0]}), mine: true);
      expect(errs, isEmpty);
      // 항목 칸은 «자기 색»을 가진다 — 진한 바탕을 물려받으면 글씨가 묻힌다
      final box = t.widget<Material>(find.descendant(
          of: find.byType(PollCard), matching: find.byType(Material)).first);
      expect(box.color, isNot(Colors.transparent));
      expect(find.textContaining('마감'), findsOneWidget);
      // 마감된 뒤에는 눌러도 안 바뀐다
      expect(t.widget<InkWell>(find.descendant(
              of: find.byType(PollCard), matching: find.byType(InkWell)).first)
          .onTap, isNull);
    });
  });

  group('코드가 지켜야 하는 것', () {
    final chat = bare('lib/ui/chat.dart');

    test('표는 «내 자리»만 적는다 — 통째로 덮어쓰면 남의 표가 사라진다', () {
      final at = chat.indexOf('Future<void> _vote(');
      expect(at, greaterThan(0));
      final body = chat.substring(at, chat.indexOf('Future<void> _setClosed', at));
      expect(body, contains('mutateItem'), reason: '트랜잭션 없이 고치면 남의 표를 덮는다');
      expect(body, contains('Store.i.myUid: next'));
      expect(body, contains('pollOldKeys'), reason: '폰 바꾸기 전 옛 표가 남아 두 번 세어진다');
      expect(body, contains('if (p.closed) return null'),
          reason: '마감된 뒤에 들어온 표를 받아 준다');
    });

    test('질문은 text 에도 담는다 — 투표를 모르는 옛 앱에서 빈 말풍선이 되지 않게', () {
      final at = chat.indexOf('Future<void> _newPoll(');
      expect(at, greaterThan(0));
      final body = chat.substring(at, chat.indexOf('void _scrollToBottom(', at));
      expect(body, contains("'text': r['q']"));
      expect(body, contains("'kind': 'poll'"));
      // 저장 결과를 안 보면 「올렸어요」인 줄 알고 회원들의 답을 기다린다
      // 안내 함수 이름은 바뀔 수 있다 — «안 됐으면 말한다»는 뜻만 지킨다
      expect(RegExp(r'if \(id == null\) return \w*[Tt]oast').hasMatch(body), isTrue,
          reason: '투표를 못 올렸는데 아무 말이 없으면 회원들의 답을 기다리게 된다');
    });

    test('투표 만들기 칸도 길이가 막혀 있다 (회원 전원에게 내려가는 글)', () {
      expect(chat, contains('maxLength: 60'));
      expect(chat, contains('maxLength: 30'));
    });
  });
}
