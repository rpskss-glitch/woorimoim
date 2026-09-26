import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

/* 🎂 홈 「창단 … · N년째 함께」가 한 해 모자랐다 (2026-09-26 82회차 에뮬레이터 홈에서 봄).

   「N년째」는 «N번째 해»다 — 창단 2023-03-14 인 모임은 2026-09-26 에 **4년째**다.
   그런데 꽉 찬 햇수(3)를 그대로 적어 「3년째」라 했고, 첫해에는 아예 안 보였다.
   365일로 나눠 윤년이 끼면 하루 어긋나기도 했다. */
void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  test('N년째 = 꽉 찬 햇수 + 1', () {
    expect(Logic.yearNth(d(2023, 3, 14), d(2026, 9, 26)), 4);
    expect(Logic.yearNth(d(2026, 3, 14), d(2026, 9, 26)), 1, reason: '첫해도 「1년째」');
    expect(Logic.yearNth(d(2025, 9, 27), d(2026, 9, 26)), 1, reason: '하루 모자라면 아직 첫해');
    expect(Logic.yearNth(d(2025, 9, 26), d(2026, 9, 26)), 2, reason: '딱 한 해 되는 날부터 2년째');
  });

  test('윤년 2월 29일에 만든 모임', () {
    expect(Logic.yearNth(d(2024, 2, 29), d(2025, 2, 28)), 1);
    expect(Logic.yearNth(d(2024, 2, 29), d(2025, 3, 1)), 2);
  });

  test('앞날 창단은 0 — 적지 않는다', () {
    expect(Logic.yearNth(d(2027, 1, 1), d(2026, 9, 26)), 0);
  });

  test('홈이 그 셈을 쓴다', () {
    final s = File('lib/ui/home.dart').readAsStringSync();
    expect(s, contains('Logic.yearNth('));
    expect(s.contains('inDays ~/ 365'), isFalse);
  });
}
