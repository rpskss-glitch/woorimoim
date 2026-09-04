// 갈래(우리모임/앞산)의 «겉»과 «속»이 어긋나지 않는가 (141회차).
//
// config.dart 가 스스로 적어 둔 경계:
//   「겉은 앞산인데 속은 우리 모임인 앱(이름·Firebase 열쇠가 어긋난 앱)이 조용히 나왔다」
// 그런데 지키는 시험은 **꾸러미 이름과 appId 뿐**이었다.
//   · 보여 주는 «앱 이름»은 gradle 과 config.dart 두 곳에 따로 적혀 있는데 대조가 없었다
//     → 한쪽만 고치면 런처에는 「모임 매니저」, 앱 안에는 「우리 모임」이 뜬다
//   · Firebase 값도 appId 만 봤다 — apiKey·저장소·보내는이 번호가 어긋나면
//     **알림이 엉뚱한 곳으로 가거나 아예 안 온다**(config.dart 가 걱정하던 바로 그 일)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _flavors = {
  // ⚠️ 판매용은 «2»가 붙는다 — 옛 이름은 Play 에서 다시 못 쓴다(2026-09-04)
  'woori': 'com.taejinsoft.woorimoim2',
  'apsan': 'com.taejinsoft.apsanclub',
};

String read(String p) => File(p).readAsStringSync();

/// gradle 의 그 갈래 칸에 적힌 앱 이름
String nameInGradle(String flavor) {
  final g = read('android/app/build.gradle.kts');
  final at = g.indexOf('create("$flavor")');
  expect(at, greaterThan(0), reason: 'gradle 에 $flavor 갈래가 없다');
  final m = RegExp(r'resValue\("string", "app_name", "([^"]+)"\)')
      .firstMatch(g.substring(at));
  expect(m, isNotNull, reason: '$flavor 갈래에 app_name 이 없다');
  return m!.group(1)!;
}

/// 그 갈래의 Firebase 설정 — 꾸러미 이름으로 짝지어 고른다
Map<String, String> keysInJson(String flavor) {
  final j = jsonDecode(read('android/app/src/$flavor/google-services.json'))
      as Map<String, dynamic>;
  final pkg = _flavors[flavor]!;
  final client = (j['client'] as List).cast<Map<String, dynamic>>().firstWhere(
        (c) =>
            ((c['client_info'] as Map)['android_client_info']
                as Map)['package_name'] ==
            pkg,
        orElse: () => throw StateError('$flavor 설정 파일에 $pkg 가 없다'),
      );
  final info = j['project_info'] as Map<String, dynamic>;
  return {
    'appId': (client['client_info'] as Map)['mobilesdk_app_id'] as String,
    'apiKey': ((client['api_key'] as List).first as Map)['current_key'] as String,
    'senderId': info['project_number'] as String,
    'bucket': info['storage_bucket'] as String,
    'projectId': info['project_id'] as String,
  };
}

/// config.dart 의 그 갈래 FirebaseOptions 덩어리
String optionsBlock(String flavor) {
  final c = read('lib/config.dart');
  final name = flavor == 'woori' ? '_androidWoori' : '_androidApsan';
  final at = c.indexOf('$name = FirebaseOptions(');
  expect(at, greaterThan(0), reason: 'config.dart 에 $name 이 없다');
  final end = c.indexOf(');', at);
  return c.substring(at, end);
}

void main() {
  test('보여 주는 «앱 이름»이 gradle 과 앱 안에서 같다', () {
    /* 한쪽만 고치면 런처 아이콘 아래와 앱 안 이름이 달라진다 — 회원은 다른 앱인 줄 안다. */
    final cfg = read('lib/config.dart');
    final m = RegExp(r"appName => isApsan \? '([^']+)' : '([^']+)'").firstMatch(cfg);
    expect(m, isNotNull, reason: 'config.dart 의 appName 모양이 바뀌었다');
    expect(m!.group(1), nameInGradle('apsan'),
        reason: '앞산 이름이 gradle 과 다르다');
    expect(m.group(2), nameInGradle('woori'),
        reason: '우리 모임 이름이 gradle 과 다르다');
  });

  test('두 갈래의 앱 이름이 서로 다르다', () {
    expect(nameInGradle('woori'), isNot(nameInGradle('apsan')));
  });

  test('Firebase 값이 «네 가지 모두» 설정 파일과 같다', () {
    /* 예전 시험은 appId 만 봤다. apiKey·저장소·보내는이 번호가 어긋나면
       앱은 켜지는데 **알림이 엉뚱한 곳으로 가거나 아예 안 온다.** */
    for (final f in _flavors.keys) {
      final want = keysInJson(f);
      final block = optionsBlock(f);
      for (final k in ['appId', 'apiKey', 'senderId', 'bucket', 'projectId']) {
        expect(block.contains(want[k]!), isTrue,
            reason: '$f: $k 가 설정 파일(${want[k]})과 config.dart 가 다르다');
      }
    }
  });

  test('두 갈래가 «서로 다른» Firebase 앱을 쓴다', () {
    // 같은 appId 를 쓰면 앞산 회원의 알림이 우리 모임 앱으로 간다
    expect(keysInJson('woori')['appId'], isNot(keysInJson('apsan')['appId']));
  });

  test('갈래별 설정 파일에 그 갈래의 꾸러미가 «반드시» 있다', () {
    for (final f in _flavors.keys) {
      expect(keysInJson(f)['appId'], isNotEmpty);
    }
  });
}
