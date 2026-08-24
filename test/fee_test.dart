import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/fee.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 💳 모임 이용권 — 193회차.

   규칙(사장님 방침):
     · 이용료는 **모임을 만든 사람(방장)**이 낸다. 회원은 한 푼도 안 낸다.
     · 총괄이 만든 방과 면제해 준 방(`free: true`)은 묻지 않는다 — 앞산 배드민턴은 평생 무료.
     · 잠겨도 **읽기는 그대로** 된다. 돈을 안 낸 벌을 회원이 받으면 안 된다.

   ⚠️ `paidUntil` 은 **서버가 영수증을 확인하고** 적는 값이다. 앱이 적으면 폰에서 고쳐 뚫린다. */
void main() {
  int daysFromNow(int n) =>
      DateTime.now().add(Duration(days: n)).millisecondsSinceEpoch;

  void seed(Map<String, dynamic> extra, {String myRole = 'owner'}) {
    AppState.i.profile = {'code': 'C1', 'slot': 'u1', 'name': '갑'};
    AppState.i.couple = Store.tidyCouple({
      'code': 'C1',
      'title': '앞산 배드민턴',
      'members': {
        'u1': {'uid': 'u1', 'name': '갑', 'role': myRole},
        'u2': {'uid': 'u2', 'name': '을', 'role': 'member'},
      },
      ...extra,
    });
    AppState.i.setItems([]);
  }

  tearDown(() {
    Demo.stop();
    AppState.i.profile = null;
    AppState.i.resetRoom();
  });

  test('면제된 모임은 언제나 열려 있다 (총괄이 만든 방·앞산)', () {
    seed({'free': true});
    expect(Fee.ok(), isTrue);
    expect(Fee.locked, isFalse);
    expect(Fee.exempt, isTrue);
  });

  test('이용권이 살아 있으면 열려 있다', () {
    seed({'paidUntil': daysFromNow(10)});
    expect(Fee.ok(), isTrue);
    expect(Fee.until()!.isAfter(DateTime.now()), isTrue);
  });

  test('끝난 지 얼마 안 됐으면 봐준다 (카드 갱신 시간)', () {
    seed({'paidUntil': daysFromNow(-1)});
    expect(Fee.ok(), isTrue, reason: '하루 늦었다고 곧바로 잠그면 억울하다');
  });

  test('봐주는 기간까지 지나면 잠긴다', () {
    seed({'paidUntil': daysFromNow(-(Fee.graceDays + 1))});
    expect(Fee.locked, isTrue);
  });

  test('결제 기록이 아예 없으면 잠긴다 (새로 만든 방)', () {
    seed({});
    expect(Fee.locked, isTrue);
  });

  test('아직 모임 문서가 안 왔으면 잠그지 않는다', () {
    AppState.i.profile = {'code': 'C1', 'slot': 'u1', 'name': '갑'};
    AppState.i.couple = null;
    expect(Fee.ok(), isTrue, reason: '모르는 것을 잠그면 들어오자마자 잠긴 화면이 뜬다');
  });

  test('체험 모드는 결제를 묻지 않는다', () {
    Demo.start();
    expect(Fee.ok(), isTrue);
    expect(Fee.locked, isFalse);
  });

  group('누가 내는가', () {
    test('방장이 낸다', () {
      seed({});
      expect(Fee.iPay, isTrue);
    });

    test('평회원에게는 결제를 묻지 않는다', () {
      seed({}, myRole: 'member');
      expect(Fee.iPay, isFalse);
      expect(Fee.lockedLine.contains('방장이'), isTrue,
          reason: '회원에게 「결제하세요」라고 하면 안 된다 — 낼 수도 없다');
    });
  });

  test('값이 망가져 있어도 안 터진다', () {
    seed({'paidUntil': '어제', 'free': 'yes'});
    expect(Fee.locked, isTrue, reason: '글자 free 를 참으로 읽으면 공짜로 뚫린다');
  });
}
