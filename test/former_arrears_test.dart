import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee_sheet.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';

/* 🚪 넉 달 밀린 회원을 내보내도, 밀린 회비가 회비 표에서 사라지면 안 된다.

   2026-09-25 조사: 내보낼 때 남기는 기록(former)에 이름·아바타만 옮겼다.
   회비 표는 «언제 들어왔는지»를 모르면 이번 달에 든 것으로 보아 그전 달을 모두 «가입 전»으로 뺐다
   → 내보내는 순간 밀린 회비가 표에서 조용히 사라졌다(총무가 받을 돈이 묻혔다).
   ⚠️ 예전 시험은 former 에 joinedAt 을 «넣어서» 만들었다 — 실제 앱은 안 넣었는데.
      그래서 여기서는 **앱이 실제로 적는 모양 그대로** 만든다. */
void main() {
  final st = AppState.i;
  final now = DateTime.now();
  int monthsAgo(int n) => DateTime(now.year, now.month - n, 3).millisecondsSinceEpoch;
  final months = [for (var i = 3; i >= 0; i--) Logic.ymKey(Logic.ymOf(now) - i)];

  final member = {
    'uid': 'u_kim',
    'name': '김밀림',
    'emoji': '🙂',
    'role': 'member',
    'joinedAt': monthsAgo(6),
    'feeFree': [months.first], // 넉 달 전 한 달은 면제해 줬다
  };

  // 앱이 내보낼 때 실제로 적는 모양 (members.dart _kick 과 같게)
  Map<String, dynamic> formerAsAppWrites({required bool carry}) => {
        'uid': 'u_kim',
        'name': '김밀림',
        'emoji': '🙂',
        'leftAt': now.millisecondsSinceEpoch,
        if (carry) ...Logic.feeCarry(member),
      };

  void seed(Map<String, dynamic> former) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'title': '모임',
      'fee': {'amount': 10000},
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': 'owner', 'joinedAt': monthsAgo(24)},
      },
      'former': {'u_kim': former},
    });
    st.setItems([]);
  }

  tearDown(() {
    st.setCouple({});
    st.setItems([]);
  });

  test('내보낸 뒤에도 밀린 회원이 회비 표에 남는다', () {
    seed(formerAsAppWrites(carry: true));
    final rows = FeeSheet.rowMembers(months);
    expect(rows.any((r) => r['uid'] == 'u_kim'), isTrue,
        reason: '넉 달 밀린 회원을 내보냈더니 표에서 사라졌다 — 받을 돈이 묻힌다');
    expect(FeeSheet.mark('u_kim', months[1]), FeeMark.unpaid,
        reason: '들어온 뒤의 달인데 «가입 전»으로 빠졌다');
  });

  test('면제해 준 달은 나간 뒤에도 면제다', () {
    seed(formerAsAppWrites(carry: true));
    expect(FeeSheet.mark('u_kim', months.first), FeeMark.exempt,
        reason: '내보내면서 면제가 사라지면 안 낸 달로 둔갑한다');
  });

  test('(예전 모양) 들어온 때를 안 옮기면 밀린 달이 «가입 전»으로 빠졌다 — 이 시험이 무엇을 막는지', () {
    seed(formerAsAppWrites(carry: false));
    // 이번 달만 미납으로 남고, 그전 달은 모두 «가입 전» — 넉 달 밀린 것이 한 달로 줄었다
    expect(FeeSheet.mark('u_kim', months[1]), FeeMark.before);
  });

  test('나가는 두 길(내보내기·내 자료 지우기) 모두 옮긴다', () {
    expect(File('lib/ui/members.dart').readAsStringSync(), contains('Logic.feeCarry(m)'));
    expect(File('lib/store.dart').readAsStringSync(), contains('Logic.feeCarry(me)'));
  });

  test('옮기는 값 — 있는 것만, 셈에 필요한 것만', () {
    expect(Logic.feeCarry(null), isEmpty);
    expect(Logic.feeCarry({'name': 'x', 'role': 'admin'}), isEmpty, reason: '권한까지 옮기면 안 된다');
    expect(Logic.feeCarry({'joinedAt': 5, 'joinFee': 'paid', 'feeFree': ['2026-01']}),
        {'joinedAt': 5, 'joinFee': 'paid', 'feeFree': ['2026-01']});
  });
}
