import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 👆 「알림을 누르면 채팅으로 간다」 — 그 길이 실제로 이어져 있는가.

   서버(functions/index.js)는 «자료만»(data-only) 보낸다 — `notification` 덩어리가 없다.
   그러면 시스템이 알림을 안 그리고 **앱이 직접 그린다**(onMessage / 뒤에서 도는 처리).
   그래서 `onMessageOpenedApp`·`getInitialMessage` 는 이 앱에서 **한 번도 안 불린다** —
   직접 그린 알림의 누름은 `onDidReceiveNotificationResponse` 로 온다.
   그 자리를 안 이어 두면 **알림을 눌러도 아무 일이 안 일어난다.** */
void main() {
  String bare(String p) => File(p)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  late String src;
  setUpAll(() {
    src = bare('lib/push.dart');
    expect(src, contains('_local.initialize('), reason: '알림 준비를 못 찾았다 — 이 시험이 헛돌고 있다');
  });

  test('직접 그린 알림의 «누름»이 이어져 있다', () {
    expect(src, contains('onDidReceiveNotificationResponse:'),
        reason: '앱이 직접 그린 알림은 이 자리로 누름이 온다 — '
            '안 이으면 알림을 눌러도 채팅으로 안 간다');
    // 그 콜백이 «채팅으로 가는» 것이라야 한다
    final at = src.indexOf('onDidReceiveNotificationResponse:');
    expect(src.substring(at, src.indexOf(';', at)), contains('_goChat()'),
        reason: '눌러도 채팅으로 안 간다');
  });

  test('앱이 «꺼져 있다» 알림으로 켜진 경우도 챙긴다', () {
    expect(src, contains('getNotificationAppLaunchDetails()'),
        reason: '앱이 꺼져 있었으면 콜백이 늦어 놓칠 수 있다 — 켤 때 한 번 물어봐야 한다');
    final at = src.indexOf('getNotificationAppLaunchDetails()');
    expect(src.substring(at, at + 260), contains('didNotificationLaunchApp'),
        reason: '물어보기만 하고 «답을 안 본다»');
    expect(src.substring(at, at + 260), contains('_goChat()'));
  });

  test('시스템이 그린 알림 길도 그대로 둔다', () {
    // 나중에 서버가 `notification` 을 함께 보내면 이쪽이 쓰인다 — 지우면 안 된다
    expect(src, contains('onMessageOpenedApp'));
    expect(src, contains('getInitialMessage()'));
  });

  test('서버가 아직 «자료만» 보낸다 — 바뀌면 이 잣대도 다시 봐야 한다', () {
    final f = File(r'C:\Users\asas3\Desktop\앞산배드민턴\functions\index.js');
    if (!f.existsSync()) return;
    final s = f.readAsStringSync();
    expect(s, contains('const payload = {'), reason: '보내는 꾸러미를 못 찾았다');
    final at = s.indexOf('const payload = {');
    final blk = s.substring(at, s.indexOf('};', at));
    expect(blk.contains('data:'), isTrue);
    expect(blk.contains('notification:'), isFalse,
        reason: '서버가 시스템 알림도 함께 보내기 시작했다 — '
            '그러면 알림이 «두 번» 뜰 수 있으니 앱이 직접 그리는 자리를 다시 봐야 한다');
  });
}
