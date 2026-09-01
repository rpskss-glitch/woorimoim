import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/* 🚪 로그아웃 ≠ 탈퇴.
   · 로그아웃: 이 폰 세션만 지우고 «회원 자리는 서버에 그대로» → 다시 로그인하면 이어받는다.
   · 탈퇴(내 자료 지우기): 회원 자리와 개인정보를 지운다 (deleteMyData).
   둘이 설정에 «따로» 있어야 하고, 로그아웃은 위험(빨강)이 아니어야 한다. */
void main() {
  final s = File('lib/ui/settings.dart').readAsStringSync();

  test('설정에 로그아웃과 탈퇴가 «따로» 있다', () {
    expect(s.contains("label: const Text('로그아웃')"), isTrue,
        reason: '로그아웃 단추가 없다');
    expect(s.contains('모임 탈퇴 · 내 자료 지우기'), isTrue,
        reason: '탈퇴(내 자료 지우기)가 없어졌다 — 로그아웃과 탈퇴는 둘 다 있어야 한다');
  });

  test('로그아웃은 회원 자리를 지우지 않는다 (세션만 비운다)', () {
    // 로그아웃 블록은 clearProfile 로 «이 폰»만 지운다. deleteMyData(탈퇴)를 부르면 안 된다.
    final at = s.indexOf("okLabel: '로그아웃'");
    expect(at, greaterThan(0));
    final blk = s.substring(at, s.indexOf('clearProfile()', at) + 20);
    expect(blk.contains('deleteMyData'), isFalse,
        reason: '로그아웃이 탈퇴를 부른다 — 다시 로그인해도 자리가 없어진다');
    expect(blk.contains('clearProfile'), isTrue,
        reason: '로그아웃이 이 폰 세션을 안 비운다');
  });

  test('로그아웃은 «위험(빨강)»으로 칠하지 않는다 (되돌릴 수 있다)', () {
    // 라벨 근처에 dangerText 가 없어야 한다 (탈퇴 단추와 달리)
    final at = s.indexOf("label: const Text('로그아웃')");
    expect(at, greaterThan(0));
    final around = s.substring((at - 400).clamp(0, s.length), at + 40);
    expect(around.contains('dangerText'), isFalse,
        reason: '로그아웃을 빨강으로 칠하면 탈퇴처럼 보여 «되돌릴 수 없는 일»로 오해한다');
  });
}
