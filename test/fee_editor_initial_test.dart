import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/settings.dart';

/* 💵 월 회비 창을 «열고 그대로 저장»해도 회비가 그대로여야 한다.

   2026-09-25 조사(처음 커밋부터 있던 버그, 스토어 1.6.0 에도 있음):
   입력칸에 지금 금액(20000) 대신 **글자 `$cur`** 가 들어 있었다.
   모르고 「저장」을 누르면 숫자가 없어 0원 → 「회비를 쓰지 않도록 했어요」 →
   모든 회원의 밀린 회비가 사라지고 홈의 회비 카드가 없어졌다. */
void main() {
  final st = AppState.i;

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });

  int fee() => ((st.couple?['fee'] as Map?)?['amount'] as num?)?.toInt() ?? 0;

  Future<void> openFeeEditor(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start(); // 방장, 월 회비 20,000원
    await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: const SettingsScreen()));
    await t.pumpAndSettle();
    final row = find.text('월 회비');
    await t.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(row);
    await t.pumpAndSettle();
  }

  testWidgets('창을 열면 «지금 금액»이 들어 있다', (t) async {
    await openFeeEditor(t);
    expect(fee(), 20000, reason: '전제: 둘러보기 모임의 월 회비');
    final field = t.widget<TextField>(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)));
    final shown = field.controller?.text ?? '';
    expect(shown.contains(r'$'), isFalse, reason: '입력칸에 «\$cur» 같은 글자가 보인다');
    expect(shown.replaceAll(RegExp(r'[^0-9]'), ''), '20000', reason: '지금 금액이 안 들어 있다');
  });

  testWidgets('아무것도 안 고치고 저장해도 회비가 0원이 되지 않는다', (t) async {
    await openFeeEditor(t);
    await t.tap(find.descendant(of: find.byType(Dialog), matching: find.text('저장')).last);
    await t.pumpAndSettle();
    expect(fee(), 20000, reason: '그대로 저장했는데 회비가 0원(안 걷는 모임)이 됐다');
  });
}
