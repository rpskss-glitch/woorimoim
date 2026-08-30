import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee.dart';
import 'package:woorimoim/state.dart';

/* 💵 「가입비」 — 한 번만 받는 돈. 회비(달마다)와 섞이면 안 된다.

   여기서 지키는 것
     ① 금액 0 = 안 받는 모임 → 단추가 아예 안 뜬다
     ② 낸 사람·면제한 사람에게는 단추가 다시 안 뜬다 (한 번짜리)
     ③ 돈은 «회원 칸»에 적힌다 — 달을 붙일 수 없으니 장부 달 셈을 건드리면 안 된다 */
void main() {
  final st = AppState.i;

  void seed(Map<String, dynamic> fee, Map<String, dynamic> members) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({'title': '모임', 'fee': fee, 'members': members});
  }

  tearDown(() => st.setCouple({}));

  test('가입비 0이면 «받지 않는» 모임 — 단추를 안 띄운다', () {
    seed({'joinAmount': 0}, {'a': {'uid': 'a', 'name': '가'}});
    expect(Fee.joinOn, isFalse);
    expect(Fee.joinPending('a'), isFalse, reason: '안 받는 모임인데 가입비 단추가 뜬다');
  });

  test('가입비를 정하면 «아직 안 낸» 회원에게 단추가 뜬다', () {
    seed({'joinAmount': 30000}, {'a': {'uid': 'a', 'name': '가'}});
    expect(Fee.joinOn, isTrue);
    expect(Fee.joinAmount(), 30000);
    expect(Fee.joinPending('a'), isTrue);
    expect(Fee.joinStateOf('a'), '');
  });

  test('낸 사람·면제한 사람에게는 단추가 다시 안 뜬다', () {
    seed({'joinAmount': 30000}, {
      'a': {'uid': 'a', 'name': '가', 'joinFee': 'paid'},
      'b': {'uid': 'b', 'name': '나', 'joinFee': 'free'},
      'c': {'uid': 'c', 'name': '다'},
    });
    expect(Fee.joinPending('a'), isFalse, reason: '이미 낸 사람에게 또 받으려 한다');
    expect(Fee.joinPending('b'), isFalse, reason: '면제한 사람에게 또 묻는다');
    expect(Fee.joinPending('c'), isTrue);
    expect(Fee.joinStateOf('a'), 'paid');
    expect(Fee.joinStateOf('b'), 'free');
  });

  test('엉뚱한 값이 들어와도 «아직»으로 본다 (안전한 쪽)', () {
    seed({'joinAmount': 30000}, {
      'a': {'uid': 'a', 'name': '가', 'joinFee': 123},
      'b': {'uid': 'b', 'name': '나', 'joinFee': 'yes'},
    });
    expect(Fee.joinStateOf('a'), '');
    expect(Fee.joinStateOf('b'), '');
    expect(Fee.joinPending('a'), isTrue);
  });
}
