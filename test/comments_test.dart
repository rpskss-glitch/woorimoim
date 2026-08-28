import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/comments.dart';
import 'package:woorimoim/state.dart';

/* 💬 게시판 댓글.

   ⚠️ 댓글은 «이용자가 쓴 글»이다 — 애플 1.2 는 그런 자리마다 신고·차단이 있기를 요구한다.
      대화방에만 두고 여기 빠뜨리면 그 자리 하나로 반려된다. 그래서 화면 코드까지 못 박는다. */
void main() {
  final st = AppState.i;

  void seed(List<Map<String, dynamic>> items) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': 'member'},
        'u2': {'uid': 'u2', 'name': '남', 'role': 'member'},
      },
    });
    st.setItems(items);
  }

  Map<String, dynamic> reply(String id, String post, String by, int at) => {
        'id': id,
        'type': 'reply',
        'replyTo': post,
        'by': by,
        'text': '댓글 $id',
        'createdAt': at,
      };

  test('그 글의 댓글만 골라 «오래된 것부터» 준다', () {
    seed([
      {'id': 'p1', 'type': 'diary', 'by': 'me', 'title': '글'},
      reply('c2', 'p1', 'u2', 200),
      reply('c1', 'p1', 'me', 100),
      reply('x1', 'p2', 'u2', 150), // 다른 글의 댓글
    ]);
    final got = Comments.of('p1').map((c) => c['id']).toList();
    expect(got, ['c1', 'c2'], reason: '대화처럼 위에서 아래로 읽는다');
    expect(Comments.count('p1'), 2);
    expect(Comments.count('없는글'), 0);
  });

  test('빈 댓글과 너무 긴 댓글은 막는다', () async {
    seed([]);
    expect(await Comments.add('p1', '   '), '내용을 적어주세요');
    final long = 'ㄱ' * (Comments.maxLen + 1);
    expect(await Comments.add('p1', long), contains('${Comments.maxLen}자'));
  });

  group('지울 수 있는 사람', () {
    test('내가 쓴 댓글은 내가 지운다', () {
      seed([]);
      expect(Comments.canDelete({'by': 'me'}), isTrue);
    });

    test('남의 댓글은 평회원이 못 지운다', () {
      seed([]);
      expect(Comments.canDelete({'by': 'u2'}), isFalse,
          reason: '서버가 거절할 사람에게 단추를 보여 주면 «헛단추»가 된다');
    });

    test('운영진은 남의 댓글도 지운다', () {
      st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
      st.setCouple({
        'members': {
          'me': {'uid': 'me', 'name': '나', 'role': 'admin'},
          'u2': {'uid': 'u2', 'name': '남', 'role': 'member'},
        },
      });
      st.setItems([]);
      expect(Comments.canDelete({'by': 'u2'}), isTrue);
    });
  });

  group('코드가 지켜야 하는 것', () {
    final code = File('lib/comments.dart').readAsStringSync();
    final ui = File('lib/ui/post_screen.dart').readAsStringSync();
    final board = File('lib/ui/board.dart').readAsStringSync();

    test('댓글을 «글 문서 안»에 배열로 넣지 않는다', () {
      /* 넣으면 댓글 하나마다 글 전체를 다시 써서, 두 사람이 거의 동시에 달면
         한쪽이 통째로 사라진다(마지막에 쓴 사람이 이긴다). */
      expect(code.contains("'type': type"), isTrue);
      expect(code.contains('mutateItem'), isFalse,
          reason: '글 문서를 고쳐 댓글을 넣고 있다 — 동시에 달면 하나가 사라진다');
    });

    test('신고·차단이 댓글에도 있다 (애플 1.2)', () {
      expect(ui.contains('reportSheet('), isTrue, reason: '댓글에 신고가 없으면 반려된다');
      expect(ui.contains('blockSheet('), isTrue, reason: '댓글에 차단이 없으면 반려된다');
    });

    test('차단한 사람의 댓글은 안 보인다', () {
      expect(ui.contains('Moderation.isBlocked'), isTrue,
          reason: '차단해 놓고 그 사람 댓글이 보이면 차단이 거짓말이 된다');
    });

    test('글을 지우면 딸린 댓글도 지운다', () {
      expect(board.contains('Comments.removeAllOf('), isTrue,
          reason: '안 지우면 «주인 없는 댓글»이 서버에 영영 남는다');
    });

    test('목록에서 글을 눌러 «안»으로 들어갈 수 있다', () {
      expect(board.contains('PostScreen(postId:'), isTrue);
      expect(board.contains('maxLines: 4'), isTrue,
          reason: '목록에서 안 자르면 긴 글 하나가 화면을 통째로 먹는다');
    });

    test('글 안에서는 «자르지 않는다»', () {
      final at = ui.indexOf("post['text']");
      expect(at, greaterThan(0));
      final near = ui.substring((at - 200).clamp(0, at), at + 120);
      expect(near.contains('maxLines'), isFalse,
          reason: '들어와서도 잘리면 뒷내용을 읽을 길이 아예 없다');
    });
  });
}
