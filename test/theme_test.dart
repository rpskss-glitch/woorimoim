// 글씨 대비 시험 — 강조색 위에 얹는 글씨가 읽히는지 12테마 × 밝음/어두움 전부 검사한다.
// (밝은 화면에서 옅은 강조색 위에 흰 글씨를 쓰면 2.5:1밖에 안 나와 밖에서 안 보인다)
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/theme.dart';

/// 웹 표준(WCAG)이 쓰는 밝기 계산.
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
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('강조색 위 글씨는 12테마 × 밝음/어두움 모두 4.5:1 이상', () {
    final fails = <String>[];
    for (final t in clubThemes) {
      for (final dark in [false, true]) {
        final s = buildTheme(t.key, dark: dark).colorScheme;
        final r = contrast(s.primary, s.onPrimary);
        if (r < 4.5) {
          fails.add('${t.label}(${dark ? '밤' : '낮'}) ${r.toStringAsFixed(2)}');
        }
      }
    }
    expect(fails, isEmpty, reason: '읽기 힘든 조합: ${fails.join(', ')}');
  });

  test('칩 글씨도 12테마 × 밝음/어두움 모두 4.5:1 이상', () {
    /* 「고른 칩」은 지출 갈래·알림 범위·반복 종류·직책 고르기에 두루 쓰인다.
       옅은 강조색 위에 흰 글씨를 얹으면 밝은 화면에서 2~3:1밖에 안 나와
       (고치기 전 레몬은 1.93:1) 밖에서 무엇을 골랐는지 안 보였다. */
    final fails = <String>[];
    for (final t in clubThemes) {
      for (final dark in [false, true]) {
        final c = buildTheme(t.key, dark: dark).chipTheme;
        final on = contrast(c.secondaryLabelStyle!.color!, c.selectedColor!);
        final off = contrast(c.labelStyle!.color!, c.backgroundColor!);
        if (on < 4.5) fails.add('${t.label}(${dark ? '밤' : '낮'}) 고른칩 ${on.toStringAsFixed(2)}');
        if (off < 4.5) fails.add('${t.label}(${dark ? '밤' : '낮'}) 안고른칩 ${off.toStringAsFixed(2)}');
      }
    }
    expect(fails, isEmpty, reason: '읽기 힘든 조합: ${fails.join(', ')}');
  });

  test('탭막대의 반투명 표시는 뒤 색과 겹친 뒤에 봐야 한다', () {
    /* 반투명 색을 그대로 재면 엉뚱한 숫자가 나온다 — 실제로 화면에 보이는 것은
       뒤 색과 겹친 결과다. (겹치기 전 숫자로 보면 멀쩡한 것도 미달로 보인다) */
    for (final t in clubThemes) {
      for (final dark in [false, true]) {
        final th = buildTheme(t.key, dark: dark);
        final bar = th.navigationBarTheme;
        final blended =
            Color.alphaBlend(bar.indicatorColor!, bar.backgroundColor!);
        expect(contrast(blended, th.colorScheme.onSurface), greaterThanOrEqualTo(4.5),
            reason: '${t.label}(${dark ? '밤' : '낮'}): 고른 탭의 그림이 안 보인다');
      }
    }
  });

  test('바탕과 카드가 서로 구분된다', () {
    for (final t in clubThemes) {
      final light = buildTheme(t.key);
      expect(light.scaffoldBackgroundColor, isNot(light.cardTheme.color),
          reason: '${t.label}: 바탕과 카드가 같은 색이면 카드 경계가 사라진다');
    }
  });

  test('없는 테마 이름을 줘도 첫 테마로 안전하게 떨어진다', () {
    expect(themeOf('없는테마').key, clubThemes.first.key);
    expect(themeOf(null).key, clubThemes.first.key);
  });

  test('돈 색이 카드·바탕 위에서 12테마 × 밝음/어두움 모두 4.5:1 이상', () {
    /* 모임에서 가장 중요한 숫자다. 예전에는 Colors.teal·redAccent 를 그대로 써서
       밝은 화면 3.67·3.19, 어두운 화면 4.13 으로 기준에 못 미쳤다. */
    final fails = <String>[];
    for (final t in clubThemes) {
      for (final dark in [false, true]) {
        final th = buildTheme(t.key, dark: dark);
        moneyColors.forEach((name, pair) {
          final c = dark ? pair.$2 : pair.$1;
          for (final on in {'카드': th.cardTheme.color!, '바탕': th.scaffoldBackgroundColor}.entries) {
            final r = contrast(c, on.value);
            if (r < 4.5) {
              fails.add('${t.label}(${dark ? '밤' : '낮'}) $name/${on.key} ${r.toStringAsFixed(2)}');
            }
          }
        });
      }
    }
    expect(fails, isEmpty, reason: '읽기 힘든 조합: ${fails.join(', ')}');
  });

  test('돈 색은 화면 밝기에 따라 «바뀐다»', () {
    // 한 가지 색으로는 밝은 화면과 어두운 화면을 둘 다 만족시킬 수 없다 (실측으로 확인)
    moneyColors.forEach((name, pair) {
      expect(pair.$1, isNot(pair.$2), reason: '$name 이 밝음·어두움에서 같으면 한쪽이 안 읽힌다');
    });
  });

  test('위험한 동작의 빨강도 12테마 × 밝음/어두움 모두 4.5:1 이상', () {
    /* 지우기·탈퇴 처리·나가기처럼 **되돌릴 수 없는** 자리다.
       고치기 전에는 위험 단추의 흰 글씨가 밝음·어두움 «둘 다» 3.19 였다 —
       가장 조심해야 할 단추의 글씨가 가장 안 읽혔다. */
    final fails = <String>[];
    for (final t in clubThemes) {
      for (final dark in [false, true]) {
        final th = buildTheme(t.key, dark: dark);
        final text = dark ? moneyColors['나간 돈']!.$2 : moneyColors['나간 돈']!.$1;
        for (final on in {'카드': th.cardTheme.color!, '바탕': th.scaffoldBackgroundColor}.entries) {
          final r = contrast(text, on.value);
          if (r < 4.5) fails.add('${t.label}(${dark ? '밤' : '낮'}) 위험글씨/${on.key} ${r.toStringAsFixed(2)}');
        }
      }
    }
    // 위험 단추는 바탕이 고정색이라 테마와 상관없다
    final btn = contrast(const Color(0xFFFFFFFF), dangerBg);
    expect(btn, greaterThanOrEqualTo(4.5),
        reason: '위험 단추의 흰 글씨가 ${btn.toStringAsFixed(2)} 밖에 안 된다');
    expect(fails, isEmpty, reason: '읽기 힘든 조합: ${fails.join(', ')}');
  });

  test('테마를 안 거치는 색이 «글씨»로 남아 있지 않다', () {
    // Colors.redAccent·teal 을 글씨색으로 쓰면 밝은 화면에서 3.2~3.7 밖에 안 나온다
    /* ⚠️ 훑는 곳을 `lib/ui` 로만 좁히면 그 밖(예: 화면을 돕는 파일)에 다시 생겨도 못 잡는다.
       색을 «정하는» theme.dart 만 빼고 lib 전체를 본다. */
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('theme.dart')) continue; // 여기가 색을 정하는 곳이다
      final rel = f.path.replaceAll(r'', '/');
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (!l.contains('Colors.redAccent') && !l.contains('Colors.teal')) continue;
        bad.add('$rel:${i + 1}');
      }
    }
    expect(bad, isEmpty, reason: '테마를 안 거치는 색이 남아 있다: ${bad.join(', ')}');
  });

  test('고른 단추와 안 고른 단추가 «실제로» 다르게 보인다', () {
    /* 참석/불참·회비 받기는 「고른 것만 진하게」로 보여 준다.
       테마가 「살짝 채운 단추」까지 진하게 칠하면 **둘이 똑같아져**
       회원이 자기가 투표했는지 알 수 없다. (2026-08-22 실측: 밝음·어두움 둘 다 같은 색이었다) */
    for (final t in clubThemes) {
      for (final dark in [false, true]) {
        final th = buildTheme(t.key, dark: dark);
        final style = th.filledButtonTheme.style;
        expect(style?.backgroundColor?.resolve({}), isNull,
            reason: '${t.label}: 테마가 단추 바탕을 박으면 살짝 채운 단추까지 같은 색이 된다');
        expect(style?.foregroundColor?.resolve({}), isNull);
      }
    }
  });

  test('안 고른 단추의 글씨도 읽히고, 고른 것과 눈에 띄게 다르다', () {
    final fails = <String>[];
    for (final t in clubThemes) {
      for (final dark in [false, true]) {
        final cs = buildTheme(t.key, dark: dark).colorScheme;
        final r = contrast(cs.onSecondaryContainer, cs.secondaryContainer);
        if (r < 4.5) fails.add('${t.label}(${dark ? '밤' : '낮'}) 글씨 ${r.toStringAsFixed(2)}');
        final diff = contrast(cs.primary, cs.secondaryContainer);
        if (diff < 1.5) fails.add('${t.label}(${dark ? '밤' : '낮'}) 구분 ${diff.toStringAsFixed(2)}');
      }
    }
    expect(fails, isEmpty, reason: fails.join(', '));
  });

  /* 「고를 수 있는 것」은 눌러도 되는 자리인 줄 알아야 한다.
     2026-08-22 실측: 어두운 화면에서 칩 바탕이 카드 색과 **완전히 같아**(1.00) 테두리도 없어서
     「모두 받기 / 공지만 / 끄기」가 글씨만 떠 있는 것처럼 보였다. */
  test('안 고른 칩은 카드·바탕 위에서 테두리로 드러난다', () {
    for (final dark in [false, true]) {
      for (final t in clubThemes) {
        final th = buildTheme(t.key, dark: dark);
        final side = th.chipTheme.side;
        expect(side, isNotNull, reason: '${t.label}: 테두리가 없다');
        final off = (side is WidgetStateBorderSide)
            ? side.resolve(<WidgetState>{})!
            : side!;
        expect(off.style, BorderStyle.solid,
            reason: '${t.label}/${dark ? "어두움" : "밝음"}: 안 고른 칩에 테두리가 없다');
        for (final on in {'카드': th.cardTheme.color!, '바탕': th.scaffoldBackgroundColor}.entries) {
          final r = contrast(off.color, on.value);
          expect(r, greaterThanOrEqualTo(3.0),
              reason: '${t.label}/${dark ? "어두움" : "밝음"} $on.key 위 칩 테두리 '
                  '${r.toStringAsFixed(2)}:1');
        }
        // 고른 칩은 색으로 드러나므로 테두리가 없어야 자연스럽다
        final sel = (side is WidgetStateBorderSide)
            ? side.resolve(<WidgetState>{WidgetState.selected})
            : side;
        expect(sel == null || sel.style == BorderStyle.none, isTrue,
            reason: '${t.label}: 고른 칩에 테두리가 남아 있다');
      }
    }
  });

  test('적는 칸의 테두리도 카드·바탕과 3:1 이상', () {
    for (final dark in [false, true]) {
      for (final t in clubThemes) {
        final th = buildTheme(t.key, dark: dark);
        final b = th.inputDecorationTheme.enabledBorder!.borderSide.color;
        for (final on in {'카드': th.cardTheme.color!, '바탕': th.scaffoldBackgroundColor}.entries) {
          final r = contrast(b, on.value);
          expect(r, greaterThanOrEqualTo(3.0),
              reason: '${t.label}/${dark ? "어두움" : "밝음"} ${on.key} 위 칸 테두리 '
                  '${r.toStringAsFixed(2)}:1');
        }
      }
    }
  });
}
