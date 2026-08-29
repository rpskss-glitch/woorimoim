import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/main.dart';

/* 폰을 「어두운 화면」으로 해 둔 회원이 보는 첫 화면도 어두워야 한다.
   MaterialApp 은 `darkTheme` 을 안 주면 «밝은 테마를 그대로» 쓴다 —
   조용히 넘어가서 눈에 안 띄지만, 어두운 방에서 앱을 켠 회원에게는
   흰 화면이 통째로 번쩍인다. */
void main() {
  testWidgets('폰이 어두운 화면이면 「못 받았어요」 화면도 어둡게 나온다', (t) async {
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);

    await t.pumpWidget(const NeedNetworkApp());
    final ctx = t.element(find.text('모임 정보를 받지 못했어요'));
    expect(Theme.of(ctx).brightness, Brightness.dark,
        reason: '폰은 어두운 화면인데 이 화면만 밝은 테마로 나온다 — '
            'MaterialApp 에 darkTheme 이 빠졌다');
  });

  testWidgets('밝은 화면이면 그대로 밝게 나온다', (t) async {
    t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);

    await t.pumpWidget(const NeedNetworkApp());
    final ctx = t.element(find.text('모임 정보를 받지 못했어요'));
    expect(Theme.of(ctx).brightness, Brightness.light);
  });

  test('앱 화면 «전부»가 밝음·어두움 두 벌을 갖는다', () {
    // 새 MaterialApp 을 만들면서 darkTheme 을 빠뜨리는 것을 여기서 잡는다
    final src = File('lib/main.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'//.*'), '')
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
    final apps = RegExp(r'MaterialApp\(').allMatches(src).toList();
    expect(apps, isNotEmpty, reason: 'MaterialApp 을 못 찾았다 — 이 시험이 헛돌고 있다');
    for (final m in apps) {
      // 괄호를 맞춰 «그 MaterialApp 만» 떼어낸다 (다음 것으로 새지 않게)
      var depth = 0, i = m.end - 1;
      for (; i < src.length; i++) {
        if (src[i] == '(') depth++;
        if (src[i] == ')') { depth--; if (depth == 0) break; }
      }
      final call = src.substring(m.end, i);
      expect(call, contains('theme:'), reason: '테마를 안 준 화면이 있다');
      expect(call, contains('darkTheme:'),
          reason: '어두운 테마가 빠진 화면이 있다 — 폰이 어두운 화면이어도 '
              '이 화면만 흰색으로 번쩍인다 (main.dart 의 ${apps.indexOf(m) + 1}번째 MaterialApp)');
    }
  });
}
