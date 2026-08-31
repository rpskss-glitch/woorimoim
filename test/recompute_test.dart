// 대화 한 건이 올 때 «다시 세지 않아야 할 것»이 다시 세어지지 않는지 (113회차).
//
// 출석·회비 표는 「그 묶음이 그대로인가」로 다시 만들지를 정하는데,
// 열쇠를 «전체 기록»으로 잡고 있어서 **대화 한 건만 와도 표를 통째로 다시 만들었다.**
// 실측(모임 8개·회원 20명·3년치): 대화 하나에 131.6㎳ → 고친 뒤 34.0㎳.
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

Map<String, dynamic> event(String id) => {
      'id': id, 'type': 'event', 'title': '모임', 'date': '2026-08-03', 'repeat': 'week',
      'attend': {'2026-08-03_u1': true}, 'createdAt': 1755800000000,
    };

// ⚠️ 회비 달은 «이번 달»로 — '2026-08' 처럼 박아 두면 달이 바뀐 «다음 달 1일»에
// unpaidMonths 가 이번 달을 미납으로 잡아 시험이 그날만 깨진다(2026-09-01에 겪음).
final _thisMonth =
    '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
Map<String, dynamic> ledger(String id) => {
      'id': id, 'type': 'ledger', 'kind': 'in', 'payer': 'u1', 'amount': 10000,
      'feeMonths': [_thisMonth], 'createdAt': 1755800000000, 'date': '$_thisMonth-03',
    };

Map<String, dynamic> msg(String id, int at) =>
    {'id': id, 'type': 'msg', 'text': '말', 'by': 'u1', 'createdAt': at};

void seed() {
  AppState.i.couple = Store.tidyCouple({
    'members': {'u1': {'uid': 'u1', 'name': '갑', 'role': 'member'}},
    'fee': {'amount': 10000},
  });
}

void main() {
  test('대화만 오면 «일정·회비 묶음»은 앞의 것을 그대로 쓴다', () {
    seed();
    final e = event('e1');
    final l = ledger('f1');
    AppState.i.setItems(Store.tidy([e, l, msg('m1', 1)]));
    final ev1 = AppState.i.by('event');
    final le1 = AppState.i.by('ledger');

    AppState.i.setItems(Store.tidy([e, l, msg('m1', 1), msg('m2', 2)]));
    expect(identical(AppState.i.by('event'), ev1), isTrue,
        reason: '새 묶음을 주면 출석 표를 통째로 다시 만든다');
    expect(identical(AppState.i.by('ledger'), le1), isTrue);
    // 대화 묶음은 당연히 달라진다
    expect(AppState.i.by('msg').length, 2);
  });

  test('일정이 «정말» 바뀌면 묶음도 새로 준다', () {
    seed();
    AppState.i.setItems(Store.tidy([event('e1'), msg('m1', 1)]));
    final ev1 = AppState.i.by('event');
    AppState.i.setItems(Store.tidy([event('e1'), event('e2'), msg('m1', 1)]));
    expect(identical(AppState.i.by('event'), ev1), isFalse,
        reason: '안 바꾸면 새 모임이 화면에 안 나온다');
  });

  test('같은 개수라도 «다른 기록»이면 새로 준다', () {
    seed();
    AppState.i.setItems(Store.tidy([event('e1')]));
    final ev1 = AppState.i.by('event');
    AppState.i.setItems(Store.tidy([event('e2')])); // 새 묶음 · 새 물건
    expect(identical(AppState.i.by('event'), ev1), isFalse);
  });

  test('출석·회비 표가 «묶음»을 열쇠로 삼는다', () {
    seed();
    final e = event('e1');
    final l = ledger('f1');
    AppState.i.setItems(Store.tidy([e, l, msg('m1', 1)]));
    final a1 = Logic.attendStats();
    AppState.i.setItems(Store.tidy([e, l, msg('m1', 1), msg('m2', 2)]));
    expect(identical(Logic.attendStats(), a1), isTrue,
        reason: '대화가 왔다고 출석을 다시 세면 안 된다');
    expect(Logic.unpaidMonths('u1'), isEmpty, reason: '회비 표도 그대로 쓴다');
  });

  test('«다음 모임»도 재어 둔다', () {
    seed();
    final e = event('e1');
    AppState.i.setItems(Store.tidy([e, msg('m1', 1)]));
    final n1 = Logic.nextEvent();
    AppState.i.setItems(Store.tidy([e, msg('m1', 1), msg('m2', 2)]));
    final n2 = Logic.nextEvent();
    expect(n1?.date, n2?.date);
    /* 재어 뒀으면 «돌려준 것 자체»가 같은 물건이다.
       (일정 물건만 견주면 다시 세어도 같게 나와 구분이 안 된다 — 실제로 그랬다) */
    expect(identical(n1, n2), isTrue,
        reason: '홈은 무엇이 바뀌어도 다시 그려진다 — 매번 회차를 펼치면 그때마다 걸린다');
  });

  test('일정이 바뀌면 «다음 모임»도 다시 본다', () {
    seed();
    AppState.i.setItems(Store.tidy([event('e1'), msg('m1', 1)]));
    Logic.nextEvent();
    AppState.i.setItems(Store.tidy([
      {'id': 'e9', 'type': 'event', 'title': '새 모임', 'date': '2026-08-04',
       'repeat': 'week', 'createdAt': 1755800000000}
    ]));
    expect(Logic.nextEvent()?.event['id'], 'e9', reason: '안 다시 보면 없어진 모임이 계속 뜬다');
  });
}
