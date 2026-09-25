import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 💵 직책만 있는 총무(회계·총무보)가 «남의 자리»에 표시를 적으려 할 때.

   2026-09-25 조사: 가입비 «받음·면제»와 달별 «면제»는 그 회원 자리(members.<번호>)에 적는데,
   서버는 남의 자리를 운영진만 고치게 한다. 운영진이 아닌 「회계」가 가입비 「받았어요」를 누르면
     · 장부에는 수입이 적히고 (장부는 총무 직책이면 쓸 수 있다)
     · 표시는 거절돼 「기록하지 못했어요」 — 가입비 단추가 영영 남고, 다시 눌러도 또 실패했다.
   이제 아무것도 적기 «전에» 운영진인지 보고 이유를 알려 준다. */
String bodyOf(String src, String head) {
  final at = src.indexOf(head);
  expect(at, greaterThanOrEqualTo(0), reason: '$head 을 못 찾았다');
  var depth = 0;
  for (var i = src.indexOf('{', at + head.length); i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}' && --depth == 0) return src.substring(at, i + 1);
  }
  return src.substring(at);
}

void main() {
  test('가입비: 운영진 확인이 장부 쓰기보다 먼저다', () {
    final b = bodyOf(File('lib/ui/wallet.dart').readAsStringSync(), 'Future<void> _joinFee(');
    final guard = b.indexOf('if (!AppState.i.isAdmin)');
    final ledger = b.indexOf('Store.i.addItem(');
    final mark = b.indexOf('Store.i.patchCouple(');
    expect(guard, greaterThan(0), reason: '운영진인지 안 본다 — 돈만 적히고 표시는 거절된다');
    expect(guard, lessThan(ledger), reason: '장부에 적은 «뒤에» 막으면 반쪽 기록이 남는다');
    expect(guard, lessThan(mark));
  });

  test('달별 면제: 운영진 확인이 확인창·쓰기보다 먼저다', () {
    final b = bodyOf(
        File('lib/ui/fee_sheet_screen.dart').readAsStringSync(), 'Future<void> _toggleExempt(');
    final guard = b.indexOf('if (!AppState.i.isAdmin)');
    final ask = b.indexOf('confirmSheet(');
    final write = b.indexOf('Store.i.patchCouple(');
    expect(guard, greaterThan(0), reason: '확인까지 받아 놓고 늘 거절된다');
    expect(guard, lessThan(ask), reason: '「면제할까요?」를 물어 놓고 안 되면 헛수고다');
    expect(guard, lessThan(write));
  });

  test('막을 때 «어떻게 하면 되는지»를 알려 준다', () {
    for (final f in ['lib/ui/wallet.dart', 'lib/ui/fee_sheet_screen.dart']) {
      expect(File(f).readAsStringSync(), contains('방장에게 「운영진 권한」을 받아주세요'),
          reason: '$f — 막기만 하면 왜 안 되는지 모른다');
    }
  });
}
