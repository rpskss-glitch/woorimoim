import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee_sheet.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 🕛 시간의 모서리 — 자정·월말·연말·윤년.

   회비는 «달»로 센다. 그래서 달이 넘어가는 자리에서 셈이 틀어지면
   회원이 낸 돈이 사라지거나, 안 낸 사람이 낸 것으로 잡힌다.
   총무는 어디서 틀렸는지 못 찾는다.

   ⚠️ 실제로 걸리는 자리들:
      · 12월 → 1월 (해가 바뀐다)
      · 1월 31일에 «한 달 뒤»를 세면 2월 31일이 없다
      · 윤년 2월 29일
      · 자정 직전·직후 */
void main() {
  final st = AppState.i;

  void seed({required int joinedYear, required int joinedMonth,
      List<String> paidMonths = const []}) {
    st.profile = {'code': 'C', 'slot': 'u1', 'name': '나'};
    st.setCouple(Store.tidyCouple({
      'free': true,
      'fee': {'amount': 20000},
      'members': {
        'u1': {
          'uid': 'u1', 'name': '나', 'role': 'owner',
          'joinedAt': DateTime(joinedYear, joinedMonth, 1).millisecondsSinceEpoch,
        },
      },
    }));
    st.setItems(Store.tidy([
      for (final m in paidMonths)
        {
          'id': 'p$m', 'type': 'ledger', 'kind': 'in', 'payer': 'u1',
          'amount': 20000, 'date': '$m-05',
        },
    ]));
  }

  group('달 셈 — 해가 바뀌는 자리', () {
    test('12월 다음은 이듬해 1월이다', () {
      // 달을 정수로 세는 방식(해*12 + 달-1)이 해를 넘길 때도 맞는가
      final dec = Logic.ymOf(DateTime(2026, 12, 15));
      expect(Logic.ymKey(dec), '2026-12');
      expect(Logic.ymKey(dec + 1), '2027-01', reason: '해를 못 넘긴다');
      expect(Logic.ymKey(dec - 11), '2026-01');
      expect(Logic.ymKey(dec - 12), '2025-12', reason: '거꾸로도 해를 넘겨야 한다');
    });

    test('표의 달 머리글이 해를 넘겨도 이어진다', () {
      final ms = FeeSheet.monthKeys(4, now: DateTime(2027, 2, 10));
      expect(ms, ['2026-11', '2026-12', '2027-01', '2027-02']);
    });

    test('12월에 든 회원의 미납이 이듬해로 이어진다', () {
      /* ⚠️ «지난» 12월이라야 한다 — 앞으로 올 12월로 두면 아직 안 든 사람이라
         밀린 달이 하나도 없는 게 맞다(내가 처음에 그렇게 짜서 헛짚었다). */
      final lastDec = DateTime(DateTime.now().year - 1, 12);
      seed(joinedYear: lastDec.year, joinedMonth: 12);
      final un = Logic.unpaidMonths('u1');
      expect(un, isNotEmpty, reason: '지난 12월 가입인데 밀린 달이 하나도 없다');
      final joinKey = '${lastDec.year}-12';
      for (final m in un) {
        expect(m.compareTo(joinKey), greaterThanOrEqualTo(0),
            reason: '가입 전 달($m)을 미납으로 세고 있다');
      }
      // 해를 넘겨 이듬해 1월이 들어 있어야 한다
      expect(un.any((m) => m.startsWith('${lastDec.year + 1}-')), isTrue,
          reason: '해를 넘긴 달이 미납에 없다 — 12월에서 셈이 멈췄다');
    });

    test('💥 «들어온 때를 모를 때» 표와 현황이 같은 말을 한다', () {
      /* 들어온 때를 모를 수 있다: 옛 판이 안 적었거나, 백업을 손으로 고쳤거나,
         적힌 값이 말이 안 되는 때라 다듬기가 뺐거나(폰 시계가 틀린 채로 가입).

         현황 화면은 그때 «이번 달부터»만 센다. 그런데 회비 표는
         «옛 달까지 다 안 낸 것»으로 그렸다 — 새로 든 회원이 표에서
         「열두 달 밀린 사람」이 되어 대화방에 그대로 올라간다.
         (2026-08-29: 표와 현황이 다른 말을 하던 자리가 또 나왔다) */
      st.profile = {'code': 'C', 'slot': 'u1', 'name': '나'};
      st.setCouple(Store.tidyCouple({
        'free': true,
        'fee': {'amount': 20000},
        'members': {
          // joinedAt 이 아예 없다
          'u1': {'uid': 'u1', 'name': '나', 'role': 'member'},
        },
      }));
      st.setItems([]);

      final months = FeeSheet.monthKeys(12, now: DateTime.now());
      final onSheet =
          months.where((m) => FeeSheet.mark('u1', m) == FeeMark.unpaid).toSet();
      final onScreen =
          Logic.unpaidMonths('u1').toSet().intersection(months.toSet());
      expect(onSheet, onScreen,
          reason: '들어온 때를 모를 때 표와 현황이 다른 달을 «안 낸 달»이라 한다');
      expect(onSheet.length, lessThanOrEqualTo(1),
          reason: '언제 들었는지 모르는 사람을 «열두 달 밀린 사람»으로 그린다');
    });

    test('진짜 이상한 앞날은 그대로 걸린다', () {
      // 2099년 같은 값을 «들어온 때»로 받아들이면 회비 셈이 통째로 무너진다
      final farFuture = DateTime(2099).millisecondsSinceEpoch;
      final c = Store.tidyCouple({
        'members': {
          'u1': {'uid': 'u1', 'name': '나', 'role': 'member', 'joinedAt': farFuture},
        },
      });
      final me = (c?['members'] as Map)['u1'] as Map;
      expect(me.containsKey('joinedAt'), isFalse);
    });
  });

  group('말일·윤년', () {
    test('1월 31일 다음 달은 2월이다 (2월 31일이 아니다)', () {
      final jan = Logic.ymOf(DateTime(2027, 1, 31));
      expect(Logic.ymKey(jan + 1), '2027-02');
    });

    test('윤년 2월 29일도 그 달로 센다', () {
      final feb = Logic.ymOf(DateTime(2028, 2, 29)); // 2028은 윤년
      expect(Logic.ymKey(feb), '2028-02');
      expect(Logic.ymKey(feb + 1), '2028-03');
    });

    test('말일에 낸 회비도 그 달 것으로 잡힌다', () {
      seed(joinedYear: 2026, joinedMonth: 1, paidMonths: ['2026-01']);
      // 1월 31일에 낸 것이 1월로 잡히는가 — 날짜만 바꿔 다시 넣는다
      st.setItems(Store.tidy([
        {
          'id': 'p1', 'type': 'ledger', 'kind': 'in', 'payer': 'u1',
          'amount': 20000, 'date': '2026-01-31',
        },
      ]));
      expect(Logic.paidIn('u1', '2026-01'), isTrue,
          reason: '말일에 낸 회비가 그 달로 안 잡힌다 — 낸 사람이 미납이 된다');
    });
  });

  group('여러 달치를 한 번에 낼 때', () {
    test('12월에 3달치를 내면 이듬해 2월까지 채워진다', () {
      seed(joinedYear: 2026, joinedMonth: 12);
      final months = Logic.feeMonthsToFill('u1', 3);
      expect(months.length, 3);
      // 해를 넘겨 이어져야 한다
      expect(months.first.compareTo(months.last), lessThan(0),
          reason: '달이 거꾸로 나열됐다');
      for (var i = 1; i < months.length; i++) {
        final a = months[i - 1].split('-');
        final b = months[i].split('-');
        final gap = (int.parse(b[0]) * 12 + int.parse(b[1])) -
            (int.parse(a[0]) * 12 + int.parse(a[1]));
        expect(gap, 1, reason: '${months[i - 1]} 다음이 ${months[i]} 다 — 달이 건너뛰었다');
      }
    });

    test('이미 낸 달은 건너뛴다 — 돈이 두 번 얹히지 않게', () {
      seed(joinedYear: 2026, joinedMonth: 1, paidMonths: ['2026-02']);
      final months = Logic.feeMonthsToFill('u1', 3);
      expect(months.contains('2026-02'), isFalse,
          reason: '이미 낸 달에 또 얹으면 낸 돈만큼 미납이 안 줄어든다');
    });
  });

  group('선납·미납이 서로 어긋나지 않는다', () {
    test('선납한 사람은 미납이 없다', () {
      final now = DateTime.now();
      final thisMonth = Logic.ymKey(Logic.ymOf(now));
      final next = Logic.ymKey(Logic.ymOf(now) + 1);
      seed(joinedYear: now.year, joinedMonth: now.month,
          paidMonths: [thisMonth, next]);
      expect(Logic.unpaidMonths('u1'), isEmpty,
          reason: '앞으로까지 냈는데 밀렸다고 한다');
      expect(Logic.prepaidLeft('u1'), greaterThanOrEqualTo(1),
          reason: '선납이 안 세어진다');
    });

    test('미납과 표가 같은 달을 가리킨다', () {
      seed(joinedYear: 2026, joinedMonth: 1);
      final months = FeeSheet.monthKeys(12, now: DateTime.now());
      final onSheet =
          months.where((m) => FeeSheet.mark('u1', m) == FeeMark.unpaid).toSet();
      final onScreen = Logic.unpaidMonths('u1').toSet().intersection(months.toSet());
      expect(onSheet, onScreen,
          reason: '표와 현황이 다른 달을 «안 낸 달»이라 한다');
    });
  });

  tearDown(() => st.setItems([]));
}
