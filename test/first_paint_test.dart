import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

/* ⏱ 「방에 들어갈 때 화면이 멎는」 자리 두 곳.

   ① 회차를 «건너뛰는» 갈래표가 `nthOccurrence` 와 어긋나 있었다.
      거기서는 모르는 반복값을 「매주」로 보는데, 건너뛰기 쪽만 0(건너뛰기 없음)이라
      모르는 값이 오면 처음 회차부터 하나씩 세어 안전장치(2000번)까지 헛돌았다.
      2026-08-24 실측: 같은 자료로 「다가오는 모임」 9.8㎳ → **60.7㎳ (6배)**.
      모르는 값은 실제로 온다 — 웹앱·백업 복원·다음 판 앱이 적은 값.
   ② 지난 회차 펼치기를 홈 화면이 **두 번** 했다(전체 출석 + 이번 달 순위).
      실측 81㎳ + 55㎳. 재어 두니 이번 달 순위가 **55㎳ → 3㎳ (18배)**. */
void main() {
  Map<String, dynamic> ev(String rep, String date, {String? until}) {
    final m = <String, dynamic>{
      'id': 'e-$rep-$date',
      'type': 'event',
      'title': '모임',
      'date': date,
      'repeat': rep,
    };
    if (until != null) m['until'] = until;
    return m;
  }

  group('건너뛰기 갈래표가 회차 계산과 «짝이 맞는다»', () {
    /* 결과만 견주면 안 잡힌다 — 헛돌아도 «답은 같기» 때문이다.
       그래서 안전장치를 아주 낮게 잡는다: 제대로 건너뛰면 몇 번이면 닿고,
       안 건너뛰면 그 안에 못 닿아 **빈손**이 된다. */
    final from = DateTime.now().add(const Duration(days: 7));
    final to = from.add(const Duration(days: 30));
    final start = DateTime.now().subtract(const Duration(days: 365 * 3));
    String ymd(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    test('「매주」는 3년 전에 시작해도 몇 걸음 만에 닿는다', () {
      final got = Logic.occurrences(ev('week', ymd(start)),
          from: from, to: to, limit: 6);
      expect(got, isNotEmpty);
    });

    test('«모르는 반복값»도 똑같이 닿는다 — 여기가 어긋나 6배 느렸다', () {
      final got = Logic.occurrences(ev('매주마다', ymd(start)),
          from: from, to: to, limit: 6);
      expect(got, isNotEmpty,
          reason: '모르는 반복값일 때 건너뛰기가 꺼진다 — 처음 회차부터 하나씩 세어 '
              '안전장치까지 헛돈다(실측 6배). nthOccurrence 와 같은 갈래표를 써야 한다');
      expect(got, Logic.occurrences(ev('week', ymd(start)), from: from, to: to, limit: 6),
          reason: '모르는 값을 「매주」로 보는 것까지 같아야 한다');
    });

    test('「매달·매년·2주」는 저마다 제 셈으로 건너뛴다', () {
      for (final r in ['month', 'year', '2week']) {
        expect(
            Logic.occurrences(ev(r, ymd(DateTime(start.year, start.month, 5))),
                from: from, to: from.add(const Duration(days: 400)), limit: 6),
            isNotEmpty,
            reason: '$r 이 건너뛰기를 못 한다');
      }
    });
  });

  group('지난 회차 펼치기를 «한 번만» 한다', () {
    test('같은 모임을 다시 물으면 «같은 답 물건»을 준다', () {
      final e = ev('week', '2024-01-06', until: '2026-12-31');
      final a = Logic.pastOccurrences(e);
      final b = Logic.pastOccurrences(e);
      expect(identical(a, b), isTrue,
          reason: '같은 모임을 두 번 펼친다 — 홈 화면이 전체 출석과 이번 달 순위로 '
              '두 번 부르므로 그대로 두 배가 든다');
    });

    test('모임이 «바뀌면» 다시 펼친다 (재어 둔 값이 남으면 안 된다)', () {
      final before = Logic.pastOccurrences(ev('week', '2024-01-06', until: '2024-03-01'));
      final after = Logic.pastOccurrences(ev('week', '2024-01-06', until: '2024-06-01'));
      expect(after.length, greaterThan(before.length),
          reason: '종료일을 늘렸는데 옛 답을 그대로 준다 — 새 회차가 화면에 안 나온다');
    });

    test('재어 둔 답이 «맨손으로 센 것»과 같다', () {
      final e = ev('week', '2024-01-06', until: '2024-02-10');
      final today = DateTime.now();
      String ymd(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final want = Logic.occurrences(e)
          .where((d) => d.compareTo(ymd(today)) <= 0)
          .toList();
      expect(Logic.pastOccurrences(e), want);
    });

    test('모임이 아주 많아도 표가 끝없이 커지지 않는다', () {
      for (var i = 0; i < 500; i++) {
        Logic.pastOccurrences(ev('week', '2024-01-0${i % 9 + 1}', until: '2024-02-01'));
      }
      // 넘치면 비우고 다시 담는다 — 여기까지 와서 안 터지면 된다
      final e = ev('week', '2024-01-06', until: '2024-02-10');
      expect(identical(Logic.pastOccurrences(e), Logic.pastOccurrences(e)), isTrue);
    });
  });
}
