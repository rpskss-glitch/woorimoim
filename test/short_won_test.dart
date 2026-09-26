import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee_sheet.dart';

/* 💰 회비표 지출 칸의 «만 원» 줄임 글자가 틀렸다 (2026-09-26 83회차).

   99,999원이 「10.0만」, 400원 같은 작은 지출이 「0.0만」 — 대화방에 올리는 표에서
   돈을 쓴 달이 «0»으로 읽혔다. 만 원 아래는 원으로, 반올림해 딱 떨어지면 소수점을 떼어 적는다. */
void main() {
  test('만 원 단위로 짧게 — 딱 떨어지면 소수점 없이', () {
    expect(FeeSheet.shortWon(0), '');
    expect(FeeSheet.shortWon(20000), '2만');
    expect(FeeSheet.shortWon(15000), '1.5만');
    expect(FeeSheet.shortWon(12345), '1.2만');
    expect(FeeSheet.shortWon(99999), '10만', reason: '「10.0만」');
    expect(FeeSheet.shortWon(240000), '24만');
  });

  test('만 원이 안 되는 돈은 원으로 — 「0.0만」이면 안 쓴 것처럼 보인다', () {
    expect(FeeSheet.shortWon(400), '400원');
    expect(FeeSheet.shortWon(9500), '9500원');
  });

  test('회비표 화면이 그 셈을 쓴다', () {
    final s = File('lib/ui/fee_sheet_screen.dart').readAsStringSync();
    expect(s, contains('FeeSheet.shortWon('));
    expect(s.contains('toStringAsFixed(v % 10000'), isFalse);
  });
}
