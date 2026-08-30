import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🔔 「아이폰에서 알림이 실제로 올 수 있는 모양인가」

   🔴 2026-08-30 아이폰 첫 판에서 실제로 겪은 일 —
     「알림 켜기」를 누르면 권한 창은 뜨고 「허용」도 눌리는데,
     화면에는 계속 「알림 권한을 허용해야 받을 수 있어요」만 떴다.
     안드로이드는 잘 됐다.

   까닭은 권한이 아니었다. **아이폰 쪽 설정이 통째로 빠져 있었다**:
     ① 앱에 `Runner.entitlements` 가 없었다 (`aps-environment` 없음)
     ② Xcode 의 Release 설정이 그 파일을 안 봤다
     ③ App ID 에 「푸시 알림」 기능이 안 켜져 있었다 (인앱결제만 켜져 있었다)
   셋 중 하나만 빠져도 애플 알림망 등록이 안 되고, APNs 토큰이 영영 안 와
   FCM 토큰도 못 받는다 → 앱은 «실패»만 알고, 권한 탓으로 잘못 안내했다.

   ①②는 이 저장소 안의 파일이라 여기서 지킨다.
   ③은 애플 계정 쪽이라 여기서 못 본다 — 대신 [[project_woorimoim_ios_appstore]] 에 적어 두었다. */
void main() {
  final ent = File('ios/Runner/Runner.entitlements');
  final proj = File('ios/Runner.xcodeproj/project.pbxproj');

  test('아이폰 알림 권한 파일이 있다', () {
    expect(ent.existsSync(), isTrue,
        reason: 'ios/Runner/Runner.entitlements 가 없다 — '
            '아이폰에서 알림이 통째로 안 온다(권한 창은 떠서 더 헷갈린다)');
  });

  test('그 파일에 «aps-environment» 가 들어 있다', () {
    final s = ent.readAsStringSync();
    expect(s.contains('aps-environment'), isTrue,
        reason: '알림망 등록 허가가 없다 — APNs 토큰이 안 온다');
    /* App Store 배포 프로파일이 담은 값과 «같아야» 서명이 통과한다.
       이 앱의 아이폰 판은 CI 에서 Release 로만 짓고 배포 프로파일로 서명한다. */
    expect(s.contains('<string>production</string>'), isTrue,
        reason: 'development 로 두면 배포 프로파일과 어긋나 서명이 막힌다');
  });

  test('Xcode 의 «Release» 설정이 그 파일을 본다', () {
    /* 파일만 만들어 두고 연결을 안 하면 아무 일도 안 일어난다 —
       빌드는 멀쩡히 되고, 아이폰에서만 조용히 알림이 안 온다. */
    final s = proj.readAsStringSync();
    expect(s.contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'), isTrue,
        reason: '권한 파일을 만들어 두고 Xcode 에 연결하지 않았다');

    // 그 줄이 «배포 서명»을 하는 자리(Release)에 있어야 뜻이 있다
    final at = s.indexOf('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;');
    final near = s.substring(at, (at + 400).clamp(0, s.length));
    expect(near.contains('Apple Distribution'), isTrue,
        reason: '권한 파일이 Release(배포) 설정에 안 걸려 있다 — 스토어 판에는 안 들어간다');
  });

  test('알림이 «켜져 있어야» 뜻이 있는 배경 모드도 그대로다', () {
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    expect(info.contains('remote-notification'), isTrue,
        reason: '배경 알림 모드가 빠졌다 — 앱이 꺼져 있을 때 알림을 못 받는다');
  });

  test('«거절»과 «등록 실패»를 다른 말로 안내한다', () {
    /* 둘을 같은 말로 덮으면, 허용을 눌렀는데도 「허용해야 한다」는 말을 듣는다.
       아이폰은 한 번 거절하면 창이 다시 안 뜨므로 «설정으로 가라»고 해야 한다. */
    final push = File('lib/push.dart').readAsStringSync();
    expect(push.contains('String offReason('), isTrue,
        reason: '실패 까닭을 갈라 말하는 자리가 없다');
    expect(push.contains('설정 → 알림'), isTrue,
        reason: '아이폰에서 거절한 회원에게 «어디로 가라»고 안 알려 준다');

    // 화면들이 그 말을 실제로 쓰는지 — 만들어 두고 안 쓰면 소용없다
    for (final f in const ['lib/ui/home.dart', 'lib/ui/settings.dart']) {
      expect(File(f).readAsStringSync().contains('offReason('), isTrue,
          reason: '$f 가 옛 안내문을 그대로 쓴다');
    }
  });
}
