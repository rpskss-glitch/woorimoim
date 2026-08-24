// 회원이 «매일 보는 숫자»가 맞는지 (107회차).
//
// 지금까지의 홈 시험은 「빈 값·망가진 값에 안 터지는지」만 봤다.
// 여기서는 그 반대 — **제대로 된 모임에서 숫자가 정말 맞는지**를 손으로 센 값과 맞댄다.
// (출석 한 번, 선납 한 달이 어긋나면 아무도 못 알아채고 총무만 곤란해진다)
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

final _now = DateTime.now();
DateTime get _first => DateTime(_now.year, _now.month, 1);
String get _thisMonth => ymd(_now).substring(0, 7);

/// 이번 달 1일부터 «매주» 모이는 동호회.
/// 갑은 매번, 을은 한 번 걸러 나온다. 회비는 월 1만원.
({int rounds, Map<String, dynamic> club, List<Map<String, dynamic>> items}) makeClub() {
  final attend = <String, dynamic>{};
  var rounds = 0;
  for (var d = _first; !d.isAfter(_now); d = d.add(const Duration(days: 7))) {
    attend['${ymd(d)}_u1'] = true;
    if (rounds.isEven) attend['${ymd(d)}_u2'] = true;
    rounds++;
  }
  return (
    rounds: rounds,
    club: {
      'members': {
        'u1': {'uid': 'u1', 'name': '갑', 'role': 'owner', 'joinedAt': _first.millisecondsSinceEpoch},
        'u2': {'uid': 'u2', 'name': '을', 'role': 'member', 'joinedAt': _first.millisecondsSinceEpoch},
      },
      'fee': {'amount': 10000},
    },
    items: Store.tidy([
      {
        'id': 'e1',
        'type': 'event',
        'title': '정기모임',
        'date': ymd(_first),
        'repeat': 'week',
        'attend': attend,
        'createdAt': _first.millisecondsSinceEpoch,
      }
    ]),
  );
}

void main() {
  late int rounds;

  setUp(() {
    final c = makeClub();
    rounds = c.rounds;
    AppState.i.couple = Store.tidyCouple(c.club);
    AppState.i.setItems(c.items);
  });

  test('출석 횟수 — 매번 나온 사람과 걸러 나온 사람', () {
    final s = Logic.attendStats();
    expect(s['u1'], rounds, reason: '지난 회차마다 한 번씩');
    expect(s['u2'], (rounds + 1) ~/ 2, reason: '한 번 걸러 (첫 회차 포함)');
  });

  test('이번 달 순위 — 많이 나온 사람이 먼저', () {
    final r = Logic.monthRank();
    expect(r.map((e) => e.key).toList(), ['u1', 'u2']);
    expect(r.first.value, rounds);
  });

  test('배지 — 딱 그 횟수만큼만 받는다', () {
    // 배지 기준: 1·3·5·10·20…
    for (final n in [0, 1, 2, 3, 4, 5, 9, 10]) {
      final got = Logic.badgesOf(n).map((b) => b.$1).toList();
      final want = Logic.badges.map((b) => b.$1).where((t) => n >= t).toList();
      expect(got, want, reason: '$n번');
    }
    expect(Logic.nextBadge(4)?.$1, 5, reason: '4번이면 다음은 5번짜리');
    expect(Logic.nextBadge(0)?.$1, 1);
    expect(Logic.nextBadge(99999), isNull, reason: '다 받았으면 다음이 없다');
  });

  test('다음 모임 — 오늘 이후 «가장 가까운» 회차', () {
    final next = Logic.nextEvent();
    expect(next, isNotNull);
    final d = parseYmd(next!.date);
    expect(d.isBefore(DateTime(_now.year, _now.month, _now.day)), isFalse);
    expect(d.difference(_now).inDays, lessThan(7), reason: '매주 모임이니 이레 안에 있다');
  });

  test('회비 — 이번 달에 가입했으면 이번 달 한 건만 밀린다', () {
    expect(Logic.unpaidMonths('u1'), [_thisMonth]);
    expect(Logic.prepaidLeft('u1'), 0);
  });

  test('회비 — N개월치를 받으면 «N-1달» 선납으로 보인다', () {
    for (final months in [1, 3, 12]) {
      final c = makeClub();
      AppState.i.couple = Store.tidyCouple(c.club);
      AppState.i.setItems(c.items);
      final fill = Logic.feeMonthsToFill('u1', months);
      expect(fill.length, months, reason: '$months개월');
      expect(fill.first, _thisMonth, reason: '밀린 달부터 메운다');

      AppState.i.setItems(Store.tidy([
        ...c.items,
        {
          'id': 'f1',
          'type': 'ledger',
          'kind': 'in',
          'payer': 'u1',
          'amount': 10000 * months,
          'months': months,
          'feeMonths': fill,
          'createdAt': _now.millisecondsSinceEpoch,
          'date': ymd(_now),
        }
      ]));
      expect(Logic.unpaidMonths('u1'), isEmpty, reason: '$months개월치를 냈으면 안 밀린다');
      expect(Logic.prepaidLeft('u1'), months - 1,
          reason: '$months개월 중 이번 달을 뺀 만큼이 «앞으로» 채워진 것이다');
    }
  });

  test('통장 — 들어온 돈에서 나간 돈을 뺀다', () {
    final c = makeClub();
    AppState.i.setItems(Store.tidy([
      ...c.items,
      {'id': 'i1', 'type': 'ledger', 'kind': 'in', 'amount': 120000,
       'createdAt': _now.millisecondsSinceEpoch, 'date': ymd(_now)},
      {'id': 'o1', 'type': 'ledger', 'kind': 'out', 'amount': 45000,
       'createdAt': _now.millisecondsSinceEpoch, 'date': ymd(_now)},
    ]));
    expect(Logic.balance(), 75000);
  });
}
