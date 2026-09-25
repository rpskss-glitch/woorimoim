import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🗑 방 지우기 — 기록 찾기는 «서버에 직접» 묻는다.

   2026-09-25 조사: 그냥 get() 은 연결이 약하면 이 폰에 남은 것으로 답한다. 총괄 폰에는
   남의 모임 기록이 거의 없어 «0건» → 기록은 안 지우고 「방과 기록 0건을 지웠어요」 →
   방 문서만 지워져, 남은 대화·사진·회비 기록에 아무도 손댈 수 없게 됐다(보관 요금만 계속). */
void main() {
  test('기록을 찾을 때 서버에 직접 묻는다 (못 닿으면 던져서 멈춘다)', () {
    final s = File('lib/store.dart').readAsStringSync();
    final at = s.indexOf('Future<int> purgeClubData(');
    final body = s.substring(at, s.indexOf('return done;', at));
    expect(body, contains('GetOptions(source: Source.server)'),
        reason: '기기 캐시로 답하면 «0건»을 믿고 방 문서만 지운다');
  });

  test('콘솔은 기록을 다 지운 «뒤에만» 방 문서를 지운다 (던지면 방 문서는 남는다)', () {
    final a = File('lib/ui/admin.dart').readAsStringSync();
    final at = a.indexOf('Future<void> _delete(');
    final body = a.substring(at, a.indexOf('Future<void> _releaseOwner(', at));
    final purge = body.indexOf('await Store.i.purgeClubData(');
    final couple = body.indexOf('await Store.i.deleteCouple(code);');
    final tryAt = body.indexOf('try {');
    expect(tryAt, lessThan(purge));
    expect(purge, lessThan(couple), reason: '방 문서를 먼저 지우면 기록에 영영 손을 못 댄다');
  });
}
