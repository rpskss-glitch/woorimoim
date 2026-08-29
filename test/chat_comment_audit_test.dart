import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/comments.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/board.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/post_screen.dart';

/* 🔎 댓글·대화창 집중 점검.

   회원이 가장 오래 머무는 두 자리다. 여기가 부실하면 나머지가 아무리 좋아도 못 판다.
   실제로 일어나는 일들로 하나씩 눌러 본다. */
final _base = DateTime(2026, 8, 28, 20).millisecondsSinceEpoch;

void main() {
  final st = AppState.i;

  Widget host(Widget child) => MaterialApp(
        theme: buildTheme('sky'),
        home: Scaffold(body: child),
      );

  void seed(List<Map<String, dynamic>> extra) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple(Store.tidyCouple({
      'title': '앞산 배드민턴',
      'free': true,
      'fee': {'amount': 20000},
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': 'owner'},
        'u2': {'uid': 'u2', 'name': '박영진', 'role': 'member'},
      },
    }));
    st.setItems(Store.tidy(extra));
  }

  Map<String, dynamic> post(String id) => {
        'id': id, 'type': 'diary', 'by': 'u2',
        'title': '공지', 'text': '내용입니다', 'date': '2026-08-28',
      };

  /* ⚠️ 때는 **실제 밀리초**라야 한다 — 다듬기가 「말이 되는 때」가 아닌 값(1970년 같은 것)을
     빼 버려서, 작은 수를 쓰면 차례 시험이 엉뚱하게 실패한다(내가 그렇게 짜서 헛짚었다). */
  Map<String, dynamic> reply(String id, String to, String by, int at,
          {String text = '댓글'}) =>
      {'id': id, 'type': 'reply', 'replyTo': to, 'by': by, 'text': text,
       'createdAt': _base + at, 'date': '2026-08-28'};

  group('💭 댓글 — 셈', () {
    test('그 글의 댓글만, 오래된 것부터', () {
      seed([
        post('p1'), post('p2'),
        reply('c2', 'p1', 'u2', 200), reply('c1', 'p1', 'me', 100),
        reply('x1', 'p2', 'u2', 150),
      ]);
      expect(Comments.of('p1').map((c) => c['id']).toList(), ['c1', 'c2']);
      expect(Comments.count('p1'), 2);
      expect(Comments.count('p2'), 1);
      expect(Comments.count('없는글'), 0);
    });

    test('때가 같아도 «차례가 흔들리지» 않는다', () {
      /* 같은 밀리초에 둘이 달면(모임 날 흔하다) 볼 때마다 차례가 바뀌면 안 된다 —
         읽던 자리를 잃고, 「내 댓글이 사라졌나」로 읽는다. */
      seed([
        post('p1'),
        reply('cB', 'p1', 'u2', 100), reply('cA', 'p1', 'me', 100),
      ]);
      // 같은 때면 «문서 번호»로 갈라 준다 — 그래야 늘 같은 차례다
      expect(Comments.of('p1').map((c) => c['id']).toList(), ['cA', 'cB'],
          reason: '같은 때인데 차례가 정해져 있지 않다');
      for (var i = 0; i < 5; i++) {
        expect(Comments.of('p1').map((c) => c['id']).toList(), ['cA', 'cB'],
            reason: '볼 때마다 차례가 바뀐다');
      }
    });

    test('때가 여럿 겹쳐도 차례가 늘 같다', () {
      /* 모임 날 여럿이 한꺼번에 달면 같은 밀리초가 흔하다.
         Dart 의 sort 는 «차례를 지켜 주지 않아서»(불안정), 갈라 줄 것이 없으면
         볼 때마다 자리가 바뀔 수 있다. */
      seed([
        post('p1'),
        for (var i = 0; i < 12; i++) reply('c${i.toString().padLeft(2, '0')}', 'p1', 'u2', 500),
      ]);
      final want = Comments.of('p1').map((c) => c['id']).toList();
      expect(want.length, 12);
      for (var i = 0; i < 8; i++) {
        expect(Comments.of('p1').map((c) => c['id']).toList(), want,
            reason: '같은 때인 댓글 열두 개의 차례가 흔들린다');
      }
    });

    test('때가 없는 옛 댓글도 자리를 잃지 않는다', () {
      seed([post('p1'), reply('c1', 'p1', 'u2', 0), {
        'id': 'c0', 'type': 'reply', 'replyTo': 'p1', 'by': 'me', 'text': '옛 댓글',
      }]);
      expect(Comments.of('p1').length, 2, reason: '때가 없는 댓글이 사라졌다');
    });

    test('빈 댓글·너무 긴 댓글은 막는다', () async {
      seed([post('p1')]);
      expect(await Comments.add('p1', '   '), '내용을 적어주세요');
      expect(await Comments.add('p1', 'ㄱ' * (Comments.maxLen + 1)),
          contains('${Comments.maxLen}자'));
    });
  });

  group('💭 댓글 — 화면', () {
    testWidgets('댓글 수가 목록과 글 안에서 같다', (t) async {
      seed([post('p1'), reply('c1', 'p1', 'u2', 1), reply('c2', 'p1', 'me', 2)]);
      await t.pumpWidget(host(const BoardTab()));
      await t.pumpAndSettle();
      expect(find.textContaining('댓글 2'), findsWidgets,
          reason: '목록의 댓글 수가 틀리면 «새 댓글이 있나»를 못 읽는다');

      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(host(const PostScreen(postId: 'p1')));
      await t.pumpAndSettle();
      expect(find.textContaining('댓글 2'), findsWidgets);
    });

    testWidgets('글 안에서는 본문이 «안 잘린다»', (t) async {
      final longText = '가나다라마바사아자차카타파하 ' * 30;
      seed([{...post('p1'), 'text': longText}]);
      await t.pumpWidget(host(const PostScreen(postId: 'p1')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      // 들어와서도 잘리면 뒷내용을 읽을 길이 없다
      final ui = File('lib/ui/post_screen.dart').readAsStringSync();
      final at = ui.indexOf("post['text']");
      final near = ui.substring((at - 200).clamp(0, at), at + 120);
      expect(near.contains('maxLines'), isFalse);
    });

    testWidgets('댓글이 없으면 «처음으로 남겨보세요»라 한다', (t) async {
      seed([post('p1')]);
      await t.pumpWidget(host(const PostScreen(postId: 'p1')));
      await t.pumpAndSettle();
      expect(find.textContaining('아직 댓글이 없어요'), findsWidgets,
          reason: '빈 자리만 있으면 «고장났나»로 읽는다');
    });

    testWidgets('보내기 단추가 도는 동안 잠긴다', (t) async {
      seed([post('p1')]);
      await t.pumpWidget(host(const PostScreen(postId: 'p1')));
      await t.pumpAndSettle();
      final src = File('lib/ui/post_screen.dart').readAsStringSync();
      expect(src.contains('_busy ? null : _send'), isTrue,
          reason: '도는 동안 또 눌리면 같은 댓글이 두 번 달린다');
      expect(src.contains('finally'), isTrue,
          reason: '터졌을 때 잠금을 안 풀면 그 자리에서 영영 못 쓴다');
    });
  });

  group('💬 대화창', () {
    testWidgets('내 말과 남의 말이 갈라 보인다', (t) async {
      seed([
        {'id': 'm1', 'type': 'msg', 'by': 'u2', 'text': '남의 말', 'createdAt': 1},
        {'id': 'm2', 'type': 'msg', 'by': 'me', 'text': '내 말', 'createdAt': 2},
      ]);
      await t.pumpWidget(host(const ChatTab(active: true)));
      await t.pumpAndSettle();
      expect(find.textContaining('남의 말'), findsWidgets);
      expect(find.textContaining('내 말'), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('아주 긴 말도 넘치지 않는다', (t) async {
      seed([
        {
          'id': 'm1', 'type': 'msg', 'by': 'u2',
          'text': '가나다라마바사아자차카타파하' * 60, 'createdAt': 1,
        },
      ]);
      await t.pumpWidget(host(const ChatTab(active: true)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '긴 말이 화면 밖으로 나간다');
    });

    testWidgets('붙여 넣은 줄바꿈 덩어리도 버틴다', (t) async {
      seed([
        {'id': 'm1', 'type': 'msg', 'by': 'u2', 'text': '\n' * 200, 'createdAt': 1},
      ]);
      await t.pumpWidget(host(const ChatTab(active: true)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    test('보내는 글의 길이 한계가 있다', () {
      final src = File('lib/ui/chat.dart').readAsStringSync();
      expect(RegExp(r'maxLength:\s*\d+').hasMatch(src), isTrue,
          reason: '한계가 없으면 한 사람이 대화방을 통째로 먹는다');
    });

    testWidgets('대화가 하나도 없어도 안 터진다', (t) async {
      seed([]);
      await t.pumpWidget(host(const ChatTab(active: true)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('🔒 애플 1.2 — 신고·차단이 둘 다에 있다', () {
    test('대화방에도 댓글에도 신고·차단이 있다', () {
      for (final f in ['lib/ui/chat.dart', 'lib/ui/post_screen.dart']) {
        final s = File(f).readAsStringSync();
        expect(s.contains('reportSheet('), isTrue, reason: '$f 에 신고가 없다');
        expect(s.contains('blockSheet('), isTrue, reason: '$f 에 차단이 없다');
      }
    });

    test('차단한 사람은 둘 다에서 안 보인다', () {
      for (final f in ['lib/ui/chat.dart', 'lib/ui/post_screen.dart']) {
        expect(File(f).readAsStringSync().contains('Moderation'), isTrue,
            reason: '$f 에서 차단이 안 지켜진다');
      }
    });

    test('내 것에는 신고·차단을 안 보여 준다', () {
      // 내 글을 신고하는 단추는 «뜻이 없는 단추»다
      final ui = File('lib/ui/post_screen.dart').readAsStringSync();
      expect(ui.contains('by != Store.i.myUid'), isTrue);
    });
  });

  group('🗑 지울 때', () {
    test('글을 지우면 딸린 댓글도 지운다', () {
      expect(File('lib/ui/board.dart').readAsStringSync()
          .contains('Comments.removeAllOf('), isTrue,
          reason: '안 지우면 «주인 없는 댓글»이 서버에 영영 남는다');
    });

    test('댓글은 쓴 사람과 운영진만 지운다', () {
      seed([]);
      expect(Comments.canDelete({'by': 'me'}), isTrue);
      expect(Comments.canDelete({'by': 'u2'}), isTrue, reason: '나는 방장이다');
      st.setCouple(Store.tidyCouple({
        'members': {
          'me': {'uid': 'me', 'name': '나', 'role': 'member'},
          'u2': {'uid': 'u2', 'name': '남', 'role': 'member'},
        },
      }));
      expect(Comments.canDelete({'by': 'u2'}), isFalse,
          reason: '서버가 거절할 사람에게 단추를 보여 주면 헛단추가 된다');
    });
  });

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });
}
