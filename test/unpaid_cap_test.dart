import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 🧾 「밀린 달」은 **12달까지만** 센다. 그런데 화면이 그냥 「12달 밀림」이라고 하면
   총무는 **그게 전부인 줄 안다** — 실제로는 3년치일 수도 있다.
   셈은 그대로 두고(오래된 것까지 세면 회원 줄마다 느려진다) **말만 맞춘다.** */
void main() {
  int ymOf(DateTime d) => d.year * 12 + d.month - 1;
  String ymKey(int ym) =>
      '${ym ~/ 12}-${(ym % 12 + 1).toString().padLeft(2, '0')}';
  final nowYm = ymOf(DateTime.now());

  /// [joinedMonthsAgo] 달 전에 들어온 회원 + [paidMonths] 만 낸 상태로 꾸민다
  void seed({required int joinedMonthsAgo, List<String> paidMonths = const [], int fee = 20000}) {
    final joined = DateTime(DateTime.now().year, DateTime.now().month - joinedMonthsAgo, 1);
    AppState.i.couple = Store.tidyCouple({
      'fee': {'amount': fee},
      'members': {
        'u1': {'uid': 'u1', 'name': '갑', 'joinedAt': joined.millisecondsSinceEpoch}
      },
    });
    AppState.i.setItems(Store.tidy([
      for (var i = 0; i < paidMonths.length; i++)
        {
          'id': 'l$i', 'type': 'ledger', 'kind': 'in', 'amount': fee,
          'payer': 'u1', 'feeMonths': [paidMonths[i]], 'date': '${paidMonths[i]}-05'
        }
    ]));
  }

  test('한도까지 세는 것 자체는 그대로다', () {
    /* ⚠️ `unpaidMonths().length == unpaidMaxBack` 으로만 보면 **동어반복**이다 —
       상수를 바꿔도 양쪽이 같이 바뀌어 그냥 통과한다(처음에 그렇게 틀렸다).
       그래서 «값 자체»를 못 박는다. 바꾸려면 이 시험도 같이 고치면서
       화면 문구(「N달 이상 밀림」)가 여전히 맞는지 다시 보게 된다. */
    expect(Logic.unpaidMaxBack, 12,
        reason: '거슬러 보는 달 수가 달라졌다 — 화면 문구도 다시 봐야 한다');
    seed(joinedMonthsAgo: 36);
    expect(Logic.unpaidMonths('u1').length, 12);
  });

  test('3년째 안 낸 회원은 «이상»이라고 말해야 한다', () {
    seed(joinedMonthsAgo: 36);
    expect(Logic.unpaidTruncated('u1'), isTrue,
        reason: '실제로는 36달인데 「12달 밀림」이라고만 하면 총무가 그게 전부인 줄 안다');
  });

  test('창 «바로 앞» 달을 냈으면 12달이 정확한 값이다', () {
    seed(joinedMonthsAgo: 36, paidMonths: [ymKey(nowYm - Logic.unpaidMaxBack)]);
    expect(Logic.unpaidTruncated('u1'), isFalse,
        reason: '그 앞을 낸 사람에게까지 「이상」이라고 하면 거짓말이 된다');
  });

  test('들어온 지 얼마 안 된 회원에게는 «이상»을 안 붙인다', () {
    seed(joinedMonthsAgo: 3);
    expect(Logic.unpaidMonths('u1').length, 4); // 이번 달 포함
    expect(Logic.unpaidTruncated('u1'), isFalse,
        reason: '들어오기 «전» 달까지 밀린 것으로 몰면 안 된다');
  });

  test('회비를 안 걷는 모임에는 붙일 말이 없다', () {
    seed(joinedMonthsAgo: 36, fee: 0);
    expect(Logic.unpaidTruncated('u1'), isFalse);
  });

  test('가입일을 모르는 옛 회원은 «단정하지 않는다»', () {
    AppState.i.couple = Store.tidyCouple({
      'fee': {'amount': 20000},
      'members': {
        'u1': {'uid': 'u1', 'name': '갑'} // joinedAt 없음
      },
    });
    AppState.i.setItems([]);
    expect(Logic.unpaidTruncated('u1'), isFalse);
  });

  test('두 화면 모두 그 말을 «보여 준다»', () {
    for (final f in const ['lib/ui/home.dart', 'lib/ui/wallet.dart']) {
      final s = File(f)
          .readAsStringSync()
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
          .replaceAll(RegExp(r'//.*'), '');
      expect(s, contains('Logic.unpaidTruncated('),
          reason: '$f 가 「12달 밀림」이라고만 한다 — '
              '3년치가 밀린 회원도 12달로 보여 총무가 그게 전부인 줄 안다');
      expect(s, contains("' 이상'"), reason: '$f 가 «이상»을 안 붙인다');
    }
  });
}
