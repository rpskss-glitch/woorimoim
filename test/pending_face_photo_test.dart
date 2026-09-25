import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

/* 📷 가입 화면에서 고른 «내 사진»이 승인을 거치면 사라지던 것. (2026-09-26 조사)
   신청을 보낸 «뒤»에 사진을 회원 칸(members.<나>.photo)에 적으려 했는데,
   신청 대기 중인 사람은 아직 회원이 아니라 서버가 거절 → 올린 사진을 도로 지웠다.
   (승인이 필요한 새 회원은 거의 전부 이 길이다 — 고른 얼굴이 조용히 사라졌다)
   → 신청(pending)에 사진 번호를 함께 적고, 승인할 때 회원 칸으로 옮긴다.
     거절·취소하면 그 사진도 치운다(아무도 못 보는 파일에 요금만 나간다). */
void main() {
  test('승인할 때 신청의 사진을 회원 칸으로 옮긴다', () {
    final cur = {
      'pending': {'u9': {'uid': 'u9', 'name': '새회원', 'photo': 'st:C/abc'}},
      'members': {},
    };
    final patch = Logic.approvePatch(cur, (cur['pending'] as Map)['u9'] as Map<String, dynamic>, 1)!;
    expect(((patch['members'] as Map)['u9'] as Map)['photo'], 'st:C/abc');
  });

  test('사진이 없으면 photo 칸을 안 만든다', () {
    final cur = {'pending': {'u9': {'uid': 'u9', 'name': '새회원'}}, 'members': {}};
    final patch = Logic.approvePatch(cur, (cur['pending'] as Map)['u9'] as Map<String, dynamic>, 1)!;
    expect(((patch['members'] as Map)['u9'] as Map).containsKey('photo'), isFalse);
  });

  test('가입 신청에 사진 번호를 함께 적는다', () {
    final s = File('lib/ui/onboarding.dart').readAsStringSync();
    final at = s.indexOf('// 가입 신청 — 내 신청만 보낸다');
    final part = s.substring(at, at + 1400);
    expect(part, contains("if (facePhoto != null) 'photo': facePhoto"));
  });

  test('거절·신청 취소하면 신청 사진을 치운다', () {
    final m = File('lib/ui/members.dart').readAsStringSync();
    final r = m.substring(m.indexOf('Future<void> _reject('), m.indexOf('Future<void> _kick('));
    expect(r, contains("Store.i.dropPhotos([p['photo'] as String?])"));
    final w = File('lib/ui/wait.dart').readAsStringSync();
    expect(w, contains('dropPhotos('));
  });
  test('승인 대기 줄에 신청 사진을 보여 준다', () {
    final m = File('lib/ui/members.dart').readAsStringSync();
    expect(m, contains("photoId: p['photo'] as String"));
  });
}
