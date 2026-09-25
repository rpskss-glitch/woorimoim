import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/comments.dart';
import 'package:woorimoim/fee.dart';
import 'package:woorimoim/state.dart';

/* 🔒 이용권이 끝나 잠긴 모임 — «왜 안 되는지»를 말해야 한다. (2026-09-25 조사)
   잠기면 `addItem` 이 조용히 실패를 돌려준다. 그런데 몇 자리는 그걸 «연결 탓»으로 말했다:
     · 대화 보내기  「보내지 못했어요 — 다시 눌러주세요」 (쓴 글도 지웠다가 되돌림)
     · 댓글         「댓글을 남기지 못했어요 — 다시 해주세요」
     · 신고         「신고하지 못했어요 — 잠시 후 다시 해주세요」
     · 여러 명 회비 「기록하지 못했어요」
   회원은 인터넷 문제인 줄 알고 몇 번이고 다시 누른다 — 방장이 결제해야 풀리는 일인데. */
void main() {
  final st = AppState.i;

  setUp(() {
    st.profile = {'code': 'C', 'slot': 'u2', 'name': '박회원'};
    st.setCouple({
      'paidUntil': DateTime(2020, 1, 1).millisecondsSinceEpoch, // 오래전에 끝남
      'members': {
        'u1': {'uid': 'u1', 'name': '김방장', 'role': 'owner'},
        'u2': {'uid': 'u2', 'name': '박회원', 'role': 'member'},
      },
    });
  });

  test('잠긴 모임에서 댓글은 «잠겼다»고 말한다(서버에 보내지도 않는다)', () async {
    expect(Fee.locked, isTrue);
    final why = await Comments.add('p1', '안녕하세요');
    expect(why, Fee.lockedLine, reason: '「다시 해주세요」라고 하면 인터넷 탓인 줄 안다');
  });

  test('대화 보내기 — 쓴 글을 비우기 «전에» 잠김을 본다', () {
    final s = File('lib/ui/chat.dart').readAsStringSync();
    final at = s.indexOf('Future<void> _send(');
    final body = s.substring(at, s.indexOf('Future<void> _sendPhoto(', at));
    final lock = body.indexOf('Store.lockReason()');
    expect(lock, greaterThan(0));
    expect(lock, lessThan(body.indexOf('_textC.clear()')));
  });

  test('신고 실패도 잠김이면 잠김을 말한다', () {
    final s = File('lib/ui/common.dart').readAsStringSync();
    expect(s.contains("if (!ok) return toast(context, '신고하지 못했어요"), isFalse);
    expect(s, contains("saveFailToast(context, '신고하지 못했어요"));
  });

  test('여러 명 회비 — 사람마다 «잠겼다»가 이유로 남는다', () {
    final s = File('lib/fee_book.dart').readAsStringSync();
    expect(s, contains('if (Fee.locked) return FeeReceipt.fail(name, Fee.lockedLine);'));
  });
}
