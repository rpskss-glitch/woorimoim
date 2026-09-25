import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 📖 회원 안내 — 폰 설정에서 찾을 «이름»은 모임 이름이 아니라 «앱 이름»이다. (2026-09-25 조사)
   「알림이 안 오면 폰 설정에서 「앞산 배드민턴」 알림이 꺼져 있는지 보세요」라고 했는데,
   폰 설정의 앱 목록에는 「우리 모임」으로 나온다 — 모임 이름으로는 찾을 수가 없다. */
void main() {
  test('알림 안내는 앱 이름(Cfg.appName)을 쓴다', () {
    final s = File('lib/ui/member_guide.dart').readAsStringSync();
    expect(s.contains(r"폰 설정에서 「$title」 알림"), isFalse);
    expect(s, contains(r'폰 설정에서 「${Cfg.appName}」 알림'));
  });
  test('아이폰 알림 안내도 앱 이름을 쓴다(앞산 판은 «앞산 배드민턴»으로 뜬다)', () {
    final s = File('lib/push.dart').readAsStringSync();
    expect(s.contains('설정 → 알림 → 우리 모임'), isFalse);
    expect(s, contains(r'설정 → 알림 → ${Cfg.appName}'));
  });
}
