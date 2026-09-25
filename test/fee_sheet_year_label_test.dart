import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee_sheet.dart';

/* 📅 회비 표 — 해가 걸친 기간이면 «몇 년»이 보여야 한다. (2026-09-25 조사)
   2025-03~2026-02 표의 머리가 「3월 … 2월」, 대화방 설명은 「(3월~2월)」이었다.
   24개월이면 같은 달이 두 번씩 나와 어느 해 것인지 알 수 없었다.
   올리기 확인창은 「올해」·직접 고르기여도 늘 「6개월」이라 했다. */
void main() {
  List<String> range(int y, int m, int n) => [
        for (var i = 0; i < n; i++)
          '${y + (m - 1 + i) ~/ 12}-${((m - 1 + i) % 12 + 1).toString().padLeft(2, '0')}'
      ];

  test('한 해 안이면 예전처럼 달만', () {
    final r = range(2026, 3, 7);
    expect(FeeSheet.headLabels(r).first, '3월');
    expect(FeeSheet.spanLabel(r), '3월~9월');
  });

  test('해가 걸치면 첫 칸과 1월 칸에 해를 붙인다', () {
    final r = range(2025, 3, 12); // 25-03 … 26-02
    final h = FeeSheet.headLabels(r);
    expect(h.first, '25.3월');
    expect(h[r.indexOf('2026-01')], '26.1월');
    expect(h[1], '4월', reason: '모든 칸에 붙이면 좁은 칸에 안 들어간다');
    expect(FeeSheet.spanLabel(r), '25년 3월~26년 2월');
  });

  test('24개월이어도 같은 글자의 머리가 «해 없이» 두 번 나오지 않는다(해가 바뀌는 곳이 보인다)', () {
    final h = FeeSheet.headLabels(range(2024, 10, 24));
    expect(h.where((x) => x.contains('.1월')).length, 2, reason: '1월마다 해가 붙어야 한다');
  });

  test('올리기 확인창·대화방 설명이 실제로 고른 기간을 쓴다', () {
    final s = File('lib/ui/fee_sheet_screen.dart').readAsStringSync();
    expect(s.contains(r"'$_months개월"), isFalse, reason: '올해·직접 고르기여도 「6개월」이라 한다');
    expect(s, contains('FeeSheet.spanLabel(months)'));
    expect(s, contains('FeeSheet.headLabels(months)'));
  });
}
