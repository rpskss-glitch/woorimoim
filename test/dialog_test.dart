// 확인창·고르기창 — 모든 화면이 쓰는 부품이라 여기가 어긋나면 앱 전체가 어긋난다.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/common.dart';

double _lum(Color c) {
  double ch(double v) {
    v = v / 255.0;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }
  return 0.2126 * ch((c.r * 255).roundToDouble()) +
      0.7152 * ch((c.g * 255).roundToDouble()) +
      0.0722 * ch((c.b * 255).roundToDouble());
}

double contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('위험 확인 단추의 글씨가 ${dark ? '어두운' : '밝은'} 화면에서 읽힌다', (t) async {
      /* 「모임 지우기」·「탈퇴 처리」처럼 **되돌릴 수 없는** 동작의 확인 단추다.
         바탕만 바꾸고 글씨를 안 정하면 테마의 «거의 검정» 글씨가 얹혀 2.93 이 된다. */
      final th = buildTheme('sky', dark: dark);
      await t.pumpWidget(MaterialApp(
        theme: th,
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => confirmSheet(c, '지울까요?', '되돌릴 수 없어요',
                    okLabel: '지우기', danger: true),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('열기'));
      await t.pumpAndSettle();

      final btn = t.widget<FilledButton>(
          find.ancestor(of: find.text('지우기'), matching: find.byType(FilledButton)));
      final merged = btn.style!.merge(th.filledButtonTheme.style);
      final fg = merged.foregroundColor!.resolve({})!;
      final bg = merged.backgroundColor!.resolve({})!;
      final r = contrast(fg, bg);
      expect(r, greaterThanOrEqualTo(4.5),
          reason: '위험 단추 글씨가 ${r.toStringAsFixed(2)} — 가장 조심해야 할 단추가 가장 안 읽힌다');
    });
  }

  testWidgets('고를 것이 많고 화면이 작아도 고르기 창이 안 넘친다', (t) async {
    // 같은 이름의 모임이 여럿일 때 그 수만큼 단추가 생긴다 — 몇 개가 될지 정해져 있지 않다
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => chooseSheet(c, '같은 이름의 모임이 여러 개예요', '어느 모임인가요?', [
                for (var i = 0; i < 8; i++) ['c$i', '앞산 배드민턴 — 방장 홍길동$i · 12명'],
              ]),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: '창이 화면을 넘치면 회원이 아래 것을 못 고른다');
  });
}
