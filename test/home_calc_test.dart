import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';

void main() {
  test('가입 직후·기록 0건일 때 홈 계산이 모두 안전한 값을 준다', () {
    AppState.i.couple = {'title': '새 모임', 'members': {}, 'fee': {'amount': 0}};
    AppState.i.setItems([]);
    expect(Logic.nextEvent(), isNull);
    expect(Logic.attendStats(), isEmpty);
    expect(Logic.monthRank(), isEmpty);
    expect(Logic.balance(), 0);
    expect(Logic.badgesOf(0), isEmpty);
    expect(Logic.nextBadge(0)?.$1, 1);
    expect(Logic.unpaidMonths('없는사람'), isEmpty);
    expect(Logic.prepaidLeft('없는사람'), 0);
  });

  test('모임 문서가 아예 없어도 죽지 않는다', () {
    AppState.i.couple = null;
    AppState.i.setItems([]);
    expect(Logic.nextEvent(), isNull);
    expect(Logic.unpaidMonths('u1'), isEmpty);
    expect(Logic.balance(), 0);
    expect(AppState.i.memberList, isEmpty);
    expect(AppState.i.isTreasurer, isFalse);
    expect(AppState.i.isAdmin, isFalse);
  });

  test('망가진 기록이 섞여 있어도 계산이 멈추지 않는다', () {
    AppState.i.couple = {'members': {}, 'fee': {'amount': 10000}};
    AppState.i.setItems([
      {'id': 'a', 'type': 'event'},                                  // 날짜 없음
      {'id': 'b', 'type': 'event', 'date': '엉터리', 'repeat': 'week'},
      {'id': 'c', 'type': 'ledger', 'kind': 'in', 'amount': 'x'},    // 숫자 아님
      {'id': 'd', 'type': 'event', 'date': '2026-01-01', 'attend': '목록아님'},
    ]);
    expect(() => Logic.attendStats(), returnsNormally);
    expect(() => Logic.nextEvent(), returnsNormally);
    expect(() => Logic.balance(), returnsNormally);
  });

  test('회비 받기는 «이미 낸 달»을 건너뛴다', () {
    /* 총무가 중간 기록 하나를 잘못 지우면 안 낸 달이 띄엄띄엄해진다.
       그때 그냥 이어서 세면 이미 낸 달에 또 얹혀 회원이 낸 만큼 미납이 안 줄어든다. */
    final now = DateTime.now();
    String mk(int back) {
      final m = DateTime(now.year, now.month - back);
      return '${m.year}-${m.month.toString().padLeft(2, '0')}';
    }

    AppState.i.couple = {
      'members': {
        'u1': {'name': '홍길동', 'joinedAt': DateTime(now.year, now.month - 3).millisecondsSinceEpoch}
      },
      'fee': {'amount': 10000},
    };
    // 3달 전은 안 냄, 2달 전은 냄, 1달 전·이번 달은 안 냄
    AppState.i.setItems([
      {'id': 'p', 'type': 'ledger', 'kind': 'in', 'payer': 'u1', 'amount': 10000,
       'feeMonths': [mk(2)]},
    ]);

    expect(Logic.unpaidMonths('u1'), [mk(3), mk(1), mk(0)]);

    // 3달치를 받으면 → 안 낸 세 달을 메워야 한다 (2달 전을 또 넣으면 안 된다)
    final got = Logic.feeMonthsToFill('u1', 3);
    expect(got, [mk(3), mk(1), mk(0)]);
    expect(got.contains(mk(2)), isFalse, reason: '이미 낸 달을 또 채우면 회원이 그 달치를 두 번 낸 셈이 된다');

    // 밀린 것보다 많이 받으면 나머지는 앞으로의 달로 이어진다
    expect(Logic.feeMonthsToFill('u1', 4).length, 4);
    expect(Logic.feeMonthsToFill('u1', 4).toSet().length, 4, reason: '같은 달이 겹치면 안 된다');
    expect(Logic.feeMonthsToFill('u1', 0), isEmpty);
  });

  test('출석 셈은 기록이 그대로면 다시 세지 않는다', () {
    /* 홈 한 장을 그리는 데 이 셈이 세 번 불린다(내 출석·이번 달 순위 두 번).
       홈은 채팅에서 누가 글씨만 쳐도 다시 그려지므로, 매번 세면 화면이 걸린다.
       실제로 재보니 모임 8개·회원 20명·3년치에서 한 번 그리는 데 140ms였다. */
    AppState.i.couple = {'members': {}, 'fee': {'amount': 0}};
    AppState.i.setItems([
      {
        'id': 'e1',
        'type': 'event',
        'date': '2026-01-05',
        'repeat': 'week',
        'attend': {'2026-01-05_u1': true, '2026-01-12_u1': true, '2026-01-12_u2': true},
      },
    ]);
    final a = Logic.attendStats();
    final b = Logic.attendStats();
    expect(identical(a, b), isTrue, reason: '기록이 그대로면 재둔 값을 그대로 써야 한다');
    expect(a['u1'], 2);
    expect(a['u2'], 1);

    // 기록이 갈리면 반드시 다시 센다
    AppState.i.setItems([
      {
        'id': 'e1',
        'type': 'event',
        'date': '2026-01-05',
        'repeat': 'week',
        'attend': {'2026-01-05_u1': true},
      },
    ]);
    final c = Logic.attendStats();
    expect(identical(a, c), isFalse, reason: '기록이 바뀌었으면 새로 세야 한다');
    expect(c['u1'], 1);
    expect(c.containsKey('u2'), isFalse);
  });

  test('이번 달 출석 순위에 「지난 회원」이 끼지 않는다', () {
    /* 출석표에는 탈퇴한 사람의 기록도 그대로 남는다(옛 기록을 지우지 않으므로).
       안 거르면 홈 순위 카드에 이름 없는 유령 줄이 뜬다. */
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    String key(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    AppState.i.couple = {
      'members': {
        'u1': {'name': '남은사람', 'uid': 'u1', 'role': 'member'},
      },
      'former': {
        'u2': {'name': '나간사람', 'uid': 'u2'},
      },
      'fee': {'amount': 0},
    };
    AppState.i.setItems([
      {
        'id': 'e1',
        'type': 'event',
        'date': key(first),
        'repeat': 'week',
        'attend': {'${key(first)}_u1': true, '${key(first)}_u2': true},
      },
    ]);

    // 세는 것 자체는 둘 다 세어 둔다 (옛 기록은 남아 있어야 한다)
    expect(Logic.attendStats()['u2'], 1);
    // 그러나 순위에는 지금 회원만 나온다
    final rank = Logic.monthRank();
    expect(rank.map((e) => e.key).toList(), ['u1']);
  });
}
