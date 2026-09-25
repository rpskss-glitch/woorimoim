import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 🏦 홈 「이번 달 회비」 — 이번 달을 면제받은 회원은 «미납»이 아니다. (2026-09-26 조사)
   회비 표는 그 달을 「면」으로 그리는데, 홈 카드는 면제 회원을 「미납: …」 명단에 넣고
   「2/6명」의 전체 수에도 셌다 — 다쳐서 면제받은 분이 매달 홈에서 안 낸 사람으로 보였다. */
void main() {
  final st = AppState.i;
  final now = DateTime.now();
  final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';

  setUp(() {
    st.profile = {'code': 'C', 'slot': 'a', 'name': '가'};
    st.setCouple({
      'fee': {'amount': 20000},
      'members': {
        'a': {'uid': 'a', 'name': '가', 'role': 'owner', 'joinedAt': 1},
        'b': {'uid': 'b', 'name': '나', 'role': 'member', 'joinedAt': 1, 'feeFree': [month]},
        'c': {'uid': 'c', 'name': '다', 'role': 'member', 'joinedAt': 1},
      },
    });
    st.setItems(Store.tidy([
      {'id': 'x', 'type': 'ledger', 'kind': 'in', 'payer': 'a', 'amount': 20000,
       'feeMonths': [month], 'date': '$month-01'},
    ]));
  });

  test('이번 달 낼 사람 = 면제 안 받은 사람', () {
    final due = Logic.monthDue(st.memberList, month);
    expect(due.map((m) => m['uid']), ['a', 'c']);
  });

  test('홈 카드가 이 규칙을 쓴다', () {
    final s = File('lib/ui/home.dart').readAsStringSync();
    final at = s.indexOf('List<Widget> _feeCard(');
    final body = s.substring(at, at + 900);
    expect(body, contains('Logic.monthDue('));
  });
  test('내가 이번 달 면제면 «안 냈어요»가 아니라 «면제»라고 말한다', () {
    final s = File('lib/ui/home.dart').readAsStringSync();
    expect(s, contains('이번 달은 회비 면제예요'));
  });
}
