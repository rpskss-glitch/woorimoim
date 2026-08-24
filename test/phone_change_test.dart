// 폰을 바꾼 뒤에도 «그동안 쌓은 것»이 남아 있는지 (109회차).
//
// 폰을 바꾸면 번호(uid)가 새로 생기고, 옛 자리는 `former[옛번호].movedTo = 새번호` 로 남는다.
// 그런데 출석·회비는 그 번호를 열쇠로 적혀 있다 — 잇지 않으면 바꾼 순간 전부 사라진다.
// 실측(고치기 전): 출석 4 → 0 · 배지 2개 → 0 · 순위 사라짐 · 낸 회비 → 미납.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

final _now = DateTime.now();
DateTime get _first => DateTime(_now.year, _now.month, 1);
String get _thisMonth => ymd(_now).substring(0, 7);

/// 갑이 «옛 번호»로 이번 달 내내 나왔고 회비도 냈다. 오늘 폰을 바꿔 새 번호가 되었다.
int seed({String old = 'u1old', Map<String, dynamic>? extraFormer, bool alsoNew = false}) {
  final attend = <String, dynamic>{};
  var rounds = 0;
  for (var d = _first; !d.isAfter(_now); d = d.add(const Duration(days: 7))) {
    attend['${ymd(d)}_$old'] = true;
    if (alsoNew) attend['${ymd(d)}_u1'] = true; // 같은 날 새 번호로도 찍힌 경우
    rounds++;
  }
  AppState.i.couple = Store.tidyCouple({
    'members': {
      'u1': {'uid': 'u1', 'name': '갑', 'role': 'member', 'joinedAt': _first.millisecondsSinceEpoch},
      'u2': {'uid': 'u2', 'name': '을', 'role': 'member', 'joinedAt': _first.millisecondsSinceEpoch},
    },
    'former': {
      old: {'uid': old, 'name': '갑', 'movedTo': 'u1'},
      ...?extraFormer,
    },
    'fee': {'amount': 10000},
  });
  AppState.i.setItems(Store.tidy([
    {'id': 'e1', 'type': 'event', 'title': '정기모임', 'date': ymd(_first), 'repeat': 'week',
     'attend': attend, 'rsvp': {'${ymd(_first)}_$old': 'yes', '${ymd(_first)}_u1': 'yes'},
     'createdAt': _first.millisecondsSinceEpoch},
    {'id': 'f1', 'type': 'ledger', 'kind': 'in', 'payer': old, 'amount': 10000,
     'feeMonths': [_thisMonth], 'createdAt': _now.millisecondsSinceEpoch, 'date': ymd(_now)},
  ]));
  return rounds;
}

void main() {
  test('출석 횟수가 그대로 이어진다', () {
    final rounds = seed();
    expect(Logic.attendStats()['u1'], rounds, reason: '옛 번호로 찍힌 것도 그 사람 것이다');
    expect(Logic.attendStats().containsKey('u1old'), isFalse, reason: '옛 번호로 따로 세면 안 된다');
  });

  test('배지와 이번 달 순위도 그대로다', () {
    final rounds = seed();
    expect(Logic.badgesOf(Logic.attendStats()['u1'] ?? 0), isNotEmpty);
    expect(Logic.monthRank().map((e) => e.key).toList(), ['u1']);
    expect(Logic.monthRank().first.value, rounds);
  });

  test('낸 회비가 미납으로 바뀌지 않는다', () {
    seed();
    expect(Logic.unpaidMonths('u1'), isEmpty, reason: '옛 번호로 낸 회비도 그 사람이 낸 것이다');
    expect(Logic.unpaidMonths('u2'), [_thisMonth], reason: '안 낸 사람은 그대로 밀린다');
  });

  test('같은 날 옛·새 번호가 둘 다 찍혀 있어도 «한 번»만 센다', () {
    final rounds = seed(alsoNew: true);
    expect(Logic.attendStats()['u1'], rounds, reason: '두 번 세면 출석이 부풀려진다');
  });

  test('참석 표도 «한 사람»으로 센다', () {
    seed();
    final e = AppState.i.by('event').first;
    expect(Logic.rsvpCount(e, ymd(_first), 'yes'), 1,
        reason: '옛·새 번호로 두 번 찍혀 있어도 한 사람이다');
  });

  test('그 회차에 나왔는지도 옛 번호를 본다', () {
    seed();
    final e = AppState.i.by('event').first;
    expect(Logic.attended(e, ymd(_first), 'u1'), isTrue);
    expect(Logic.attended(e, ymd(_first), 'u2'), isFalse);
  });

  test('폰을 여러 번 바꿔도 사슬을 끝까지 따라간다', () {
    final rounds = seed(old: 'uA', extraFormer: {
      'uB': {'uid': 'uB', 'name': '갑', 'movedTo': 'uA'}, // uB → uA → u1
    });
    expect(Logic.liveUid('uB'), 'u1');
    expect(Logic.liveUid('uA'), 'u1');
    expect(Logic.liveUid('u1'), 'u1', reason: '지금 번호는 그대로');
    expect(Logic.attendStats()['u1'], rounds);
  });

  test('자료가 고리를 이뤄도 안 멈춘다', () {
    AppState.i.couple = Store.tidyCouple({
      'members': {'u1': {'uid': 'u1', 'name': '갑', 'role': 'member'}},
      'former': {
        'a': {'uid': 'a', 'movedTo': 'b'},
        'b': {'uid': 'b', 'movedTo': 'a'},
      },
    });
    expect(() => Logic.liveUid('a'), returnsNormally);
  });

  test('폰을 안 바꾼 사람은 아무것도 안 달라진다', () {
    AppState.i.couple = Store.tidyCouple({
      'members': {'u2': {'uid': 'u2', 'name': '을', 'role': 'member'}},
      'former': <String, dynamic>{},
    });
    expect(Logic.liveUid('u2'), 'u2');
    expect(Logic.pastUids('u2'), isEmpty);
  });

  /* 111회차: 「남이 쓴 말」을 고르는 자리도 폰 바꾸기를 이어야 한다.
     실측(고치기 전): 남이 쓴 말 3개인데 안읽음 배지가 **8** — 내가 옛 폰에서 쓴 5개까지 셌다. */
  group('안읽음 세기', () {
    List<Map<String, dynamic>> chat() => Store.tidy([
          for (var i = 0; i < 5; i++)
            {'id': 'a$i', 'type': 'msg', 'text': '옛 폰에서 쓴 내 말', 'by': 'u1old',
             'createdAt': 1755800000000 + i},
          for (var i = 0; i < 3; i++)
            {'id': 'b$i', 'type': 'msg', 'text': '을이 쓴 말', 'by': 'u2',
             'createdAt': 1755800001000 + i},
          {'id': 'c0', 'type': 'msg', 'text': '새 폰에서 쓴 내 말', 'by': 'u1',
           'createdAt': 1755800002000},
        ]);

    setUp(() {
      AppState.i.couple = Store.tidyCouple({
        'members': {
          'u1': {'uid': 'u1', 'name': '갑', 'role': 'member'},
          'u2': {'uid': 'u2', 'name': '을', 'role': 'member'},
        },
        'former': {'u1old': {'uid': 'u1old', 'name': '갑', 'movedTo': 'u1'}},
      });
      AppState.i.setItems(chat());
    });

    int unread(int seen) => AppState.i
        .by('msg')
        .where((m) =>
            !Logic.isMe(m['by'] as String?, 'u1') &&
            ((m['createdAt'] as num?) ?? 0) > seen)
        .length;

    test('내가 옛 폰에서 쓴 말은 «안 읽음»이 아니다', () {
      expect(unread(0), 3, reason: '을이 쓴 3개만 — 내 옛 말 5개는 빼야 한다');
    });

    test('이미 본 데까지는 안 센다', () {
      expect(unread(1755800001001), 1);
      expect(unread(1755800009999), 0);
    });

    test('탭 막대가 이 셈을 실제로 쓴다', () {
      final src = File('lib/ui/shell.dart').readAsStringSync();
      final at = src.indexOf('int get _unreadChat');
      expect(at, greaterThan(0));
      // 파일 «끝» 가까이에 있는 함수다 — 창이 넘으면 substring 이 터진다
      final body = src.substring(at, (at + 700).clamp(at, src.length));
      expect(body.contains('Logic.isMe'), isTrue,
          reason: '안 이으면 새 폰에서 내가 쓴 말까지 안읽음으로 뜬다');
    });
  });
}
