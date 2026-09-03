import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🍎 «아이폰 알림이 실제로 오려면» 갖춰야 하는 것들.

   2026-09-03: 아이폰만 알림이 안 왔다. 권한도 허용했고 App ID·entitlements·프로파일·
   APNs 키까지 다 맞는데 「알림을 켜지 못했어요」만 떴다(= 토큰을 못 받은 것).
   까닭은 **GoogleService-Info.plist 가 Xcode 프로젝트에 없어 앱 꾸러미에 안 실린 것**.
   · Firestore·로그인은 Dart 쪽 설정(config.dart)으로 도니까 멀쩡해 보였고
   · 안드로이드는 google-services.json 을 gradle 이 챙겨 주니 알림이 됐다
   → 아이폰만 조용히 죽는 자리라, 여기서 못 박는다. */
void main() {
  final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
  final info = File('ios/Runner/Info.plist').readAsStringSync();

  test('GoogleService-Info.plist 가 «앱 꾸러미에 실린다»', () {
    expect(File('ios/Runner/GoogleService-Info.plist').existsSync(), isTrue,
        reason: '파일 자체가 없다');
    expect(pbx.contains('GoogleService-Info.plist'), isTrue,
        reason: 'Xcode 프로젝트에 없다 — 파일이 있어도 꾸러미에 안 실린다');
    /* ⚠️ «자원(Resources) 단계»에 있어야 실제로 실린다.
       그냥 파일 목록에만 있으면 Xcode 에는 보이는데 앱에는 안 들어간다. */
    expect(pbx.contains('GoogleService-Info.plist in Resources'), isTrue,
        reason: '자원 단계에 없다 — 꾸러미에 안 실려 아이폰 알림이 조용히 죽는다');
  });

  test('꾸러미 안 값이 이 앱의 것이다', () {
    final plist = File('ios/Runner/GoogleService-Info.plist').readAsStringSync();
    expect(plist.contains('com.taejinsoft.woorimoim'), isTrue,
        reason: '다른 앱의 설정 파일이다');
    expect(plist.contains('wedding-246e7'), isTrue, reason: '다른 프로젝트다');
  });

  test('알림을 받을 준비 — 배경 모드와 스위즐링', () {
    expect(info.contains('remote-notification'), isTrue,
        reason: '알림이 와도 앱이 깨어나지 못한다');
    /* 스위즐링을 끄면 APNs 토큰을 손으로 넘겨야 하는데, 이 앱은 그 코드가 없다 */
    final at = info.indexOf('FirebaseAppDelegateProxyEnabled');
    expect(at, greaterThan(0), reason: '스위즐링 설정이 없다');
    expect(info.substring(at, at + 120).contains('<true/>'), isTrue,
        reason: '스위즐링을 끄면 APNs 토큰이 FCM 에 안 넘어간다');
  });

  test('앱 쪽 서명·권한도 그대로 (한 번 겪은 자리)', () {
    final ent = File('ios/Runner/Runner.entitlements').readAsStringSync();
    expect(ent.contains('aps-environment'), isTrue);
    expect(pbx.contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements'),
        isTrue, reason: 'Release 에 entitlements 가 안 걸려 있다');
  });
}
