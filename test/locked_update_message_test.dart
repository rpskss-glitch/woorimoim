import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🔒 잠긴 모임에서 «고치기»가 거절될 때 — 잠겼다고 말한다. (2026-09-25 조사)
   서버 규칙은 잠긴 모임의 «고치기(update)»를 막는다(지우기는 된다 — firestore.rules clubPaid).
   그런데 아래 자리들은 실패를 「다시 시도해주세요」로만 말해, 인터넷 탓인 줄 알고 되풀이해 눌렀다.
   saveFailToast 는 잠겼으면 잠긴 까닭을, 아니면 원래 말을 보여 준다. */
void main() {
  String body(String file, String from, String to) {
    final s = File(file).readAsStringSync();
    final a = s.indexOf(from);
    expect(a, greaterThanOrEqualTo(0), reason: '$file: $from');
    return s.substring(a, s.indexOf(to, a + from.length));
  }

  test('대화 투표하기', () {
    final b = body('lib/ui/chat.dart', 'Future<void> _vote(int i)', 'Future<void> _setClosed(');
    expect(b.contains("toast(context, '투표하지 못했어요"), isFalse);
    expect(b, contains("saveFailToast(context, '투표하지 못했어요"));
  });

  test('투표 마감·다시 열기', () {
    final b = body('lib/ui/chat.dart', 'Future<void> _setClosed(', '@override');
    expect(b.contains("toast(context, '바꾸지 못했어요"), isFalse);
  });

  test('반복 모임 그만하기', () {
    final s = File('lib/ui/calendar.dart').readAsStringSync();
    expect(s.contains("toast(context, '바꾸지 못했어요 — 다시 시도해주세요')"), isFalse);
  });

  test('게시판 고정', () {
    final s = File('lib/ui/board.dart').readAsStringSync();
    // 실패 쪽만 — 성공 알림(「고정했어요」)은 그대로 toast 가 맞다
    expect(RegExp(r"[^l]toast\(context, pinned\s*\? '고정을 풀지 못했어요").hasMatch(s), isFalse);
    expect(s, contains('saveFailToast(context, pinned'));
  });

  test('신고 «처리 끝»', () {
    final b = body('lib/ui/members.dart', 'Future<void> _closeReport(', 'Future<void> _removeReported(');
    expect(b.contains("toast(context, '처리하지 못했어요"), isFalse);
  });
}
