import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/theme.dart';

/* 🌙 다크 모드에서도 «테마 색이 보여야» 한다.
   예전엔 다크 배경이 고정 회색이라, 모임 색을 바꿔도 바탕이 똑같아
   «테마 선택이 작동 안 하는 것»처럼 보였다(2026-09-01 아이폰 다크 모드에서). */
void main() {
  test('다크 배경이 테마마다 다르다 (하늘 ≠ 산호 ≠ 포도)', () {
    final sky = buildTheme('sky', dark: true).scaffoldBackgroundColor;
    final coral = buildTheme('coral', dark: true).scaffoldBackgroundColor;
    final grape = buildTheme('grape', dark: true).scaffoldBackgroundColor;
    expect(sky, isNot(coral), reason: '다크 바탕이 테마와 상관없이 똑같다 — 선택이 안 보인다');
    expect(coral, isNot(grape));
    expect(sky, isNot(grape));
  });

  test('다크 카드·앱바도 테마마다 다르다', () {
    Color card(String k) => buildTheme(k, dark: true).cardTheme.color!;
    expect(card('sky'), isNot(card('lemon')));
  });

  test('그래도 여전히 «어두운» 배경이다 (틴트는 옅게)', () {
    // 밝기(대략 luminance)가 낮아야 다크 모드로 읽힌다 — 틴트가 배경을 밝게 만들면 안 된다
    final bg = buildTheme('coral', dark: true).scaffoldBackgroundColor;
    expect(bg.computeLuminance(), lessThan(0.06),
        reason: '틴트가 너무 진해 다크 배경이 밝아졌다');
  });

  test('밝은 테마는 예전 그대로 (틴트는 다크에서만)', () {
    // 밝은 테마 바탕은 t.bg 를 그대로 쓴다 — 다크 틴트가 안 새어야 한다
    final light = buildTheme('sky').scaffoldBackgroundColor;
    expect(light.computeLuminance(), greaterThan(0.8),
        reason: '밝은 테마 바탕이 어두워졌다');
  });
}
