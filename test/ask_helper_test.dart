import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:woorimoim/ui/common.dart';

/* 💬 「물어보는 창의 설명이 «다 보이는가»」

   설명(helper)은 기본이 **한 줄**이다. 한 줄을 넘으면 뒤가 「…」로 잘린다.
   총괄 관리자 창에서 실제로 이렇게 나왔다:
     「아이디가 맞으면 이름과 생년월일을 …」
   정작 해야 할 말이 사라져, 회원은 무엇을 넣어야 하는지 모른다.

   ⚠️ 이 시험은 «글자가 실제로 잘렸는가»를 그림에서 재어 본다 —
      코드 모양이 아니라 **화면에 난 일**을 본다. */
void main() {
  const long = '아이디가 맞으면 이름과 생년월일을 다시 물어봐요 — 셋이 다 맞아야 들어갑니다';

  Future<void> openAsk(WidgetTester t, {double width = 360}) async {
    t.view.physicalSize = Size(width * 3, 700 * 3);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => askText(c, title: '총괄 관리자', hint: '이름', helper: long),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
  }

  testWidgets('물어보는 창의 설명이 «잘리지 않는다»', (t) async {
    await openAsk(t);
    expect(find.text(long), findsOneWidget, reason: '설명이 아예 안 나온다');

    final para = t.renderObject<RenderParagraph>(find.text(long));
    expect(para.didExceedMaxLines, isFalse,
        reason: '설명이 «…»로 잘렸다 — 무엇을 넣어야 하는지 못 읽는다');
  });

  testWidgets('아주 좁은 화면·큰 글자에서도 설명이 «잘리지 않는다»', (t) async {
    /* 노인 회원은 글자를 키워 쓴다. 그때 한 줄에 들어갈 리가 없다. */
    t.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await openAsk(t, width: 320);

    final para = t.renderObject<RenderParagraph>(find.text(long));
    expect(para.didExceedMaxLines, isFalse,
        reason: '글자를 키우면 설명이 잘린다 — 잘 안 보이는 분일수록 더 못 읽는다');
    expect(t.takeException(), isNull);
  });
}
