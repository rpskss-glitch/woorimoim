import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/comments.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/ui/chat.dart';

/* 💬 대화·댓글·차단 — 2026-09-25 조사에서 나온 것들.

   ① 운영진 방에서 「답장」을 누른 채 모두의 방으로 옮겨 보내면 운영진 대화가 회원들 앞에 인용됐다.
   ② 대화 글자를 복사할 길이 없었다 — 총무가 올린 계좌번호를 받아 적어야 했다.
   ③ 차단한 사람이 마지막에 말하면 채팅 배지 「1」이 안 없어졌다(들어가도 가려져 안 보이니까).
   ④ 차단한 사람의 말이 남의 «답장 인용 띠»로 내 화면에 그대로 떴다.
   ⑤ 게시판 목록은 「댓글 3」, 들어가면 「💬 댓글 2」(차단한 사람 댓글을 목록만 셌다). */
String codeOf(String path) => File(path)
    .readAsStringSync()
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

void main() {
  final st = AppState.i;

  test('① 방을 바꾸면 «답장 중»이 풀린다', () {
    final s = codeOf('lib/ui/chat.dart');
    final at = s.indexOf('onSelectionChanged: (v) {');
    expect(at, greaterThan(0));
    final body = s.substring(at, s.indexOf('},', at));
    expect(body, contains('_replyTo = null;'), reason: '운영진 방 답장이 모두의 방으로 따라간다');
  });

  group('② 글자 복사', () {
    test('글이면 그 글자, 사진·투표·음성이면 없음(메뉴를 안 띄운다)', () {
      expect(msg0Text({'text': ' 신한 110-123-456789 '}), '신한 110-123-456789');
      expect(msg0Text({'kind': 'img', 'text': 'x'}), '');
      expect(msg0Text({'kind': 'poll', 'text': '몇 시?'}), '');
      expect(msg0Text({'kind': 'voice'}), '');
      expect(msg0Text({}), '');
    });
    test('길게 누른 메뉴에 «글자 복사하기»가 있고 실제로 클립보드에 넣는다', () {
      final s = codeOf('lib/ui/chat.dart');
      expect(s, contains("'글자 복사하기'"));
      expect(s, contains('Clipboard.setData(ClipboardData(text: msg0Text(m)))'));
    });
  });

  test('③ 채팅 배지는 차단한 사람의 말을 세지 않는다', () {
    final s = codeOf('lib/ui/shell.dart');
    final at = s.indexOf('int get _unreadChat');
    expect(s.substring(at, at + 300), contains("Moderation.hide(st.by('msg'))"));
  });

  test('④ 답장 인용 띠도 차단한 사람의 말을 가린다', () {
    final s = codeOf('lib/ui/chat.dart');
    expect(s, contains("Moderation.isBlocked(replied['by'] as String?)"));
    expect(s, contains("'↩ 차단한 회원의 대화'"));
  });

  group('⑤ 댓글 수', () {
    tearDown(() {
      st.setCouple({});
      st.setItems([]);
    });

    test('목록의 댓글 수가 글 안과 같다 — 차단한 사람 댓글은 뺀다', () {
      st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
      st.setCouple({
        'members': {
          'me': {'uid': 'me', 'name': '나', 'role': 'member', 'blocked': ['troll']},
          'u2': {'uid': 'u2', 'name': '을', 'role': 'member'},
          'troll': {'uid': 'troll', 'name': '병', 'role': 'member'},
        },
      });
      st.setItems(Store.tidy([
        {'id': 'p1', 'type': 'diary', 'title': '공지', 'text': '...'},
        {'id': 'c1', 'type': Comments.type, 'replyTo': 'p1', 'by': 'u2', 'text': '좋아요', 'createdAt': 1},
        {'id': 'c2', 'type': Comments.type, 'replyTo': 'p1', 'by': 'troll', 'text': '욕', 'createdAt': 2},
        {'id': 'c3', 'type': Comments.type, 'replyTo': 'p1', 'by': 'me', 'text': '넵', 'createdAt': 3},
      ]));
      expect(Comments.of('p1').length, 3, reason: '전제: 자료에는 셋');
      expect(Comments.count('p1'), 2, reason: '목록이 차단한 사람 댓글까지 센다');
    });
  });
}
