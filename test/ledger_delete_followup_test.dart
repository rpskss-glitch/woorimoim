import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🗑 장부 기록을 지울 때 «딸린 표시»도 맞춘다. (2026-09-25 조사)
   · 가입비 기록(joinfee_…)을 지워도 회원 자리의 `joinFee: 'paid'` 가 남았다 —
     돈은 장부에서 빠졌는데 «받음»으로 남아 가입비 단추가 다시 안 떠 **다시 적을 길이 없었다.**
   · 회비 기록을 지우면 그 달들이 다시 «안 낸 달»이 된다 — 확인창이 그걸 말해야 한다. */
void main() {
  final s = File('lib/ui/wallet.dart').readAsStringSync();
  final at = s.indexOf("if (v != 'del') return;");
  final body = s.substring(at, s.indexOf('itemBuilder:', at));

  test('가입비 기록을 지우면 회원 자리의 가입비 표시도 푼다', () {
    expect(body, contains("startsWith('joinfee_')"));
    expect(body, contains(r"'members.$payer.joinFee': null"));
  });

  test('회비 기록을 지울 때 «그 달이 다시 안 낸 달»이 된다고 알린다', () {
    expect(body, contains('안 낸 달'));
  });
}
