import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee.dart';
import 'package:woorimoim/fee_sheet.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';

/* 🔍 오늘 새로 짠 «가입비·면제·탈퇴 표» 로직의 가장자리 경우.
   화면에서는 안 눌러 보는 조합들을 여기서 캔다. */
void main() {
  final st = AppState.i;
  final now = DateTime(2026, 8, 15);
  String ym(int back) => Logic.ymKey(Logic.ymOf(now) - back);
  int at(int back) => DateTime(2026, 8 - back, 1).millisecondsSinceEpoch;

  tearDown(() {
    st.setCouple({});
    st.setItems([]);
  });

  void couple(Map<String, dynamic> extra) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({'title': '모임', 'fee': {'amount': 10000}, ...extra});
  }

  test('낸 달을 면제로 잡아도 «냈다»가 이긴다 (돈이 사라지면 안 된다)', () {
    couple({
      'members': {
        'a': {'uid': 'a', 'name': '가', 'joinedAt': at(6), 'feeFree': [ym(1)]},
      },
    });
    // ym(1) 달치를 실제로 받은 기록이 있다
    st.setItems([
      {'type': 'ledger', 'kind': 'in', 'payer': 'a', 'amount': 10000,
       'feeMonths': [ym(1)], 'date': '${ym(1)}-05'}
    ]);
    expect(FeeSheet.mark('a', ym(1)), FeeMark.paid,
        reason: '냈는데 면제로 보이면 통장과 표가 안 맞는다');
  });

  test('가입비 금액을 0으로 되돌리면 «아직»이던 사람도 단추가 사라진다', () {
    couple({
      'fee': {'amount': 10000, 'joinAmount': 0},
      'members': {'a': {'uid': 'a', 'name': '가'}},
    });
    expect(Fee.joinPending('a'), isFalse);
    expect(Fee.joinOn, isFalse);
  });

  test('탈퇴 전 미납 달은 표에 남고, 탈퇴 다음 달부터는 «셀 것 없음»', () {
    couple({
      'members': {'me': {'uid': 'me', 'name': '나', 'role': 'owner', 'joinedAt': at(6)}},
      'former': {
        'z': {'uid': 'z', 'name': '지', 'joinedAt': at(6), 'leftAt': at(2)},
      },
    });
    // 나가기 전(3·2달 전)은 미납으로 남아야
    expect(FeeSheet.mark('z', ym(3)), FeeMark.unpaid);
    expect(FeeSheet.mark('z', ym(2)), FeeMark.unpaid); // 나간 달까지 낸다
    // 나간 다음 달부터
    expect(FeeSheet.mark('z', ym(1)), FeeMark.after);
    expect(FeeSheet.mark('z', ym(0)), FeeMark.after);
    // 표 줄에 든다 (미납이 있으므로)
    final months = FeeSheet.monthKeys(6, now: now);
    expect(FeeSheet.rowMembers(months).any((m) => m['uid'] == 'z'), isTrue);
  });

  test('폰만 바꾼 탈퇴자(movedTo)는 표에 «두 줄»로 안 나온다', () {
    couple({
      'members': {'new': {'uid': 'new', 'name': '가', 'joinedAt': at(6)}},
      'former': {
        'old': {'uid': 'old', 'name': '가', 'joinedAt': at(6),
                'leftAt': at(1), 'movedTo': 'new'},
      },
    });
    final months = FeeSheet.monthKeys(6, now: now);
    final ids = FeeSheet.rowMembers(months).map((m) => m['uid']).toList();
    expect(ids.contains('old'), isFalse, reason: '같은 사람이 두 줄이 됐다');
    expect(ids.contains('new'), isTrue);
  });

  test('면제 달은 회비 받을 때 «채우지 않는다» (안 받은 돈이 통장에 들어가면 안 된다)', () {
    couple({
      'members': {'a': {'uid': 'a', 'name': '가', 'joinedAt': at(3), 'feeFree': [ym(1)]}},
    });
    // 3달치를 받으려 하면, 면제한 ym(1)은 건너뛴다
    final fill = Logic.feeMonthsToFill('a', 3);
    expect(fill.contains(ym(1)), isFalse, reason: '면제한 달에 돈을 채웠다');
  });

  test('가입한 달도 내야 하는 달 — 미납으로 잡힌다', () {
    couple({
      'members': {'a': {'uid': 'a', 'name': '가', 'joinedAt': at(0)}},
    });
    // 이번 달 가입, 안 냄 → 미납
    expect(FeeSheet.mark('a', ym(0)), FeeMark.unpaid);
    // 지난달은 가입 전
    expect(FeeSheet.mark('a', ym(1)), FeeMark.before);
  });
}
