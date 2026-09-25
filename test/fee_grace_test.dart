import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee.dart';
import 'package:woorimoim/state.dart';

/* ⏳ 이용권이 끝난 뒤 3일(유예) — «켜져 있어요»라고 하면 안 된다. (2026-09-25 조사)
   유예 동안 이용권 화면은 「이용권이 켜져 있어요 · 9월 23일까지 쓸 수 있어요」(이미 지난 날),
   설정은 「9.23까지 · 눌러서 확인·복원」이라고 했다. 방장은 괜찮은 줄 알다가 며칠 뒤 모임이 잠긴다. */
void main() {
  final st = AppState.i;
  void paidUntil(DateTime d) {
    st.profile = {'code': 'C', 'slot': 'u1', 'name': '김방장'};
    st.setCouple({
      'paidUntil': d.millisecondsSinceEpoch,
      'members': {
        'u1': {'uid': 'u1', 'name': '김방장', 'role': 'owner'},
      },
    });
  }

  test('끝난 지 하루 — 아직 안 잠겼지만 «유예 중»이고 남은 날을 센다', () {
    paidUntil(DateTime.now().subtract(const Duration(days: 1)));
    expect(Fee.locked, isFalse);
    expect(Fee.inGrace, isTrue);
    expect(Fee.graceLeft, 2);
  });

  test('아직 기간 안이면 유예가 아니다', () {
    paidUntil(DateTime.now().add(const Duration(days: 10)));
    expect(Fee.inGrace, isFalse);
  });

  test('잠긴 뒤에는 유예가 아니다(잠김으로 말한다)', () {
    paidUntil(DateTime.now().subtract(const Duration(days: 10)));
    expect(Fee.locked, isTrue);
    expect(Fee.inGrace, isFalse);
  });

  test('무료 모임은 유예도 없다', () {
    paidUntil(DateTime.now().subtract(const Duration(days: 1)));
    st.setCouple({...?st.couple, 'free': true});
    expect(Fee.inGrace, isFalse);
  });

  test('이용권 화면·설정 줄이 유예를 따로 말한다', () {
    final fs = File('lib/ui/fee_screen.dart').readAsStringSync();
    expect(fs, contains('Fee.inGrace'));
    final se = File('lib/ui/settings.dart').readAsStringSync();
    final at = se.indexOf('static String _passLine(');
    expect(se.substring(at, at + 600), contains('Fee.inGrace'));
  });
}
