import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 🚪 밀린 회비가 남은 채 나간 회원 — 나중에 돈을 주면 «받아 적을 곳»이 있어야 한다. (2026-09-26 조사)
   회비 표(FeeSheet.rowMembers)는 그 사람을 일부러 남겨 «받을 돈»을 보여 주는데,
   현황 목록·미납 셈(unpaidMonths)은 지금 회원만 봐서 받아 적을 길이 없었다.
   · 미납은 들어온 달 ~ 나간 달까지만 (나간 뒤는 낼 까닭이 없다)
   · 받을 때도 그 안에서만 채운다 (앞으로 달을 채우면 없는 선납이 생긴다) */
void main() {
  final st = AppState.i;
  final now = DateTime.now();
  int ms(int monthsAgo) => DateTime(now.year, now.month - monthsAgo, 5).millisecondsSinceEpoch;
  String ym(int monthsAgo) {
    final d = DateTime(now.year, now.month - monthsAgo, 1);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  setUp(() {
    st.profile = {'code': 'C', 'slot': 'u1', 'name': '김총무'};
    st.setCouple({
      'fee': {'amount': 20000},
      'members': {
        'u1': {'uid': 'u1', 'name': '김총무', 'role': 'owner', 'joinedAt': ms(12)},
      },
      'former': {
        // 5달 전 들어와 2달 전 나감 → 5·4·3·2달 전 4달치가 밀림(그중 4달 전은 냄)
        'gone': {'uid': 'gone', 'name': '박나감', 'joinedAt': ms(5), 'leftAt': ms(2)},
        // 폰만 바꾼 사람은 «나간 회원»이 아니다
        'moved': {'uid': 'moved', 'name': '이폰', 'movedTo': 'u1', 'joinedAt': ms(5), 'leftAt': ms(2)},
      },
    });
    st.setItems(Store.tidy([
      {'id': 'p', 'type': 'ledger', 'kind': 'in', 'payer': 'gone', 'amount': 20000,
       'feeMonths': [ym(4)], 'date': '${ym(4)}-05'},
    ]));
  });

  test('나간 회원의 미납은 들어온 달~나간 달까지만', () {
    expect(Logic.unpaidMonths('gone'), [ym(5), ym(3), ym(2)]);
  });

  test('받을 때도 그 안에서만 채운다 — 없는 선납을 만들지 않는다', () {
    expect(Logic.feeMonthsToFill('gone', 12), [ym(5), ym(3), ym(2)]);
  });

  test('받을 사람 목록 — 밀린 게 있는 나간 회원만, 폰만 바꾼 사람은 빼고', () {
    expect(Logic.formerDebtors().map((m) => m['uid']), ['gone']);
  });

  test('회비 화면이 나간 회원 줄을 싣는다', () {
    final s = File('lib/ui/wallet.dart').readAsStringSync();
    expect(s, contains('Logic.formerDebtors()'));
    expect(s, contains('나간 회원'));
  });
  testWidgets('회비 화면에 «나간 회원» 줄과 회비 등록 단추가 실제로 그려진다', (t) async {
    await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: const Scaffold(body: WalletTab())));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('박나감 (나간 회원)'), 200);
    expect(find.text('박나감 (나간 회원)'), findsOneWidget);
    expect(find.textContaining('3달 밀림'), findsOneWidget);
    expect(find.text('이폰 (나간 회원)'), findsNothing, reason: '폰만 바꾼 사람');
  });
}
