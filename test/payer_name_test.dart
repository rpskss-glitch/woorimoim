import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 💰 지출의 「누가 냈나」 칸.

   이 앱에는 고르는 칸이 없다 — 모임 통장에서 나간 것이 전제다. 그래도 **비워 두면 안 된다.**
   같은 Firestore 를 보는 웹은 이 칸을 그대로 그리는데, 비어 있으면
   `nameOf(undefined)` 가 「탈퇴한 회원」을 돌려준다 →
   **앱에서 적은 지출이 웹에서 전부 「탈퇴한 회원이 결제」로 보인다.**
   웹이 쓰는 말과 «글자 하나까지» 같아야 하므로 웹 파일과 대조한다. */
void main() {
  String bare(String p) => File(p)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  test('앱이 적는 지출에 «누가 냈나»가 들어 있다', () {
    final s = bare('lib/ui/wallet.dart');
    final at = s.indexOf("'kind': 'out'");
    expect(at, greaterThan(0), reason: '지출을 적는 곳을 못 찾았다');
    // 그 addItem 의 묶음만 본다 (다음 것으로 새지 않게)
    final end = s.indexOf('});', at);
    expect(s.substring(at, end), contains("'payer': Store.walletPayer"),
        reason: '지출에 「누가 냈나」가 빠졌다 — '
            '웹에서 이 기록이 「탈퇴한 회원이 결제」로 보인다');
  });

  test('그 말이 «웹과 똑같다»', () {
    final web = File('../앞산배드민턴/index.html');
    if (!web.existsSync()) return; // 웹 파일이 없는 곳에서는 넘어간다
    final t = web.readAsStringSync();
    expect(t, contains("payer !== '${Store.walletPayer}'"),
        reason: '웹이 「회비통장」을 가리키는 말이 바뀌었다 — '
            'Store.walletPayer 도 같이 맞춰야 한다');
    expect(t, contains("=== '${Store.walletPayer}') return '회비'"),
        reason: '웹이 이 값을 「회비」로 읽는 자리가 사라졌다');
  });

  test('「회비통장」을 회원으로 세지 않는다', () {
    final now = DateTime.now();
    final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'u1': {'uid': 'u1', 'name': '갑', 'joinedAt': 1690000000000}
      },
      'fee': {'amount': 20000},
    });
    AppState.i.setItems([
      // 「회비통장」 이름으로 들어온 돈 — 사람이 낸 회비가 아니다
      {'id': 'a', 'type': 'ledger', 'kind': 'in', 'amount': 50000,
       'payer': Store.walletPayer, 'date': '$ym-01'},
    ]);
    expect(Logic.paidIn(Store.walletPayer, ym), isFalse,
        reason: '「회비통장」이 회비를 낸 «사람»으로 세어졌다');
    // 진짜 회원은 여전히 미납이어야 한다 (통장 기록이 남의 회비를 메우면 안 된다)
    expect(Logic.unpaidMonths('u1'), contains(ym));
  });

  test('사람이 낸 회비는 그대로 센다 — 거르기가 너무 넓지 않다', () {
    final now = DateTime.now();
    final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'u1': {'uid': 'u1', 'name': '갑', 'joinedAt': 1690000000000}
      },
      'fee': {'amount': 20000},
    });
    AppState.i.setItems([
      {'id': 'b', 'type': 'ledger', 'kind': 'in', 'amount': 20000,
       'payer': 'u1', 'date': '$ym-05'},
    ]);
    expect(Logic.paidIn('u1', ym), isTrue);
    expect(Logic.unpaidMonths('u1'), isNot(contains(ym)));
  });
}
