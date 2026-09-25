import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 💳 탈퇴(계정 삭제)해도 스토어 정기결제는 안 끊긴다 — 방장에게 그걸 «미리» 말한다.
   애플 5.1.1(v): 자동갱신 구독이 있는 앱은 계정을 지울 때
   「스토어에서 해지하기 전까지 계속 청구된다」를 알려야 한다. (2026-09-25 조사)
   이용권을 내는 사람은 방장인데, 탈퇴 확인창에 그 말이 한 줄도 없었다 —
   나간 뒤에도 매달 48,000원이 빠져나가 «몰래 결제»로 보인다. */
void main() {
  final s = File('lib/ui/settings.dart').readAsStringSync();
  final at = s.indexOf('Future<void> _deleteMyData(');
  final body = s.substring(at, s.indexOf('Future<void> _editMe(', at));

  test('이용권을 내는 방장이면 «정기결제는 따로 해지»를 알린다', () {
    expect(body, contains('Fee.iPay && !Fee.exempt'));
    expect(body, contains('해지되지 않아요'));
  });

  test('그 말은 확인창 «안»에 들어간다(누르기 전에 본다)', () {
    final ask = body.indexOf('confirmSheet(');
    final use = body.indexOf(r'$billNote');
    expect(use, greaterThan(ask), reason: '확인창 글에 붙어야 한다');
    expect(use, lessThan(body.indexOf('deleteMyData(code)')));
  });
}
