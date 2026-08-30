// 출시본(release)에서만 터지는 것들 — 여기 문제는 **가장 늦게** 발견된다.
// 개발 중에는 멀쩡한데 회원 폰에 깔린 뒤에야 드러나기 때문이다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('Dart 에서 «이름으로» 부르는 자원은 매니페스트에도 적혀 있다', () {
    /* 출시본은 «안 쓰는 자원»을 지운다(shrinkResources). 그런데 지우는 쪽은 자바·매니페스트만 보고,
       **Dart 안의 글자('@drawable/…')는 못 본다** → 그 그림이 통째로 사라진다.
       매니페스트가 한 번이라도 가리키면 살아남는다. */
    final used = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in RegExp(r"'@(drawable|mipmap|raw|color|string)/([a-z_0-9]+)'")
          .allMatches(f.readAsStringSync())) {
        used.add('@${m.group(1)}/${m.group(2)}');
      }
    }
    expect(used, isNotEmpty, reason: '이 시험이 무엇을 지키는지 알 수 있게 하나는 있어야 한다');
    for (final r in used) {
      expect(manifest.contains(r), isTrue,
          reason: '$r 을 Dart 에서만 부른다 — 출시본에서 지워져 안 보이게 된다');
    }
  });

  test('갈래마다 Firebase 설정 파일이 있다', () {
    // 없는 갈래는 빌드가 안 되거나, 더 나쁘게는 «다른 앱의 열쇠»로 붙는다
    for (final f in ['woori', 'apsan']) {
      expect(File('android/app/src/$f/google-services.json').existsSync(), isTrue,
          reason: '$f 갈래의 설정 파일이 없다');
    }
  });

  test('출시본이 안 쓰는 코드를 지우되, 지우면 안 될 것은 지켜 둔다', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle.contains('isMinifyEnabled = true'), isTrue);
    expect(gradle.contains('isShrinkResources = true'), isTrue);
    expect(gradle.contains('"proguard-rules.pro"'), isTrue,
        reason: '지키는 목록을 가리키지 않으면 지워져서 앱이 켜지자마자 죽는다');

    final rules = File('android/app/proguard-rules.pro').readAsStringSync();
    for (final must in [
      'io.flutter.**',
      'com.google.firebase.**',
      'com.dexterous.**', // 알림 패키지
      'com.google.android.play.core.**', // 안 쓰는 기능 경고 무시 — 없으면 R8 이 멈춘다
    ]) {
      expect(rules.contains(must), isTrue, reason: '$must 가 지키는 목록에 없다');
    }
  });

  test('알림 묶음 이름을 «한 곳에서만» 정한다', () {
    /* 안드로이드 8부터는 알림에 «묶음(channel)»을 달아야 하고,
       만들어 둔 묶음과 이름이 다르면 **오류 없이 그냥 버려진다** — 알림이 조용히 안 온다.
       예전에는 세 군데에 따로 적혀 있었다. */
    final src = File('lib/push.dart').readAsStringSync();
    // 글자로 직접 적힌 곳은 «정의 한 줄»뿐이라야 한다
    expect(RegExp(r"'club_msgs'").allMatches(src).length, 1,
        reason: '묶음 이름이 여러 군데 적혀 있으면 한 곳만 바뀌어도 알림이 안 온다');
    expect(RegExp(r"'모임 알림'").allMatches(src).length, 1);
    // 알림을 띄우는 두 자리(앱이 켜져 있을 때·꺼져 있을 때)가 그 값을 쓴다
    expect(RegExp(r'AndroidNotificationDetails\((Push\.)?channelId, (Push\.)?channelName')
            .allMatches(src).length, 2,
        reason: '두 자리 모두 같은 묶음을 써야 설정이 하나로 유지된다');
  });

  group('여러 곳에 적힌 «같아야 하는 값»', () {
    /// build.gradle.kts 의 갈래별 꾸러미 이름
    String appIdOf(String flavor) {
      final g = File('android/app/build.gradle.kts').readAsStringSync();
      final at = g.indexOf('create("$flavor")');
      expect(at, greaterThan(0), reason: '$flavor 갈래를 못 찾았다');
      final m = RegExp(r'applicationId = "([^"]+)"').firstMatch(g.substring(at));
      return m!.group(1)!;
    }

    test('앱이 «어느 갈래인지» 알아내는 이름이 gradle 과 같다', () {
      /* 28회차에 갈래 판단을 «꾸러미 이름»에 걸어 두었다.
         gradle 쪽만 바뀌면 앞산 앱이 **우리 모임의 Firebase 열쇠**로 붙어
         알림이 엉뚱한 곳으로 가거나 아예 안 온다 — 그런데 그 연결이 안 지켜지고 있었다. */
      final cfg = File('lib/config.dart').readAsStringSync();
      final m = RegExp("_apsanPackage = '([^']+)'").firstMatch(cfg);
      expect(m, isNotNull);
      expect(m!.group(1), appIdOf('apsan'),
          reason: 'config.dart 의 앞산 꾸러미 이름이 gradle 과 다르다');
    });

    test('갈래별 Firebase 설정 파일이 그 갈래의 꾸러미 이름을 담고 있다', () {
      for (final f in ['woori', 'apsan']) {
        final json = File('android/app/src/$f/google-services.json').readAsStringSync();
        expect(json.contains('"package_name": "${appIdOf(f)}"'), isTrue,
            reason: '$f 설정 파일에 ${appIdOf(f)} 가 없다 — 그 갈래는 Firebase 에 못 붙는다');
      }
    });

    test('회비를 다룰 수 있는 직책이 «서버 규칙»과 같다', () {
      /* 앱은 이 목록으로 「기록하기」 단추를 보여 주고, 서버는 같은 목록으로 저장을 허락한다.
         어긋나면 단추는 보이는데 저장이 거절돼 회원이 영문을 모른다. */
      /* 🔴 여기도 «옛 PC 경로»가 박혀 있어, 이 기기에서는 이 대조가 몇 달째
         그냥 넘어가고 있었다. 폴더째 옮겨 다니므로 상대 경로로 적는다. */
      final rules = File('../데이트장부/firestore.rules');
      if (!rules.existsSync()) {
        markTestSkipped('규칙 파일을 못 찾았다 — 폴더 밖에 있다');
        return;
      }

      final cfg = File('lib/config.dart').readAsStringSync();
      final appList =
          RegExp(r'treasurerTitles = \[(.*?)\]', dotAll: true).firstMatch(cfg)!.group(1)!;
      final appTitles = RegExp("'([^']+)'").allMatches(appList).map((m) => m.group(1)!).toSet();

      final money = rules.readAsStringSync();
      final at = money.indexOf('function canHandleMoney');
      expect(at, greaterThan(0));
      final block = money.substring(at, at + 400);
      final inAt = block.indexOf('in [');
      final ruleTitles = RegExp("'([^']+)'")
          .allMatches(block.substring(inAt, block.indexOf(']', inAt)))
          .map((m) => m.group(1)!)
          .toSet();

      expect(appTitles, ruleTitles, reason: '앱 $appTitles 와 서버 $ruleTitles 가 다르다');
    });

    /* 아이폰 쪽은 안드로이드와 달리 값을 지켜 주는 대조가 없었다 (96회차).
       어긋나면 «앱은 켜지는데 Firebase 에만 못 붙는» 조용한 고장이 된다. */
    test('아이폰의 Firebase 값이 config.dart 와 같다', () {
      final plist = File('ios/Runner/GoogleService-Info.plist');
      if (!plist.existsSync()) return;
      final ios = plist.readAsStringSync();
      final cfg = File('lib/config.dart').readAsStringSync();
      final block = cfg.substring(cfg.indexOf('_ios = FirebaseOptions'));
      String pick(String key) =>
          RegExp('$key:' r"\s*'([^']+)'").firstMatch(block)!.group(1)!;

      for (final v in [
        pick('apiKey'),
        pick('appId'),
        pick('messagingSenderId'),
        pick('projectId'),
        pick('storageBucket'),
        pick('iosBundleId'),
      ]) {
        expect(ios.contains('<string>$v</string>'), isTrue,
            reason: '설정 파일에 «$v» 가 없다 — 아이폰에서 Firebase 에 못 붙는다');
      }
    });

    test('아이폰 꾸러미 이름이 Xcode·설정파일·config 세 곳에서 같다', () {
      final proj = File('ios/Runner.xcodeproj/project.pbxproj');
      if (!proj.existsSync()) return;
      final cfg = File('lib/config.dart').readAsStringSync();
      final block = cfg.substring(cfg.indexOf('_ios = FirebaseOptions'));
      final id = RegExp(r"iosBundleId:\s*'([^']+)'").firstMatch(block)!.group(1)!;
      expect(proj.readAsStringSync().contains('PRODUCT_BUNDLE_IDENTIFIER = $id;'), isTrue,
          reason: 'Xcode 가 다른 이름으로 만들면 알림이 아예 안 온다');
      expect(File('ios/Runner/GoogleService-Info.plist').readAsStringSync().contains(id),
          isTrue);
    });

    test('올릴 때마다 걸리는 «암호 사용» 답이 미리 적혀 있다', () {
      final info = File('ios/Runner/Info.plist');
      if (!info.existsSync()) return;
      final s = info.readAsStringSync();
      final at = s.indexOf('ITSAppUsesNonExemptEncryption');
      expect(at, greaterThan(0),
          reason: '없으면 올릴 때마다 「규정 준수 정보 없음」으로 잡혀 TestFlight 로도 못 보낸다');
      expect(s.substring(at, at + 60).contains('<false/>'), isTrue,
          reason: '이 앱은 https 만 쓰므로 «아니오»가 맞다');
      // 알림에 꼭 필요한 것들도 같이 지켜 둔다
      expect(s.contains('remote-notification'), isTrue, reason: '없으면 앱이 꺼졌을 때 알림이 안 온다');
      expect(s.contains('NSPhotoLibraryUsageDescription'), isTrue,
          reason: '없으면 사진을 고르는 순간 앱이 튕긴다');
    });
  });
}
