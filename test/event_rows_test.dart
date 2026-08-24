// 일정 목록을 «다시 펼치지» 않는지 (127회차).
//
// 일정 화면은 IndexedStack 안에 살아 있어 다른 탭을 보는 중에도 다시 그려진다 —
// 곧 **채팅 한 줄만 와도** 회차를 다시 펼쳤다.
// 실측(이 PC): 매주 모임 10개·3년치 → 지난 목록 한 번에 97ms (회차 1902개).
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

Map<String, dynamic> ev(String id, {String repeat = 'week'}) => {
      'id': id, 'type': 'event', 'title': '모임 $id', 'date': '2023-01-04',
      'repeat': repeat, 'time': '19:00', 'createdAt': 1672790400000,
    };

Map<String, dynamic> msg(String id, int at) =>
    {'id': id, 'type': 'msg', 'text': '말', 'by': 'u1', 'createdAt': at};

void main() {
  /* ⚠️ 실제로는 대화가 와도 «일정 묶음의 물건»은 그대로다 —
     items 구독은 안 바뀌었고, 화면에 알릴 때 그 맵들이 그대로 실려 온다.
     시험에서 매번 새 맵을 만들면 그 사실이 깨져 헛돌게 된다. 같은 물건을 돌려 쓴다. */
  late Map<String, dynamic> a, b;

  setUp(() {
    a = ev('a');
    b = ev('b');
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'u1': {'uid': 'u1', 'name': '갑', 'role': 'member'}
      }
    });
    AppState.i.setItems([a, b]);
    // 앞 시험이 남긴 표를 비운다 (열쇠가 «묶음 그 자체»라 새 묶음이면 저절로 갈린다)
    Logic.eventRows(past: true);
  });

  test('일정이 그대로면 «다시 펼치지» 않는다', () {
    final first = Logic.eventRows(past: true);
    final again = Logic.eventRows(past: true);
    /* ⚠️ 「값이 같다」로는 못 잡는다 — 다시 펼쳐도 값은 같다.
       돌려준 «그 물건»이 같은지를 봐야 다시 안 펼쳤다는 뜻이 된다(113회차 교훈). */
    expect(identical(first, again), isTrue, reason: '다시 펼쳤다');
    expect(first, isNotEmpty);
  });

  test('대화 한 건이 와도 다시 펼치지 않는다', () {
    final before = Logic.eventRows(past: true);
    AppState.i.setItems([a, b, msg('m1', 1755800000000)]);
    expect(identical(Logic.eventRows(past: true), before), isTrue,
        reason: '대화가 왔다고 일정을 다시 펼치면 채팅할 때마다 화면이 걸린다');
  });

  test('일정이 바뀌면 다시 펼친다', () {
    final before = Logic.eventRows(past: true);
    AppState.i.setItems([a, b, ev('c')]);
    final after = Logic.eventRows(past: true);
    expect(identical(after, before), isFalse);
    expect(after.length, greaterThan(before.length));
  });

  test('지난 목록과 다가올 목록을 헷갈리지 않는다', () {
    final past = Logic.eventRows(past: true);
    final soon = Logic.eventRows(past: false);
    expect(identical(past, soon), isFalse);
    final today = ymd(DateTime.now());
    expect(past.every((r) => r.date.compareTo(today) <= 0), isTrue,
        reason: '지난 목록에 앞으로 올 회차가 섞였다');
    expect(soon.every((r) => r.date.compareTo(today) >= 0), isTrue,
        reason: '다가올 목록에 지난 회차가 섞였다');
  });

  test('재어 둬도 «펼친 결과»는 그대로다', () {
    final cached = Logic.eventRows(past: true);
    // 표를 비우고 처음부터 다시 펼쳐 견준다
    AppState.i.setItems([a, b, msg('x', 1)]);
    AppState.i.setItems([a, b]);
    final fresh = Logic.eventRows(past: true);
    expect(fresh.map((r) => '${r.e['id']}|${r.date}').toList(),
        cached.map((r) => '${r.e['id']}|${r.date}').toList());
  });

  test('차례가 맞다 — 지난 것은 최근부터, 다가올 것은 가까운 것부터', () {
    final past = Logic.eventRows(past: true).map((r) => r.date).toList();
    expect(past.first.compareTo(past.last) >= 0, isTrue);
    final soon = Logic.eventRows(past: false).map((r) => r.date).toList();
    expect(soon.first.compareTo(soon.last) <= 0, isTrue);
  });
}
