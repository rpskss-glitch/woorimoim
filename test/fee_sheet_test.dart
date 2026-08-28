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

  test('낸 달은 ○, 안 낸 달은 빈칸', () {
    seed(joinedAt: msOf('2026-01'), paidMonths: ['2026-07']);
    expect(FeeSheet.mark('u1', '2026-07'), FeeMark.paid);
    expect(FeeSheet.cell(FeeSheet.mark('u1', '2026-07')), '○');
    expect(FeeSheet.mark('u1', '2026-08'), FeeMark.unpaid);
    expect(FeeSheet.cell(FeeSheet.mark('u1', '2026-08')), '');
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

  test('가입한 달은 「가입」으로 표시한다 (사진 속 표와 같게)', () {
    seed(joinedAt: msOf('2026-08'));
    expect(FeeSheet.mark('u1', '2026-08'), FeeMark.joined);
    expect(FeeSheet.cell(FeeSheet.mark('u1', '2026-08')), '가입');
  });

  test('가입한 달에 회비를 냈으면 「가입」이 아니라 ○', () {
    // 가입하자마자 그 달치를 낸 사람이 미납처럼 보이면 안 된다
    seed(joinedAt: msOf('2026-08'), paidMonths: ['2026-08']);
    expect(FeeSheet.mark('u1', '2026-08'), FeeMark.paid);
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
