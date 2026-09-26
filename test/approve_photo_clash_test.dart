import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 📷 얼굴 사진을 실어 보낸 신청자가 «같은 이름·같은 아바타»로 승인이 막혔다 (2026-09-26 88회차).

   50회차부터 가입 신청에 얼굴 사진(pending.photo)이 실려 온다 — 사진은 그 자체로 구분된다
   (Logic.avatarClash 도 «사진을 쓰는 사람은 겹침으로 안 센다»). 그런데 승인 화면은 자기 나름의 검사를 써서
   **기존 회원의 사진만** 보고 신청자의 사진은 안 봤다 → 「거절하고 다른 아바타로 다시 신청받아주세요」. */
void main() {
  final s = File('lib/ui/members.dart').readAsStringSync();
  final at = s.indexOf('Future<void> _approve(');
  final body = s.substring(at, s.indexOf('Future<void> _reject(', at) > 0 ? s.indexOf('/* 💵', at) : at + 1500);

  test('승인 겹침 검사는 공용 셈(Logic.avatarClash)을 쓴다', () {
    expect(body, contains('Logic.avatarClash('));
  });

  test('신청자에게 얼굴 사진이 있으면 겹침으로 막지 않는다', () {
    expect(body, contains("p['photo']"));
  });
}
