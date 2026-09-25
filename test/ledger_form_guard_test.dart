import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🧾 지출 기록 창 — 두 가지 빈틈. (2026-09-25 조사)
   ① 금액 한도: 1억을 넘으면 들어올 때 다듬기(Store.money)가 0으로 만든다.
      「지출 1,500,000,000원을 기록했어요」라 해 놓고 장부에는 0원 — 월 회비 창은 이미 막고 있었다.
   ② 영수증을 올리는 «도중» 저장을 누르면 영수증 없이 저장되고 창이 닫혔다.
      그 뒤 올라간 영수증은 아무 기록에도 안 붙어 보관함에 남아 매달 요금만 나갔다. */
void main() {
  final s = File('lib/ui/wallet.dart').readAsStringSync();
  final at = s.indexOf('Future<void> _save() async {', s.indexOf('class _LedgerFormState'));
  final save = s.substring(at, s.indexOf('Widget build(', at));

  test('저장은 금액이 다듬기에 살아남을 때만', () {
    expect(save, contains('amount != Store.money(amount)'));
    expect(save.indexOf('Store.money(amount)'), lessThan(save.indexOf('addItem(')));
  });

  test('영수증을 올리는 중에는 저장하지 않는다', () {
    expect(save, contains('if (_rcptBusy)'));
    expect(save.indexOf('if (_rcptBusy)'), lessThan(save.indexOf('addItem(')));
  });

  test('창이 닫힌 뒤 올라간 영수증은 치운다', () {
    final p = s.substring(s.indexOf('Future<void> _pickReceipt('), at);
    expect(p, contains('if (!mounted) {'), reason: '닫힌 뒤 끝난 영수증이 주인 없이 남는다');
    expect(p, contains('Store.i.dropPhotos([id])'));
  });
}
