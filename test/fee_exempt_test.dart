import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee_sheet.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';

/* 🙇 회비 표의 «면제·가입 전·탈퇴 후», 그리고 탈퇴 미납자.

   ⚠️ 표와 회비 화면이 «같은 말»을 해야 한다 — 표는 「면」인데 화면은 「밀림」이면
      회원은 어느 쪽을 믿어야 할지 모른다. 그래서 면제를 Logic 한 곳에 둔다. */
void main() {
  final st = AppState.i;
  final now = DateTime(2026, 8, 15);
  String ym(int back) => Logic.ymKey(Logic.ymOf(now) - back);

  void seed(Map<String, dynamic> members, {List items = const []}) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'title': '모임',
      'fee': {'amount': 10000},
      'members': members,
    });
    st.setItems(List<Map<String, dynamic>>.from(items));
  }

  int at(int back) =>
      DateTime(2026, 8 - back, 1).millisecondsSinceEpoch;

  tearDown(() {
    st.setCouple({});
    st.setItems([]);
  });

  test('면제한 달은 표에서 «면», 밀린 셈에서도 빠진다', () {
    seed({
      'a': {'uid': 'a', 'name': '가', 'joinedAt': at(6), 'feeFree': [ym(1)]},
    });
    expect(FeeSheet.mark('a', ym(1)), FeeMark.exempt);
    expect(FeeSheet.cell(FeeSheet.mark('a', ym(1))), '면');
    expect(Logic.unpaidMonths('a').contains(ym(1)), isFalse,
        reason: '면제한 달이 아직 「밀림」으로 남았다 — 표와 화면이 다른 말을 한다');
    // 앞뒤 달은 그대로 미납
    expect(FeeSheet.mark('a', ym(0)), FeeMark.unpaid);
  });

  test('가입 전은 «빈칸», 미납(−)과 글자가 갈린다', () {
    seed({'a': {'uid': 'a', 'name': '가', 'joinedAt': at(2)}});
    expect(FeeSheet.mark('a', ym(5)), FeeMark.before);
    expect(FeeSheet.cell(FeeSheet.mark('a', ym(5))), '');
    expect(FeeSheet.cell(FeeSheet.mark('a', ym(0))), '−');
  });

  test('나간 다음 달부터는 «셀 것이 없다» — 나간 달까지는 낸다', () {
    seed({
      'z': {'uid': 'z', 'name': '지', 'joinedAt': at(6), 'leftAt': at(2)},
    });
    // 나간 달(2달 전)까지는 내야 할 달
    expect(FeeSheet.mark('z', ym(2)), FeeMark.unpaid);
    // 그 다음 달부터는 after
    expect(FeeSheet.mark('z', ym(1)), FeeMark.after);
    expect(FeeSheet.cell(FeeSheet.mark('z', ym(1))), '');
  });

  test('탈퇴자도 «미납이 남으면» 표 줄에 들어온다', () {
    seed(
      {'a': {'uid': 'a', 'name': '가', 'joinedAt': at(6)}},
    );
    // former 로 옮긴 탈퇴자 — 나가기 전 달에 미납이 있다
    st.setCouple({
      'title': '모임',
      'fee': {'amount': 10000},
      'members': {'a': {'uid': 'a', 'name': '가', 'joinedAt': at(6)}},
      'former': {
        'z': {'uid': 'z', 'name': '지', 'joinedAt': at(6), 'leftAt': at(1)},
      },
    });
    final months = FeeSheet.monthKeys(6, now: now);
    final rows = FeeSheet.rowMembers(months);
    final ids = rows.map((m) => m['uid']).toList();
    expect(ids.contains('z'), isTrue, reason: '미납 남은 탈퇴자가 표에서 사라졌다 — 받을 돈이 묻힌다');
    expect(rows.firstWhere((m) => m['uid'] == 'z')['left'], isTrue);
  });

  test('다 낸 탈퇴자는 표에 안 남는다 (표가 지난 회원으로 안 찬다)', () {
    final months = FeeSheet.monthKeys(6, now: now);
    final paid = [
      for (final m in months)
        {'type': 'ledger', 'kind': 'in', 'payer': 'z', 'amount': 10000,
         'feeMonths': [m], 'date': '$m-05'}
    ];
    st.setCouple({
      'title': '모임',
      'fee': {'amount': 10000},
      'members': {'a': {'uid': 'a', 'name': '가', 'joinedAt': at(6)}},
      'former': {
        'z': {'uid': 'z', 'name': '지', 'joinedAt': at(6), 'leftAt': at(0)},
      },
    });
    st.setItems(List<Map<String, dynamic>>.from(paid));
    final rows = FeeSheet.rowMembers(months);
    expect(rows.map((m) => m['uid']).contains('z'), isFalse);
  });
}
