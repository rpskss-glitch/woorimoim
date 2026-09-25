import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/common.dart';

/* 🎂 내 정보 창의 생년월일 칸에 «이름»이 없었다. (2026-09-26 에뮬)
   가입 화면은 칸 위에 「생년월일」 제목이 있는데, 내 정보 창은 「예) 800125」만 보여
   무엇을 적는 칸인지 알 수 없었다(비어 있을 때). */
void main() {
  testWidgets('label 을 주면 칸 이름이 보인다', (t) async {
    await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: Scaffold(body: BirthInput(label: '생년월일', onChanged: (_) {}))));
    expect(find.text('생년월일'), findsOneWidget);
  });

  test('내 정보 창이 칸 이름을 준다', () {
    final s = File('lib/ui/settings.dart').readAsStringSync();
    expect(s, contains("BirthInput(\n                  label: '생년월일',").or(contains("label: '생년월일'")));
  });
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
