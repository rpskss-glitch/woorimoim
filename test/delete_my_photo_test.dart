import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🗑 「내 자료 지우기」 — 내 얼굴 사진(아바타 원본)도 지운다. (2026-09-26 조사)
   운영진이 내보낼 때(_kick)는 사진 원본을 치우는데, 스스로 지울 때는 회원 칸만 지우고
   보관함의 얼굴 사진은 그대로 남았다. 얼굴 사진은 개인정보다 — 애플 5.1.1(v)의
   «계정·자료 삭제»가 바로 이것을 지우라는 것이다. (former 에는 사진을 안 남기므로 아무도 못 본다) */
void main() {
  test('지우기가 됐으면 내 사진 원본을 치운다', () {
    final s = File('lib/store.dart').readAsStringSync();
    final at = s.indexOf('Future<bool> deleteMyData(');
    final body = s.substring(at, s.indexOf('Future<bool> verifySubscription(', at));
    expect(body, contains("myPhoto = me['photo']"));
    final drop = body.indexOf('dropPhotos([myPhoto])');
    expect(drop, greaterThan(0), reason: '얼굴 사진이 보관함에 남는다');
    expect(body.substring(drop - 60, drop), contains('if (done'), reason: '지우기가 거절됐는데 사진만 지우면 안 된다');
  });
}
