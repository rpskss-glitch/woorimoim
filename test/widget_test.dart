// 화면 위젯 테스트는 Firebase 연결이 필요해서 여기서는 계산 로직만 확인한다.
// (일정 회차·회비 판정이 웹앱과 어긋나면 같은 모임인데 숫자가 다르게 보인다)
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

void main() {
  test('반복 없는 모임은 회차가 하나', () {
    final e = {'date': '2026-01-05', 'repeat': 'none'};
    expect(Logic.occurrences(e, to: DateTime(2026, 3, 1)), ['2026-01-05']);
  });

  test('매주 모임은 회차별로 펼쳐진다', () {
    final e = {'date': '2026-01-05', 'repeat': 'week'};
    final out = Logic.occurrences(e, to: DateTime(2026, 1, 26));
    expect(out, ['2026-01-05', '2026-01-12', '2026-01-19', '2026-01-26']);
  });

  test('끝나는 날 뒤로는 반복하지 않는다', () {
    final e = {'date': '2026-01-05', 'repeat': 'week', 'until': '2026-01-15'};
    final out = Logic.occurrences(e, to: DateTime(2026, 2, 1));
    expect(out, ['2026-01-05', '2026-01-12']);
  });

  test('참석 투표 키는 날짜별로 갈린다', () {
    expect(Logic.rkey('2026-01-05', 'u1'), '2026-01-05_u1');
    expect(Logic.rkey('2026-01-12', 'u1'), isNot(Logic.rkey('2026-01-05', 'u1')));
  });

  test('모임 이름은 대소문자·띄어쓰기를 무시하고 견준다', () {
    expect(Store.normTitle('앞산 배드민턴 A방'), Store.normTitle('앞산배드민턴a방'));
    expect(Store.normTitle('Wed Club'), Store.normTitle('wedclub'));
  });

  test('빈칸 메꾸기 — 글자 숫자는 숫자로, 날짜 없으면 만든 날로', () {
    final rows = Store.tidy([
      {'type': 'ledger', 'amount': '5000', 'createdAt': DateTime(2026, 1, 5).millisecondsSinceEpoch},
      {'type': 'event', 'createdAt': DateTime(2026, 1, 5).millisecondsSinceEpoch},
    ]);
    expect(rows[0]['amount'], 5000);
    expect(rows[0]['date'], '2026-01-05');
    expect(rows[1]['date'], '2026-01-05');
  });

  test('매달 31일 모임은 «31일»을 지킨다 — 없는 달은 그 달 마지막 날', () {
    /* 앞 회차에 한 달씩 더하면 1/31 다음이 2/31 = 3월 3일이 되고, 그 뒤로 영영 3일로 밀린다.
       2월이 통째로 빠지고 회원은 「31일 모임」인데 3일에 나오라는 안내를 받는다. */
    final e = {'date': '2026-01-31', 'repeat': 'month'};
    final got = Logic.occurrences(e, to: DateTime(2026, 6, 30));
    expect(got, [
      '2026-01-31',
      '2026-02-28',
      '2026-03-31',
      '2026-04-30',
      '2026-05-31',
      '2026-06-30',
    ]);
  });

  test('윤달 29일 매년 모임은 3월로 밀리지 않는다', () {
    final e = {'date': '2024-02-29', 'repeat': 'year'};
    final got = Logic.occurrences(e, to: DateTime(2028, 12, 31));
    expect(got, ['2024-02-29', '2025-02-28', '2026-02-28', '2027-02-28', '2028-02-29']);
  });

  test('건너뛰기(from)를 써도 날짜가 밀리지 않는다', () {
    // 홈의 「다가오는 모임」은 from을 주고 부른다 — 그 길로도 같은 답이 나와야 한다
    final e = {'date': '2026-01-31', 'repeat': 'month'};
    final got = Logic.occurrences(e,
        from: DateTime(2026, 4, 1), to: DateTime(2026, 7, 31));
    expect(got, ['2026-04-30', '2026-05-31', '2026-06-30', '2026-07-31']);
  });

  test('매주·격주는 처음 날에서 센다', () {
    expect(Logic.occurrences({'date': '2026-03-05', 'repeat': 'week'},
            to: DateTime(2026, 4, 2)),
        ['2026-03-05', '2026-03-12', '2026-03-19', '2026-03-26', '2026-04-02']);
    expect(Logic.occurrences({'date': '2026-03-05', 'repeat': '2week'},
            to: DateTime(2026, 4, 2)),
        ['2026-03-05', '2026-03-19', '2026-04-02']);
  });

  test('한 번뿐인 모임은 아무리 멀어도 목록에 나온다', () {
    /* 예전에는 400일까지만 봐서, 1년 반 뒤 날짜로 만든 모임이 저장은 되는데
       다가오는 목록에도 지난 목록에도 안 나왔다 → 화면에 없으니 고칠 수도 지울 수도 없다. */
    final now = DateTime.now();
    final far = now.add(const Duration(days: 500));
    final e = {'date': ymd(far), 'repeat': 'none'};
    final got = Logic.occurrences(e,
        from: DateTime(now.year, now.month, now.day), to: Logic.horizonFor(e, now));
    expect(got, [ymd(far)]);

    // 반복 모임은 400일이면 다음 회차가 반드시 들어오므로 그대로 둔다
    final rep = {'date': ymd(now), 'repeat': 'week'};
    expect(Logic.horizonFor(rep, now).isBefore(Logic.horizonFor(e, now)), isTrue);
  });

  test('끝나는 날이 시작 날보다 앞이면 회차가 하나도 안 생긴다', () {
    // 그런 모임은 어느 목록에도 안 나와 손댈 수 없다 — 화면에서 그 상태가 되지 않게 막아 두었다
    final e = {'date': '2026-05-10', 'repeat': 'week', 'until': '2026-04-01'};
    expect(Logic.occurrences(e, to: DateTime(2026, 12, 31)), isEmpty);
  });

  group('같은 날 모임이 둘일 때 차례', () {
    String d(int n) {
      final t = DateTime.now();
      final x = DateTime(t.year, t.month, t.day + n);
      return '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    }

    test('홈의 「다가오는 모임」은 «가장 이른 시각»을 보여준다', () {
      /* 날짜만 견주면 아침 7시 모임을 두고 저녁 8시 모임을 보여준다 —
         회원은 홈만 보고 시간을 잘못 안다. */
      AppState.i.couple = {'members': <String, dynamic>{}, 'fee': {'amount': 0}};
      AppState.i.setItems([
        {'id': 'e1', 'type': 'event', 'date': d(1), 'time': '20:00', 'title': '저녁 번개'},
        {'id': 'e2', 'type': 'event', 'date': d(1), 'time': '07:00', 'title': '아침 운동'},
      ]);
      expect(Logic.nextEvent()?.event['title'], '아침 운동');
    });

    test('시각이 없는 모임은 그 날의 맨 앞', () {
      expect(Logic.byDateTime('2026-08-22', null, '2026-08-22', '09:00'), lessThan(0));
      expect(Logic.byDateTime('2026-08-22', '09:00', '2026-08-22', '19:30'), lessThan(0));
      expect(Logic.byDateTime('2026-08-21', '23:00', '2026-08-22', '01:00'), lessThan(0),
          reason: '날짜가 먼저다');
      expect(Logic.byDateTime('2026-08-22', '09:00', '2026-08-22', '09:00'), 0);
    });

    test('시각 칸이 망가져 있어도 차례를 매긴다', () {
      // 백업 복원으로 배열·숫자가 들어올 수 있다 (tidy 가 고치지만 여기서도 안 터져야 한다)
      expect(() => Logic.byDateTime('2026-08-22', ['x'], '2026-08-22', 5), returnsNormally);
    });
  });
}
