// 빌드 명령이 «갈래»를 고르는지 (98회차).
//
// 이 앱은 하나의 코드로 두 가지 앱을 만든다(woori/apsan). 갈래가 있으면 Gradle 은
// `app-release.apk` 를 안 만들고 `app-woori-release.apk` 처럼 갈래 이름을 붙인다.
// 그런데 Flutter 는 `--flavor` 가 없으면 `app-release.apk` 만 찾는다
// (flutter_tools 의 `_apkFilesFor`) → 「.apk 를 못 찾겠다」며 **그 자리에서 멈춘다.**
// CI 설정과 사용안내 문서가 둘 다 갈래를 빠뜨리고 있었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// gradle 이 선언한 갈래 이름들
Set<String> flavors() {
  final g = File('android/app/build.gradle.kts').readAsStringSync();
  final at = g.indexOf('productFlavors');
  if (at < 0) return {};
  return RegExp(r'create\("(\w+)"\)')
      .allMatches(g.substring(at, g.indexOf('defaultConfig', at)))
      .map((m) => m.group(1)!)
      .toSet();
}

/// 그 글에서 «갈래를 안 고른» 안드로이드 빌드 명령 줄을 찾는다.
List<String> naked(String src, String name) {
  final bad = <String>[];
  final lines = src.split(String.fromCharCode(10));
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (!RegExp(r'flutter build (apk|appbundle)').hasMatch(l)) continue;
    if (l.trimLeft().startsWith('#')) continue; // 주석은 명령이 아니다
    if (l.contains('--flavor')) continue;
    bad.add('$name:${i + 1}  ${l.trim()}');
  }
  return bad;
}

void main() {
  test('갈래가 둘 그대로다 (woori · apsan)', () {
    expect(flavors(), {'woori', 'apsan'});
  });

  test('모든 안드로이드 빌드 명령이 «갈래»를 고른다', () {
    if (flavors().isEmpty) return; // 갈래를 없앴다면 이 검사는 뜻이 없다
    final bad = <String>[];
    for (final f in ['codemagic.yaml', '사용안내-앱만들기.md']) {
      final file = File(f);
      if (!file.existsSync()) continue;
      bad.addAll(naked(file.readAsStringSync(), f));
    }
    expect(bad, isEmpty,
        reason: '갈래를 안 고르면 «.apk 를 못 찾겠다»며 그 자리에서 멈춘다:\n  ${bad.join('\n  ')}');
  });

  test('CI 가 두 갈래를 모두 만든다', () {
    final ci = File('codemagic.yaml').readAsStringSync();
    for (final f in flavors()) {
      expect(ci.contains('--flavor $f'), isTrue, reason: '$f 갈래를 안 만든다');
    }
  });

  test('AAB 를 담아 가는 길이 «갈래 이름이 낀» 곳까지 본다', () {
    final ci = File('codemagic.yaml').readAsStringSync();
    expect(ci.contains('bundle/*/*.aab'), isTrue,
        reason: '갈래가 있으면 AAB 는 bundle/wooriRelease/ 에 나온다 — 옛 길로는 못 담는다');
    expect(ci.contains('bundle/release/*.aab'), isFalse, reason: '옛 길이 남아 있다');
  });

  test('사용안내에 «나오는 곳»도 갈래에 맞게 적혀 있다', () {
    final doc = File('사용안내-앱만들기.md').readAsStringSync();
    expect(doc.contains('app-woori-release.apk'), isTrue);
    expect(doc.contains('app-apsan-release.apk'), isTrue);
    expect(doc.contains(r'flutter-apk\app-release.apk'), isFalse,
        reason: '그 파일은 안 생긴다 — 사장님이 찾다가 헤맨다');
  });

  /* 99회차: 열쇠가 없으면 gradle 이 «빈 서명 설정»을 그대로 붙여
     서명 안 된 앱을 **말없이** 내놓는다. 폰에 안 깔리고 스토어도 안 받는데 그때서야 안다.
     열쇠는 저장소에 안 올라가므로(그게 맞다) 클라우드 빌드에서 딱 이 일이 벌어진다. */
  group('서명 열쇠', () {
    test('열쇠는 저장소에 «안 올라간다»', () {
      final ig = File('android/.gitignore').readAsStringSync();
      expect(ig.contains('key.properties'), isTrue, reason: '열쇠가 새면 남이 «업데이트»를 만든다');
      expect(RegExp(r'\*\.keystore').hasMatch(ig), isTrue);
    });

    test('gradle 은 열쇠가 없으면 «조용히» 넘어간다 — 그래서 밖에서 막아야 한다', () {
      final g = File('android/app/build.gradle.kts').readAsStringSync();
      // 이 사실이 바뀌면(예: gradle 이 스스로 멈추게 되면) 아래 CI 검사를 다시 생각해야 한다
      expect(g.contains('if (keyProps.getProperty("storeFile") != null)'), isTrue,
          reason: 'gradle 이 바뀌었다 — 이 시험의 설명을 고칠 것');
    });

    test('CI 가 열쇠 없이 빌드하지 않는다', () {
      final ci = File('codemagic.yaml').readAsStringSync();
      expect(ci.contains('android_signing:'), isTrue,
          reason: '열쇠를 받아 올 자리가 없으면 서명 안 된 앱이 나온다');
      /* ⚠️ 「android/key.properties」 라는 글자는 «주석»에도 있다 —
         그걸 짚으면 순서 검사가 헛돈다(69·83·97회차와 같은 갈래).
         실제 «단계 이름»을 앵커로 삼는다. */
      final step = ci.indexOf('- name: 서명 열쇠 확인');
      expect(step, greaterThan(0), reason: '열쇠가 있는지 확인하는 단계가 없다');
      final body = ci.substring(step, ci.indexOf('- name:', step + 10));
      expect(body.contains('android/key.properties'), isTrue);
      expect(body.contains('exit 1'), isTrue, reason: '없으면 «그 자리에서 멈춰야» 한다');
      // 확인 단계는 반드시 «빌드보다 먼저» 와야 한다
      expect(step, lessThan(ci.indexOf('flutter build apk')),
          reason: '빌드 뒤에 확인하면 이미 서명 안 된 앱이 나온 뒤다');
    });

    test('사용안내가 «열쇠가 안 올라간다»는 것을 말한다', () {
      final doc = File('사용안내-앱만들기.md').readAsStringSync();
      expect(doc.contains('GitHub에 안 올라갑니다'), isTrue);
      expect(doc.contains('Code signing identities'), isTrue,
          reason: '어디에 올려야 하는지 안 적으면 사장님이 헤맨다');
    });

    test('사용안내의 «이미 해둔 것»이 갈래 나눈 뒤 사실과 맞다', () {
      final doc = File('사용안내-앱만들기.md').readAsStringSync();
      expect(doc.contains('번들 ID 통일'), isFalse,
          reason: '이제 안드로이드는 갈래별로 다르다 — 낡은 설명이다');
      expect(doc.contains('com.taejinsoft.apsanclub'), isTrue);
    });
  });

  /* 100회차: 안내 문서의 경로에 «제어문자»가 박혀 있었다.
     `build\app\outputs\flutter-apk\app-apsan-release.apk` 를 파이썬 문자열로 쓰면서
     `\a`(벨) `\f`(폼피드) 가 그대로 먹혀 `buildpp\outputslutter-apk…` 가 되어 버렸다.
     화면에는 «안 보이는 글자»라 눈으로는 못 찾는다 — 사장님이 그 폴더를 찾으면 없다. */
  test('글에 «안 보이는 글자»가 섞여 있지 않다', () {
    final bad = <String>[];
    void scan(Directory d) {
      for (final f in d.listSync()) {
        final name = f.path.split(RegExp(r'[\/]')).last;
        if (f is Directory) {
          if (const {'build', '.dart_tool', '.git', '.gradle', 'Pods'}.contains(name)) continue;
          scan(f);
        } else if (f is File &&
            const ['.md', '.dart', '.yaml', '.kts', '.pro'].any(f.path.endsWith)) {
          final s = f.readAsStringSync();
          for (var i = 0; i < s.length; i++) {
            final c = s.codeUnitAt(i);
            if (c < 32 && c != 10 && c != 13 && c != 9) {
              bad.add('${f.path} (${c.toRadixString(16)})');
              break;
            }
          }
        }
      }
    }

    scan(Directory('.'));
    expect(bad, isEmpty, reason: '눈에 안 보이는 글자가 섞였다: ${bad.join(', ')}');
  });

  test('앱나누기 안내의 «나오는 곳»이 실제 이름과 맞다', () {
    final doc = File('앱나누기-안내.md').readAsStringSync();
    for (final f in flavors()) {
      expect(doc.contains('app-$f-release.apk'), isTrue, reason: '$f 갈래의 파일 이름이 틀렸다');
    }
  });
}
