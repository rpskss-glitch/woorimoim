import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee_sheet.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';

/* 📋 회비 납부 현황표의 «셈».

   이 표는 총무가 대화방에 그대로 올려 회원들이 다 같이 본다.
   그래서 한 칸이 틀리면 **모임 사람들 앞에서 누군가 「안 낸 사람」이 된다** —
   화면 모양보다 이 셈이 먼저다. */
void main() {
  final st = AppState.i;

  void seed({required int joinedAt, List<String> paidMonths = const []}) {
    st.setCouple({
      'fee': {'amount': 20000},
      'members': {
        'u1': {'uid': 'u1', 'name': '김대현', 'joinedAt': joinedAt},
      },
    });
    st.setItems([
      for (final m in paidMonths)
        {
          'id': 'p_$m',
          'type': 'ledger',
          'kind': 'in',
          'payer': 'u1',
          'amount': 20000,
          'feeMonths': [m],
          'date': '$m-05',
        },
    ]);
  }

  int msOf(String ym) {
    final p = ym.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), 15).millisecondsSinceEpoch;
  }

  test('달 머리글은 뒤에서부터 이어진다', () {
    final ms = FeeSheet.monthKeys(3, now: DateTime(2026, 8, 25));
    expect(ms, ['2026-06', '2026-07', '2026-08']);
    expect(FeeSheet.monthLabel('2026-07'), '7월');
  });

  test('낸 달은 ○, 안 낸 달은 −', () {
    seed(joinedAt: msOf('2026-01'), paidMonths: ['2026-07']);
    expect(FeeSheet.mark('u1', '2026-07'), FeeMark.paid);
    expect(FeeSheet.cell(FeeSheet.mark('u1', '2026-07')), '○');
    expect(FeeSheet.mark('u1', '2026-08'), FeeMark.unpaid);
    expect(FeeSheet.cell(FeeSheet.mark('u1', '2026-08')), '−');
  });

  test('«안 낸 달»과 «가입 전 달»은 글자가 달라야 한다', () {
    /* 💥 2026-08-29 화면에서 잡은 버그: 둘 다 빈칸이었다.
       표를 대화방에 올려도 총무가 「누가 안 냈나」를 읽을 수가 없었다 —
       표의 존재 이유가 그건데. */
    seed(joinedAt: msOf('2026-07'), paidMonths: []);
    final unpaid = FeeSheet.cell(FeeSheet.mark('u1', '2026-08'));
    final before = FeeSheet.cell(FeeSheet.mark('u1', '2026-03'));
    expect(unpaid, isNot(before),
        reason: '안 낸 칸과 가입 전 칸이 똑같이 보인다 — 표를 읽을 수가 없다');
    expect(unpaid.trim(), isNotEmpty, reason: '안 낸 칸이 비어 있으면 눈에 안 띈다');
  });

  test('가입 «전» 달은 미납이 아니다', () {
    /* ⚠️ 이걸 미납으로 그리면 이번 달 들어온 새 회원이 표에서
       「반년 밀린 사람」이 되어 대화방에 그대로 올라간다. */
    seed(joinedAt: msOf('2026-08'));
    expect(FeeSheet.mark('u1', '2026-03'), FeeMark.before,
        reason: '가입 전인데 미납으로 셌다');
    expect(FeeSheet.cell(FeeSheet.mark('u1', '2026-03')), '',
        reason: '가입 전 칸에 무언가 찍히면 안 낸 것처럼 보인다');
  });

  test('가입한 달도 «안 냈으면 안 낸 것»이다', () {
    /* 💥 2026-08-29 화면에서 잡은 버그: 가입한 달에 「가입」이라고만 찍어서
       그 달 회비를 안 낸 사람이 표에서 안 낸 것으로 안 보였다.
       가입한 달도 내야 하는 달이다 — 안 그러면 아래 시험(두 화면 대조)이 깨진다. */
    seed(joinedAt: msOf('2026-08'));
    expect(FeeSheet.mark('u1', '2026-08'), FeeMark.unpaid,
        reason: '가입한 달의 미납을 「가입」이 덮고 있다');
  });

  test('가입한 달에 회비를 냈으면 ○', () {
    // 가입하자마자 그 달치를 낸 사람이 미납처럼 보이면 안 된다
    seed(joinedAt: msOf('2026-08'), paidMonths: ['2026-08']);
    expect(FeeSheet.mark('u1', '2026-08'), FeeMark.paid);
  });

  test('🔗 표가 세는 미납과 «현황 화면»이 세는 미납이 같아야 한다', () {
    /* 이번 버그의 뿌리다 — 같은 앱의 두 화면이 서로 다른 말을 했다.
       현황은 「2달 밀림」이라는데 표는 한 달만 안 낸 것처럼 보였다.
       회원에게 올라가는 표가 틀리면 «냈는데 안 냈다»는 소리를 듣게 된다. */
    for (final joinMonth in ['2026-03', '2026-07', '2026-08']) {
      seed(joinedAt: msOf(joinMonth), paidMonths: []);
      final months = FeeSheet.monthKeys(6, now: DateTime(2026, 8, 25));
      final onSheet = months
          .where((m) => FeeSheet.mark('u1', m) == FeeMark.unpaid)
          .toSet();
      // 현황 화면이 쓰는 셈 — 표에 나온 달만 견준다(표는 6달만 보여 준다)
      final onScreen = Logic.unpaidMonths('u1').toSet().intersection(months.toSet());
      expect(onSheet, onScreen,
          reason: '$joinMonth 가입: 표와 현황 화면이 다른 달을 «안 낸 달»이라 한다');
    }
  });

  test('한 달에 몇 명이 냈는지 센다', () {
    seed(joinedAt: msOf('2026-01'), paidMonths: ['2026-07']);
    final members = [
      {'uid': 'u1', 'name': '김대현'}
    ];
    expect(FeeSheet.paidCount(members, '2026-07'), 1);
    expect(FeeSheet.paidCount(members, '2026-08'), 0);
  });

  group('지출 표', () {
    setUp(() {
      st.setCouple({'fee': {'amount': 20000}, 'members': {}});
      st.setItems([
        {'id': 'a', 'type': 'ledger', 'kind': 'out', 'cat': 'court', 'amount': 240000, 'date': '2026-07-03'},
        {'id': 'b', 'type': 'ledger', 'kind': 'out', 'cat': 'court', 'amount': 240000, 'date': '2026-08-03'},
        {'id': 'c', 'type': 'ledger', 'kind': 'out', 'cat': 'shuttle', 'amount': 36000, 'date': '2026-08-10'},
        // 갈래가 없는 지출 — 빠뜨리면 합계가 통장과 안 맞는다
        {'id': 'd', 'type': 'ledger', 'kind': 'out', 'amount': 5000, 'date': '2026-08-11'},
        {'id': 'e', 'type': 'ledger', 'kind': 'in', 'amount': 60000, 'date': '2026-08-05'},
      ]);
    });

    test('갈래별·달별로 모은다', () {
      final t = FeeSheet.outByCat(['2026-07', '2026-08']);
      expect(t['체육관']?['2026-07'], 240000);
      expect(t['체육관']?['2026-08'], 240000);
      expect(t['셔틀콕']?['2026-08'], 36000);
    });

    test('갈래 없는 지출도 「기타」로 반드시 들어간다', () {
      final t = FeeSheet.outByCat(['2026-08']);
      expect(t['기타']?['2026-08'], 5000,
          reason: '빼면 표 합계가 통장 잔액과 안 맞아 총무가 장부를 통째로 뒤진다');
    });

    test('들어온 돈은 달별로 따로 센다', () {
      expect(FeeSheet.inByMonth(['2026-08'])['2026-08'], 60000);
      expect(FeeSheet.inByMonth(['2026-07'])['2026-07'], 0);
    });
  });
}
