// 날짜·금액을 글자로 바꾸는 자리 — 화면 곳곳이 쓰는데 한 번도 시험한 적이 없었다.
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/ui/common.dart';

void main() {
  group('0을 안 채운 날짜', () {
    /* 이 앱은 날짜를 **글자 그대로** 견주고, «열 글자»가 아니면 날짜로 안 본다.
       그래서 '2026-8-5' 한 건이 세 가지를 한꺼번에 망가뜨렸다:
         · 차례가 뒤집힘 ('2026-8-5' > '2026-08-21' 이 참)
         · 화면에 「날짜 없음」
         · 반복 계산은 **오늘 날짜**를 써서 모임이 엉뚱한 날로 잡힘 */
    test('들어올 때 0을 채운다', () {
      final e = Store.tidy([{'id': 'e1', 'type': 'event', 'date': '2026-8-5'}]).first;
      expect(e['date'], '2026-08-05');
    });

    test('채우고 나면 화면·반복 계산이 맞는다', () {
      final e = Store.tidy([
        {'id': 'e1', 'type': 'event', 'date': '2026-8-5', 'repeat': 'none'}
      ]).first;
      expect(fmtDateFull(e['date'] as String?), '8월 5일 (수)');
      expect(parseYmd(e['date'] as String?), DateTime(2026, 8, 5),
          reason: '열 글자가 아니면 «오늘»로 둔갑한다');
      expect(Logic.occurrences(e, to: DateTime(2026, 12, 31)), ['2026-08-05']);
    });

    test('차례가 뒤집히지 않는다', () {
      final rows = Store.tidy([
        {'id': 'a', 'type': 'event', 'date': '2026-8-5'},
        {'id': 'b', 'type': 'event', 'date': '2026-08-21'},
      ])..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
      expect(rows.map((x) => x['date']).toList(), ['2026-08-05', '2026-08-21']);
    });

    test('「끝나는 날」도 같이 채운다', () {
      final e = Store.tidy([
        {'id': 'e1', 'type': 'event', 'date': '2026-1-1', 'until': '2026-3-9'}
      ]).first;
      expect(e['until'], '2026-03-09');
    });

    test('있을 수 없는 날짜는 «고치지 않는다»', () {
      // 0을 채우면 2026-13-45 가 조용히 2027-02-14 로 넘어가 버린다 — 딴 날이 된다
      expect(Store.fixDate('2026-13-45'), '2026-13-45');
      expect(Store.fixDate('2026-00-10'), '2026-00-10');
      expect(fmtDateFull('2026-13-45'), isNot('2월 14일 (일)'),
          reason: '있을 수 없는 날을 «그럴듯한 날»로 보여주면 안 된다');
    });

    test('알 수 없는 글자는 그대로 둔다', () {
      expect(Store.fixDate('엉터리'), '엉터리');
      expect(fmtDateFull('엉터리'), '날짜 없음');
    });
  });

  group('금액', () {
    test('자리마다 쉼표를 찍는다', () {
      expect(fmtWon(0), '0원');
      expect(fmtWon(20000), '20,000원');
      expect(fmtWon(1234567), '1,234,567원');
    });
    test('음수와 소수도 말이 되게', () {
      expect(fmtWon(-500000), '-500,000원');
      expect(fmtWon(1234.6), '1,235원');
      expect(fmtWon(null), '0원');
    });
  });
}
