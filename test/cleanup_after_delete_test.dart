import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🧹 지운 «뒤처리»가 화면이 사라졌다는 이유로 건너뛰어졌다 (2026-09-26 79회차).

   게시판 글·장부 줄은 **목록의 한 칸**이 스스로 지우기를 부른다. 그런데 진짜 서버에서는
   지우는 순간 기기 사본에서 먼저 빠져(서버 답보다 먼저) 목록이 다시 그려지고, 그 칸이 사라진다.
   그 뒤에 `if (!context.mounted) return;` 을 만나면 **뒤처리를 통째로 건너뛴다**:
     · 게시판 글 — 사진 원본(보관료만 나감)과 딸린 댓글(주인 없는 댓글)이 서버에 남는다
     · 장부 줄  — 영수증 원본이 남고, 가입비 「받음」 표시가 안 풀려 가입비 단추가 다시 안 뜬다(22회차 고침이 무력)
   체험 모드는 지우기가 즉시 끝나 칸이 아직 살아 있어서 **체험·에뮬레이터로는 안 보였다.**
   → 뒤처리는 화면과 상관없는 일이라 «화면이 살아 있는지» 묻기 «전»에 한다. */
void main() {
  String between(String path, String from, String to) {
    final s = File(path).readAsStringSync();
    final a = s.indexOf(from);
    expect(a, greaterThan(0), reason: '$path: $from');
    final b = s.indexOf(to, a);
    expect(b, greaterThan(a), reason: '$path: $to');
    return s.substring(a, b);
  }

  test('게시판 글 — 사진·댓글 치우기가 화면 확인보다 먼저', () {
    final gap = between('lib/ui/board.dart', "deleteItem(code, item['id'] as String, 'diary')",
        'Comments.removeAllOf(');
    expect(gap.contains('!context.mounted) return'), isFalse, reason: '칸이 사라지면 댓글·사진이 남는다');
    final gap2 = between('lib/ui/board.dart', "deleteItem(code, item['id'] as String, 'diary')",
        'Store.i.dropPhotos(');
    expect(gap2.contains('!context.mounted) return'), isFalse);
  });

  test('장부 줄 — 영수증 치우기·가입비 표시 풀기가 화면 확인보다 먼저', () {
    final gap = between('lib/ui/wallet.dart', "deleteItem(code, id, 'ledger')",
        "'members.\$payer.joinFee': null");
    expect(gap.contains('!context.mounted) return'), isFalse, reason: '가입비 단추가 영영 안 돌아온다');
    final gap2 = between('lib/ui/wallet.dart', "deleteItem(code, id, 'ledger')", 'Store.i.dropPhotos(');
    expect(gap2.contains('!context.mounted) return'), isFalse);
  });
}
