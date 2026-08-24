// 회비·출석 계산 시험 — 여기가 틀리면 회원이 낸 돈이 미납으로 보이거나
// 반복 모임 출석이 1회로 세어진다. 웹앱과 규칙이 같아야 하므로 값을 박아두고 지킨다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/state.dart';

/// [joinedMonthsAgo] 몇 달 전에 가입한 회원으로 두느냐 — 미납은 가입한 달부터만 센다.
String readSource(String path) => File(path).readAsStringSync();

void setUpClub({
  int feeAmount = 30000,
  required List<Map<String, dynamic>> items,
  Map<String, dynamic>? members,
  int joinedMonthsAgo = 0,
}) {
  final now = DateTime.now();
  final joined = DateTime(now.year, now.month - joinedMonthsAgo, 1);
  AppState.i.couple = {
    'title': '시험 모임',
    'fee': {'amount': feeAmount},
    'members': members ??
        {
          'u1': {
            'uid': 'u1',
            'name': '김민수',
            'role': 'owner',
            'joinedAt': joined.millisecondsSinceEpoch,
          },
        },
  };
  AppState.i.setItems(items);
}

String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

void main() {
  final now = DateTime.now();
  final thisMonth = monthKey(DateTime(now.year, now.month));
  final nextMonth = monthKey(DateTime(now.year, now.month + 1));
  final lastMonth = monthKey(DateTime(now.year, now.month - 1));

  test('선납 6개월이면 이번 달은 낸 것이고 앞으로 5달이 채워져 있다', () {
    final months = List.generate(
        6, (i) => monthKey(DateTime(now.year, now.month + i)));
    setUpClub(items: [
      {
        'id': 'a',
        'type': 'ledger',
        'kind': 'in',
        'payer': 'u1',
        'amount': 180000,
        'months': 6,
        'feeMonths': months,
        'date': '${monthKey(now)}-01',
      }
    ]);
    expect(Logic.paidIn('u1', thisMonth), isTrue);
    expect(Logic.paidIn('u1', nextMonth), isTrue);
    expect(Logic.unpaidMonths('u1'), isEmpty);
    expect(Logic.prepaidLeft('u1'), 5);
  });

  test('선납이 아닌 입금은 그 달만 낸 것으로 본다', () {
    setUpClub(items: [
      {
        'id': 'a',
        'type': 'ledger',
        'kind': 'in',
        'payer': 'u1',
        'amount': 30000,
        'date': '$thisMonth-05',
      }
    ]);
    expect(Logic.paidIn('u1', thisMonth), isTrue);
    expect(Logic.paidIn('u1', nextMonth), isFalse);
    expect(Logic.prepaidLeft('u1'), 0);
  });

  test('남이 낸 회비는 내 것으로 세지 않는다', () {
    setUpClub(items: [
      {
        'id': 'a',
        'type': 'ledger',
        'kind': 'in',
        'payer': 'u2',
        'amount': 30000,
        'date': '$thisMonth-05',
      }
    ]);
    expect(Logic.paidIn('u1', thisMonth), isFalse);
  });

  test('가입한 달보다 앞선 달은 미납으로 세지 않는다', () {
    setUpClub(
      items: const [],
      members: {
        'u1': {
          'uid': 'u1',
          'name': '늦게온사람',
          'role': 'member',
          'joinedAt': DateTime.now().millisecondsSinceEpoch,
        }
      },
    );
    expect(Logic.unpaidMonths('u1'), [thisMonth]);
  });

  test('회비 금액이 0이면 미납 자체가 없다', () {
    setUpClub(feeAmount: 0, items: const []);
    expect(Logic.unpaidMonths('u1'), isEmpty);
  });

  test('지난달을 안 냈으면 미납에 들어간다', () {
    setUpClub(joinedMonthsAgo: 3, items: [
      {
        'id': 'a',
        'type': 'ledger',
        'kind': 'in',
        'payer': 'u1',
        'amount': 30000,
        'date': '$thisMonth-05',
      }
    ]);
    expect(Logic.unpaidMonths('u1'), contains(lastMonth));
    expect(Logic.unpaidMonths('u1'), isNot(contains(thisMonth)));
  });

  test('통장 잔액 = 들어온 돈 − 나간 돈', () {
    setUpClub(items: [
      {'id': 'a', 'type': 'ledger', 'kind': 'in', 'amount': 100000, 'date': '$thisMonth-01'},
      {'id': 'b', 'type': 'ledger', 'kind': 'out', 'amount': 30000, 'date': '$thisMonth-02'},
      {'id': 'c', 'type': 'ledger', 'kind': 'out', 'amount': 20000, 'date': '$thisMonth-03'},
    ]);
    expect(Logic.balance(), 50000);
  });

  test('매주 모임 출석은 회차마다 따로 센다 (모임 1개로 세면 안 됨)', () {
    // 3주 전부터 매주 — 지난 회차 4번 중 3번 출석
    final start = now.subtract(const Duration(days: 21));
    String d(int weeks) {
      final x = start.add(Duration(days: 7 * weeks));
      return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    }

    setUpClub(items: [
      {
        'id': 'e1',
        'type': 'event',
        'title': '주간 정기모임',
        'date': d(0),
        'repeat': 'week',
        'attend': {
          '${d(0)}_u1': true,
          '${d(1)}_u1': true,
          '${d(2)}_u1': true,
        },
      }
    ]);
    expect(Logic.attendStats()['u1'], 3);
  });

  test('참석 투표는 회차별로 따로 센다', () {
    // 108회차부터 «지금 회원»만 센다 — 그래서 누가 회원인지 밝혀 둔다
    AppState.i.couple = {
      'members': {
        'u1': {'uid': 'u1', 'name': '갑', 'role': 'owner'},
        'u2': {'uid': 'u2', 'name': '을', 'role': 'member'},
      }
    };
    final e = {
      'id': 'e1',
      'type': 'event',
      'date': '2026-01-05',
      'repeat': 'week',
      'rsvp': {
        '2026-01-05_u1': 'yes',
        '2026-01-05_u2': 'yes',
        '2026-01-12_u1': 'no',
      },
    };
    expect(Logic.rsvpCount(e, '2026-01-05', 'yes'), 2);
    expect(Logic.rsvpCount(e, '2026-01-12', 'yes'), 0);
    expect(Logic.rsvpCount(e, '2026-01-12', 'no'), 1);
  });

  test('10년 넘게 매주 하는 모임도 다가오는 일정에 나온다', () {
    // 오래된 모임을 하나씩 세어 가다 안전장치에 걸려 사라지던 문제
    final start = now.subtract(const Duration(days: 365 * 12));
    final e = {
      'id': 'e1',
      'type': 'event',
      'title': '12년째 수요 정기모임',
      'date': '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
      'repeat': 'week',
    };
    final today = DateTime(now.year, now.month, now.day);
    final future = Logic.occurrences(e, from: today, to: now.add(const Duration(days: 40)));
    expect(future, isNotEmpty, reason: '오래된 반복 모임이 다가오는 일정에서 사라지면 안 된다');
    expect(future.first.compareTo(
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}'),
        greaterThanOrEqualTo(0));

    setUpClub(items: [e]);
    expect(Logic.nextEvent(), isNotNull);
  });

  test('건너뛰기를 해도 회차 날짜가 어긋나지 않는다', () {
    final e = {'id': 'e1', 'type': 'event', 'date': '2020-01-01', 'repeat': 'week'};
    // 2020-01-01은 수요일 — 건너뛴 뒤에도 수요일이라야 한다
    final out = Logic.occurrences(e, from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 20));
    expect(out, isNotEmpty);
    for (final d in out) {
      expect(DateTime.parse(d).weekday, DateTime.wednesday);
    }
  });

  test('일정 고치기 화면은 저장된 값을 하나도 빠뜨리지 않고 불러온다', () {
    // 「끝나는 날」을 안 불러오면, 고치기만 눌러도 정해둔 종료일이 조용히 지워진다.
    // 화면 코드에서 저장하는 칸과 불러오는 칸이 짝이 맞는지 본다.
    final src = readSource('lib/ui/calendar.dart');
    for (final field in ['title', 'place', 'memo', 'date', 'repeat', 'until', 'time']) {
      expect(src.contains("e['$field']"), isTrue,
          reason: '고치기로 열 때 $field 를 안 불러오면 저장할 때 지워진다');
    }
  });

  test('반복 없는 일정으로 바꾸면 끝나는 날은 저장하지 않는다', () {
    // until 은 반복이 있을 때만 뜻이 있다 — 남아 있으면 나중에 반복을 켤 때 엉뚱하게 잘린다
    final src = readSource('lib/ui/calendar.dart');
    expect(src.contains("_repeat == 'none' || _until == null ? null : ymd(_until!)"), isTrue);
  });

  test('배지는 출석 횟수에 따라 쌓인다', () {
    expect(Logic.badgesOf(0), isEmpty);
    expect(Logic.badgesOf(5).length, 3); // 1·3·5회
    expect(Logic.nextBadge(5)?.$1, 10);
    expect(Logic.nextBadge(1000), isNull);
  });

  group('61회차에 훑어보고 «깨진 데 없음»을 확인한 자리 — 다시 깨지지 않게', () {
    test('모임 이름은 회원이 실제로 칠 법한 방식 모두로 찾아진다', () {
      /* 이름을 못 찾으면 **가입 자체를 못 한다.** 한글 자판의 전각 공백은 눈에 안 보여
         「분명히 맞게 쳤는데 없대요」가 된다. */
      const real = '앞산 배드민턴';
      final key = Store.normTitle(real);
      // 이스케이프 없이 «글자 번호»로 만든다 (파일에 눈에 안 보이는 글자를 안 남기려고)
      // 눈에 안 보이는 글자는 «글자 번호»로 만든다 (시험 파일에 그대로 넣으면 안 보인다)
      //  0x3000 = 한글 자판의 전각 공백 · 9 = 탭 · 10 = 줄바꿈
      final typedList = <String>[
        '앞산 배드민턴',
        '앞산배드민턴',
        '  앞산 배드민턴  ',
        for (final code in [0x3000, 9, 10])
          '앞산${String.fromCharCode(code)}배드민턴',
      ];
      for (final typed in typedList) {
        expect(Store.normTitle(typed), key, reason: '"$typed" 로 못 찾는다');
      }
      expect(Store.normTitle('앞산배드민턴클럽'), isNot(key), reason: '다른 이름까지 같다고 보면 안 된다');
    });

    test('배지 경계 — 하나도 없을 때부터 끝까지', () {
      expect(Logic.badgesOf(0), isEmpty);
      expect(Logic.nextBadge(0)?.$1, 1, reason: '첫 출석이 다음 배지여야 한다');
      expect(Logic.badgesOf(1).length, 1);
      expect(Logic.nextBadge(1)?.$1, 3);
      expect(Logic.badgesOf(200).length, Logic.badges.length, reason: '끝까지 가면 다 받는다');
      expect(Logic.nextBadge(200), isNull, reason: '더 없으면 «없음» — 홈이 그걸 보고 안 그린다');
      expect(Logic.nextBadge(9999), isNull);
    });
  });
}
