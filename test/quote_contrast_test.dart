// 답장 인용 띠의 글씨 대비 — 12테마 × 밝음/어두움 전부 검사한다.
// (글씨와 같은 색을 옅게 깔면 서로 묻힌다 — 실측 최저 2.83이었다)
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/theme.dart';

double _luminance(Color c) {
  double ch(double v) {
    v = v / 255.0;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * ch((c.r * 255).roundToDouble()) +
      0.7152 * ch((c.g * 255).roundToDouble()) +
      0.0722 * ch((c.b * 255).roundToDouble());
}

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// 화면에 «실제로 보이는» 색 — 반투명은 뒤 색과 겹친 뒤에 재야 한다.
Color on(Color fg, double alpha, Color bg) =>
    Color.alphaBlend(fg.withValues(alpha: alpha), bg);

void main() {
  test('내 말풍선의 인용 글씨가 12테마 × 밝음/어두움 모두 4.5:1 이상', () {
    final fails = <String>[];
    for (final t in clubThemes) {
      for (final dark in [false, true]) {
        final th = buildTheme(t.key, dark: dark);
        final cs = th.colorScheme;
        // 내 말풍선 바탕 = primary, 그 위에 인용 띠, 그 위에 글씨
        final strip = on(quoteTintFor(th.brightness), quoteTintAlpha, cs.primary);
        final r = contrast(cs.onPrimary, strip);
        if (r < 4.5) {
          fails.add('${t.label}(${dark ? '밤' : '낮'}) ${r.toStringAsFixed(2)}');
        }
      }
    }
    expect(fails, isEmpty, reason: '답장 인용이 안 읽힌다: ${fails.join(', ')}');
  });

  test('남의 말풍선의 인용 글씨도 모두 4.5:1 이상', () {
    final fails = <String>[];
    for (final t in clubThemes) {
      for (final dark in [false, true]) {
        final th = buildTheme(t.key, dark: dark);
        final strip =
            on(th.colorScheme.primary, quoteTintAlpha, th.cardTheme.color!);
        final text = th.textTheme.bodyMedium!.color!;
        final r = contrast(text, strip);
        if (r < 4.5) {
          fails.add('${t.label}(${dark ? '밤' : '낮'}) ${r.toStringAsFixed(2)}');
        }
      }
    }
    expect(fails, isEmpty, reason: '답장 인용이 안 읽힌다: ${fails.join(', ')}');
  });

  test('띠는 글씨의 «반대쪽»이라야 한다 — 같은 색을 옅게 깔면 묻힌다', () {
    /* 왜 이 시험이 있는지: 예전에는 띠도 글씨도 onPrimary 였다.
       둘의 «거리»가 투명도 차이밖에 없어 24개 짝이 전부 미달이었다. */
    for (final dark in [false, true]) {
      final cs = buildTheme('sky', dark: dark).colorScheme;
      // 옛 방식: 띠도 글씨도 onPrimary — 띠 16%, 글씨 75%
      final oldStrip = on(cs.onPrimary, 0.16, cs.primary);
      final oldText = on(cs.onPrimary, 0.75, oldStrip);
      expect(contrast(oldText, oldStrip), lessThan(4.5),
          reason: '옛 방식이 왜 안 되는지를 붙들어 둔다');
      // 새 방식: 띠는 반대쪽, 글씨는 온전한 onPrimary
      final th = buildTheme('sky', dark: dark);
      final newStrip = on(quoteTintFor(th.brightness), quoteTintAlpha, cs.primary);
      expect(contrast(cs.onPrimary, newStrip),
          greaterThan(contrast(oldText, oldStrip) + 2));
    }
  });

  test('채팅 화면이 그 띠 색을 쓴다', () {
    final code = File('lib/ui/chat.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//[^\n]*'), '');
    expect(code.contains('quoteTint(context)'), isTrue);
    expect(code.contains('quoteTintAlpha'), isTrue);
    expect(code.contains('cs.onPrimary.withValues(alpha: .75)'), isFalse,
        reason: '글씨를 흐리게 하면 대비가 다시 무너진다');
  });
}
