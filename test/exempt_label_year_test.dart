import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🙇 회비 표 면제 확인창·안내에 «몇 년» 몇 월인지. (2026-09-26 조사)
   해가 걸친 표(24개월 등)에는 「3월」 칸이 두 개인데, 확인창은 「3월 회비를 면제할까요?」라
   어느 해 3월인지 알 수 없었다. */
void main() {
  test('면제 확인·안내는 해까지 적는다', () {
    final s = File('lib/ui/fee_sheet_screen.dart').readAsStringSync();
    final at = s.indexOf('Future<void> _toggleExempt(');
    final body = s.substring(at, s.indexOf('static String _won(', at));
    expect(body.contains('final label = FeeSheet.monthLabel(month);'), isFalse);
    expect(body, contains("년 '"));
  });
}
