import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/push.dart';

/* 🔔 「알림 소리·진동 바꾸기」 — 폰의 이 앱 알림 설정을 여는 길.

   2026-09-03: 꾸러미(app_settings)를 쓰다가 «눌러도 아무 반응 없음»을 겪었다.
   그 꾸러미는 화면을 못 찾으면 아무것도 안 하고 «됐다»고 돌려줘서, 앱이 안내조차 못 했다.
   이제 우리 화면에서 직접 열고, 못 열면 «못 열었다»(false)를 돌려받아 길을 알려 준다. */
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('club/appsettings');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null);
  });

  test('폰이 열어 주면 true — 앱은 아무 말도 안 한다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async {
      expect(call.method, 'openNotificationSettings');
      return true;
    });
    expect(await Push.i.openPhoneNotificationSettings(), isTrue);
  });

  test('못 열면 false — 앱이 «어디로 가라»고 안내할 수 있다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async => false);
    expect(await Push.i.openPhoneNotificationSettings(), isFalse);
  });

  test('터져도 «안 죽고» false — 눌렀다고 앱이 멈추면 안 된다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async {
      throw PlatformException(code: 'x');
    });
    expect(await Push.i.openPhoneNotificationSettings(), isFalse);
  });

  test('길이 없는 폰(구현 없음)에서도 false', () async {
    // 핸들러를 안 걸면 MissingPluginException — 그것도 삼켜야 한다
    expect(await Push.i.openPhoneNotificationSettings(), isFalse);
  });

  group('네이티브 쪽이 «같은 이름»의 길을 갖고 있다', () {
    test('안드로이드 MainActivity 가 그 길을 연다', () {
      final kt = File(
              'android/app/src/main/kotlin/com/taejinsoft/woorimoim/MainActivity.kt')
          .readAsStringSync();
      expect(kt.contains('club/appsettings'), isTrue, reason: '길 이름이 안 맞는다');
      expect(kt.contains('openNotificationSettings'), isTrue);
      expect(kt.contains('ACTION_APP_NOTIFICATION_SETTINGS'), isTrue,
          reason: '이 앱 «알림» 화면이 아니라 딴 데를 연다');
      /* ⚠️ 실패를 «삼키고 성공»이라 하면 안 된다 — 그게 꾸러미의 문제였다 */
      expect(kt.contains('result.success(false)'), isTrue,
          reason: '못 열었을 때 «못 열었다»고 돌려주지 않는다');
    });

    test('아이폰 AppDelegate 도 같은 길을 연다', () {
      final sw = File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(sw.contains('club/appsettings'), isTrue);
      expect(sw.contains('openSettingsURLString'), isTrue,
          reason: '아이폰은 앱 설정 화면을 열어야 한다');
    });
  });
}
