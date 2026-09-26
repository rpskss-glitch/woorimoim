import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 💵 가입비 칸이 숫자가 아니면 설정·회비 화면이 통째로 터졌다 (2026-09-26 76회차).

   월 회비(`fee.amount`)는 다듬기(`tidyCouple`)가 돈으로 바꿔 주는데,
   가입비(`fee.joinAmount`)는 빠져 있었다. 백업을 손으로 고쳤거나 다른 판이 글자로 적으면
   `as num?` 에서 터져 **설정 화면·회비 화면이 빨간 화면**이 된다 — 고칠 자리(설정)조차 못 연다. */
void main() {
  tearDown(() => AppState.i.setCouple({}));

  test('글자로 적힌 가입비도 숫자로 읽는다', () {
    AppState.i.setCouple(Store.tidyCouple({
      'fee': {'amount': 10000, 'joinAmount': '30000'}
    }));
    expect(Fee.joinAmount(), 30000);
  });

  test('엉뚱한 값이면 «안 받는 모임»으로 본다 — 터지지 않는다', () {
    for (final bad in ['abc', true, [1], {'a': 1}, -5]) {
      AppState.i.setCouple(Store.tidyCouple({
        'fee': {'joinAmount': bad}
      }));
      expect(Fee.joinAmount(), 0, reason: '$bad');
    }
  });
}
