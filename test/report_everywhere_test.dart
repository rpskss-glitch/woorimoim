import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🚩 신고·차단은 «회원이 올린 것이 보이는 모든 자리»에 있어야 한다 — 애플 1.2(이용자 생성 콘텐츠).
   2026-09-25 조사: 대화·댓글에만 있었다. **게시판 글과 사진첩 사진은 신고도 차단도 못 했다.**
   게시판 목록의 «…» 메뉴는 내 글이거나 운영진일 때만 떴고, 글 화면·사진 화면엔 아예 없었다.
   (신고함은 대상 종류를 가리지 않으니 받는 쪽은 이미 된다 — 여는 길만 없었다) */
String _strip(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

void main() {
  test('게시판 목록 — 남의 글에 신고·차단이 있다', () {
    final s = _strip(File('lib/ui/board.dart').readAsStringSync());
    expect(s, contains('reportSheet('));
    expect(s, contains('blockSheet('));
    expect(s.contains('if (mine || st.isAdmin)\n                PopupMenuButton'), isFalse,
        reason: '메뉴가 내 글·운영진에게만 떠서 회원은 신고할 길이 없다');
  });

  test('글 화면 — 글 자체에도 신고·차단이 있다(댓글만이 아니라)', () {
    final s = _strip(File('lib/ui/post_screen.dart').readAsStringSync());
    expect(RegExp(r'reportSheet\(').allMatches(s).length, greaterThanOrEqualTo(2),
        reason: '댓글 신고만 있고 글 신고가 없다');
    expect(RegExp(r'blockSheet\(').allMatches(s).length, greaterThanOrEqualTo(2));
  });

  test('사진 한 장 화면 — 남의 사진에 신고·차단이 있다', () {
    final s = _strip(File('lib/ui/album.dart').readAsStringSync());
    expect(s, contains('reportSheet('));
    expect(s, contains('blockSheet('));
    expect(s, contains('Moderation.canBlock('), reason: '내 사진에 «나를 차단»이 뜬다');
  });

  test('신고함에서 글을 지우면 딸린 댓글도 지운다', () {
    final s = _strip(File('lib/ui/members.dart').readAsStringSync());
    final at = s.indexOf('Future<void> _removeReported(');
    final body = s.substring(at, s.indexOf('\n  }\n', at));
    expect(body, contains('Comments.removeAllOf('), reason: '주인 없는 댓글이 영영 남는다');
  });
}
