// 글자를 키워 쓰는 회원(중장년 동호회에는 흔하다)에게도 화면이 온전한지.
// ⚠️ 창(새 화면)에는 MediaQuery 로 씌운 글자 크기가 «안 닿는다» —
//    폰 설정 수준(platformDispatcher)으로 키워야 한다. (2026-08-22에 이걸로 헛짚었다)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/common.dart';

void main() {
  for (final scale in [1.0, 1.6, 2.0]) {
    testWidgets('글자 $scale배 — 고를 것이 많아도 «마지막까지 골라진다»', (t) async {
      /* 같은 이름의 모임이 여럿이면 고를 것이 그 수만큼 생긴다(정해져 있지 않다).
         고치기 전에는 1.6배에서 246px·2배에서 418px 넘쳐 마지막이 화면 밖이었다. */
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

      String? picked;
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  picked = await chooseSheet(c, '같은 이름의 모임이 여러 개예요', '어느 모임인가요?', [
                    for (var i = 0; i < 8; i++) ['c$i', '앞산 배드민턴 — 방장 홍길동$i · 12명'],
                  ]);
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('열기'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '창이 화면을 넘치면 아래 것을 못 고른다');

      // 밀어서 마지막 것까지 닿는지 — 실제 회원이 하는 동작
      await t.dragUntilVisible(
        find.textContaining('홍길동7'),
        find.byType(SingleChildScrollView).last,
        const Offset(0, -80),
      );
      await t.pumpAndSettle();
      await t.tap(find.textContaining('홍길동7'));
      await t.pumpAndSettle();
      expect(picked, 'c7', reason: '마지막 모임을 고르지 못하면 그 방에는 못 들어간다');
    });
  }

  test('창을 여는 곳마다 «밀어 볼 수 있는지» — 개수가 늘 수 있는 목록은 특히', () {
    /* 직책 고르기는 미리 넣어둔 12개 + 방장이 직접 적은 직책만큼 늘어난다.
       실측: 직접 입력 18개가 쌓이면 **보통 글자에서도 198px**, 1.6배면 800px 넘쳤다. */
    final src = File('lib/ui/members.dart').readAsStringSync();
    final at = src.indexOf('Future<void> _setTitle');
    expect(at, greaterThan(0));
    final body = src.substring(at, at + 1400);
    expect(body.contains('SingleChildScrollView'), isTrue,
        reason: '직책이 늘면 아래쪽을 아예 못 고른다');

    // 고르기 창(같은 이름 모임 여럿)도 마찬가지 — 65회차에 고친 자리
    final common = File('lib/ui/common.dart').readAsStringSync();
    final ch = common.indexOf('Future<String?> chooseSheet');
    expect(common.substring(ch, ch + 1600).contains('SingleChildScrollView'), isTrue);
  });
}
