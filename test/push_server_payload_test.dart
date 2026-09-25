import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🔔 서버가 보내는 대화 알림 — 아이폰에도 뜨고, 차단한 사람 것은 안 간다.

   2026-09-25 조사:
   ① 알림에 data 만 실려 있었다. 안드로이드는 앱이 받아 직접 띄우지만
      **아이폰은 앱이 닫혀 있거나 뒤에 있으면 화면에 아무것도 안 띄운다.**
   ② 차단한 회원의 말도 알림으로 가서 첫 80자가 폰에 떴다(앱 화면에서는 가려도).

   ⚠️ 서버 파일은 옆 폴더에 있다 — «상대 경로»로 찾고, 없으면 조용히 통과하지 않고
      «건너뜀»으로 드러낸다(옛 PC 경로를 박아 몇 달간 헛돈 적이 있다). */
void main() {
  final f = File('../앞산배드민턴/functions/index.js');

  String fn() {
    final s = f.readAsStringSync();
    final at = s.indexOf('exports.pushOnMsgApsan');
    final end = s.indexOf('exports.', at + 10);
    return s.substring(at, end < 0 ? s.length : end);
  }

  test('아이폰용 알림 칸(apns alert)이 실려 간다', () {
    if (!f.existsSync()) return markTestSkipped('서버 파일을 못 찾았다: ${f.absolute.path}');
    final s = fn();
    expect(s, contains('apns:'), reason: '아이폰은 data 만으로는 닫힌 앱에 알림을 안 띄운다');
    expect(s, contains('alert: { title: head, body }'));
    expect(s, contains("sound: 'default'"), reason: '소리 없이 오면 모르고 지나간다');
    expect(s, contains("'apns-push-type': 'alert'"));
  });

  test('앱을 켜 둔 동안 아이폰 시스템 알림은 앱이 가린다 (두 번 울리지 않게)', () {
    final push = File('lib/push.dart').readAsStringSync();
    expect(push, contains('alert: false'),
        reason: '이게 없으면 apns 알림 + 앱이 띄우는 알림으로 두 번 울린다');
  });

  test('차단한 사람의 말은 그 사람을 차단한 회원에게 안 간다', () {
    if (!f.existsSync()) return markTestSkipped('서버 파일을 못 찾았다: ${f.absolute.path}');
    final s = fn();
    final loop = s.substring(s.indexOf('for (const [uid, v] of Object.entries(push))'));
    final pushAt = loop.indexOf('targets.push(');
    final blockAt = loop.indexOf('blk.includes(m.by)');
    expect(blockAt, greaterThan(0), reason: '차단 목록을 안 본다');
    expect(blockAt, lessThan(pushAt), reason: '대상에 넣은 «뒤에» 거르면 소용없다');
  });
}
