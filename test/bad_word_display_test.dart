import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/board.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/post_screen.dart';

/* 🤬 심한 욕설은 화면에서 별표로 — «실제로 그려진 글»로 확인한다.

   2026-09-25 조사: 거르는 말 목록과 별표 함수(Moderation.mask)는 있었는데
   **어느 화면도 부르지 않았다**(시험만 불렀다). 대화·댓글·게시판에 욕이 그대로 떴다.
   애플 1.2 는 «거르기·신고·차단·운영자 연락» 넷을 요구한다 — 하나가 빠져 있었다. */
void main() {
  final st = AppState.i;
  const bad = '씨발';

  Future<void> host(WidgetTester t, Widget w) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: Scaffold(body: w)));
    await t.pumpAndSettle();
  }

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });

  bool seen(String s) => find.textContaining(s, findRichText: true).evaluate().isNotEmpty;

  testWidgets('대화방', (t) async {
    Demo.start();
    Demo.addItem({
      'type': 'msg',
      'coupleId': Demo.code,
      'by': 'u_jh',
      'text': '아 $bad 늦었다',
      'createdAt': DateTime.now().millisecondsSinceEpoch + 1000,
    });
    await host(t, const ChatTab(active: true));
    expect(seen(bad), isFalse, reason: '대화방에 욕이 그대로 보인다');
    expect(seen('아 ** 늦었다'), isTrue, reason: '별표로 가린 말이 안 보인다(글이 통째로 사라지면 안 된다)');
  });

  testWidgets('게시판 목록과 글 안·댓글', (t) async {
    Demo.start();
    final now = DateTime.now().millisecondsSinceEpoch;
    Demo.addItem({'type': 'diary', 'coupleId': Demo.code, 'by': 'u_jh', 'title': '$bad 공지',
      'text': '본문 $bad', 'date': '2026-09-25', 'createdAt': now + 5000}, docId: 'pbad');
    Demo.addItem({'type': 'reply', 'coupleId': Demo.code, 'by': 'u_sh', 'replyTo': 'pbad',
      'text': '댓글 $bad', 'createdAt': now + 6000});
    await host(t, const BoardTab());
    expect(seen(bad), isFalse, reason: '게시판 목록에 욕이 그대로 보인다');

    await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: const PostScreen(postId: 'pbad')));
    await t.pumpAndSettle();
    expect(seen(bad), isFalse, reason: '글 안·댓글에 욕이 그대로 보인다');
    expect(seen('댓글 **'), isTrue);
  });
}
