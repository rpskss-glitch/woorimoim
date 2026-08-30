import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/theme.dart';

/* 🏷 「고른 칩의 글씨가 «실제로 그려진 색»으로 읽히는가」

   🔴 왜 이 시험이 따로 있나 —
     테마 시험은 `secondaryLabelStyle` 과 `selectedColor` 를 견줬다. 그런데
     **칩 종류마다 어느 칸을 보는지가 다르다**:
       · ChoiceChip  → 고르면 `secondaryLabelStyle`
       · FilterChip  → 고른 뒤에도 그냥 `labelStyle`
     그래서 FilterChip 만 진한 바탕에 진한 글씨가 되어, 사진첩의 「전체 3」이
     **글자 없이 체크만 뜬 빈 알약**으로 보였다(2026-08-30 실측).
     칸을 견주는 시험은 그것을 못 잡는다 — «그려진 것»을 재야 잡는다. */
double _lum(Color c) {
  double f(double v) {
    v = v / 255.0;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * f((c.r * 255).roundToDouble()) +
      0.7152 * f((c.g * 255).roundToDouble()) +
      0.0722 * f((c.b * 255).roundToDouble());
}

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  /// 그 칩이 «실제로 그린» 글씨 색
  Color paintedLabel(WidgetTester t, String text) {
    final w = t.widget<Text>(find.text(text));
    final style = w.style ?? const TextStyle();
    // 칩은 테마의 labelStyle 을 DefaultTextStyle 로 내려 준다 — 합쳐진 값을 본다
    final ctx = t.element(find.text(text));
    final merged = DefaultTextStyle.of(ctx).style.merge(style);
    return merged.color!;
  }

  testWidgets('고른 FilterChip 의 글씨가 12테마 × 밝음/어두움 모두 읽힌다', (t) async {
    final fails = <String>[];
    for (final th in clubThemes) {
      for (final dark in [false, true]) {
        final theme = buildTheme(th.key, dark: dark);
        await t.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: FilterChip(
                label: const Text('전체 3'),
                selected: true,
                onSelected: (_) {},
              ),
            ),
          ),
        ));
        await t.pumpAndSettle();

        final label = paintedLabel(t, '전체 3');
        final bg = theme.chipTheme.selectedColor!;
        final c = contrast(label, bg);
        if (c < 4.5) {
          fails.add('${th.label}(${dark ? '밤' : '낮'}) ${c.toStringAsFixed(2)}');
        }
      }
    }
    expect(fails, isEmpty,
        reason: '고른 칩의 글씨가 바탕에 묻힌다 — 무엇을 골랐는지 안 보인다: ${fails.join(', ')}');
  });

  testWidgets('안 고른 FilterChip 의 글씨도 읽힌다', (t) async {
    final fails = <String>[];
    for (final th in clubThemes) {
      for (final dark in [false, true]) {
        final theme = buildTheme(th.key, dark: dark);
        await t.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: FilterChip(
                label: const Text('전체 3'),
                selected: false,
                onSelected: (_) {},
              ),
            ),
          ),
        ));
        await t.pumpAndSettle();

        final c = contrast(paintedLabel(t, '전체 3'), theme.chipTheme.backgroundColor!);
        if (c < 4.5) {
          fails.add('${th.label}(${dark ? '밤' : '낮'}) ${c.toStringAsFixed(2)}');
        }
      }
    }
    expect(fails, isEmpty, reason: '안 고른 칩 글씨가 안 보인다: ${fails.join(', ')}');
  });

  testWidgets('ChoiceChip 도 함께 읽힌다 — 칩 종류마다 다른 칸을 본다', (t) async {
    final fails = <String>[];
    for (final th in clubThemes) {
      for (final dark in [false, true]) {
        final theme = buildTheme(th.key, dark: dark);
        await t.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: ChoiceChip(
                label: const Text('매주'),
                selected: true,
                onSelected: (_) {},
              ),
            ),
          ),
        ));
        await t.pumpAndSettle();

        final c = contrast(paintedLabel(t, '매주'), theme.chipTheme.selectedColor!);
        if (c < 4.5) {
          fails.add('${th.label}(${dark ? '밤' : '낮'}) ${c.toStringAsFixed(2)}');
        }
      }
    }
    expect(fails, isEmpty, reason: '고른 ChoiceChip 글씨가 안 보인다: ${fails.join(', ')}');
  });
}
