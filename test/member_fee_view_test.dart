import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 💵 일반 회원의 「내 회비」 — 총무 화면과 같은 말, 설명서와 같은 말. (2026-09-26 조사)
   · 12달 넘게 밀려도 「12달 밀렸어요」라고만 했다(총무 화면은 「12달 이상」).
   · 회원 설명서가 「표(📋)에서 ○는 낸 달…」을 설명했는데, 일반 회원은 표를 열 수 없다(회장·총무만).
   · 설명서의 「밀린 것 없음」은 회원 화면 글과 달랐다(화면은 「밀린 회비가 없어요」). */
void main() {
  final w = File('lib/ui/wallet.dart').readAsStringSync();
  final at = w.indexOf('if (!st.isTreasurer) {');
  final mine = w.substring(at, w.indexOf('// 총무·방장 — 전원 납부 명단', at));

  test('내 회비도 12달 넘게 밀렸으면 «이상»을 붙인다', () {
    expect(mine, contains('Logic.unpaidTruncated(Store.i.myUid)'));
  });

  test('설명서가 회원이 못 여는 표를 설명하지 않고, 화면 글과 같은 말을 쓴다', () {
    final g = File('lib/ui/member_guide.dart').readAsStringSync();
    expect(g.contains("표(📋)에서 ○는 낸 달"), isFalse);
    expect(g.contains('「밀린 것 없음」'), isFalse);
    expect(g, contains('밀린 회비가 없어요'));
  });
}
