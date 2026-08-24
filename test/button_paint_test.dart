// 단추가 «실제로 칠해지는» 색 — 계산한 값이 아니라 화면에 나온 값을 읽는다.
// (62·63회차에 「내가 정한 값」만 재다가 두 번 헛짚었다. 그리고 한 번은 헛경보였다)
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/theme.dart';

Color paintedBg(WidgetTester t, Finder button) {
  final m = t.widgetList<Material>(find.descendant(of: button, matching: find.byType(Material)));
  return m.map((x) => x.color).whereType<Color>().last;
}

double _lum(Color c) {
  double ch(double v) {
    v = v / 255.0;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }
  return 0.2126 * ch((c.r * 255).roundToDouble()) +
      0.7152 * ch((c.g * 255).roundToDouble()) +
      0.0722 * ch((c.b * 255).roundToDouble());
}

double cr(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  for (final key in ['sky', 'lemon', 'grape']) {
    for (final dark in [false, true]) {
      testWidgets('$key(${dark ? '밤' : '낮'}) — 보통 단추는 강조색, 살짝 채운 단추는 «다른» 색', (t) async {
        final th = buildTheme(key, dark: dark);
        await t.pumpWidget(MaterialApp(
          theme: th,
          home: Scaffold(
            body: Column(children: [
              FilledButton(onPressed: () {}, child: const Text('저장')),
              FilledButton.tonal(onPressed: () {}, child: const Text('불참')),
            ]),
          ),
        ));
        await t.pumpAndSettle();
        final solid =
            paintedBg(t, find.ancestor(of: find.text('저장'), matching: find.byType(FilledButton)));
        final tonal =
            paintedBg(t, find.ancestor(of: find.text('불참'), matching: find.byType(FilledButton)));
        expect(solid, th.colorScheme.primary, reason: '보통 단추 색이 바뀌면 앱 전체 인상이 달라진다');
        expect(tonal, isNot(solid),
            reason: '「고른 것만 진하게」 구분이 사라지면 투표했는지 알 수 없다');
      });
    }
  }

  test('테마가 «정해 주지 않은» 자리들도 글씨가 읽힌다', () {
    /* 배지·입력칸·메뉴·상단바·스낵바·흐린 글씨는 앱이 색을 안 박고 기본에 맡긴다.
       ⚠️ 반투명(hintColor)은 **겹친 뒤에** 재야 한다 — 안 겹치면 멀쩡한 것도 이상하게 나온다. */
    final fails = <String>[];
    for (final t in clubThemes) {
      for (final dark in [false, true]) {
        final th = buildTheme(t.key, dark: dark);
        final cs = th.colorScheme;
        final card = th.cardTheme.color!;
        final fill = th.inputDecorationTheme.fillColor!;
        final pairs = <String, double>{
          '안읽음 배지': cr(cs.onError, cs.error),
          '입력칸 글씨': cr(cs.onSurface, fill),
          '메뉴 글씨': cr(cs.onSurface, card),
          '상단바 글씨': cr(th.appBarTheme.foregroundColor!, th.appBarTheme.backgroundColor!),
          '스낵바 글씨': cr(th.snackBarTheme.contentTextStyle!.color!, th.snackBarTheme.backgroundColor!),
          '흐린 글씨/카드': cr(Color.alphaBlend(th.hintColor, card), card),
          '흐린 글씨/바탕': cr(Color.alphaBlend(th.hintColor, th.scaffoldBackgroundColor),
              th.scaffoldBackgroundColor),
        };
        pairs.forEach((k, v) {
          if (v < 4.5) fails.add('${t.label}(${dark ? '밤' : '낮'}) $k ${v.toStringAsFixed(2)}');
        });
      }
    }
    expect(fails, isEmpty, reason: fails.join(', '));
  });
}
