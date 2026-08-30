import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/settings.dart';

/* 📗 설정에 넣은 «회원 사용설명서» — 접힌 채 시작, 눌러서 펼침.
   좁은 폰·큰 글자에서 펼쳐도 안 넘쳐야 하고, 접기·펴기가 되어야 한다. */
void main() {
  final st = AppState.i;

  Widget host() => MaterialApp(
        theme: buildTheme('sky'),
        home: const SettingsScreen(),
      );

  setUp(() => Demo.start());
  tearDown(() {
    st.setCouple({});
    st.setItems([]);
  });

  testWidgets('접힌 채 시작하고, 눌러서 펼치면 내용이 나온다', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('📗 앱 사용설명서'), 300,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();

    expect(find.text('📗 앱 사용설명서'), findsOneWidget);
    // 접힘 안내 문구가 보이고, 펼침 내용은 아직 없다
    expect(find.textContaining('눌러서 펼쳐'), findsOneWidget);
    expect(find.textContaining('참석을 찍어요'), findsNothing);

    await t.tap(find.text('📗 앱 사용설명서'));
    await t.pumpAndSettle();
    expect(find.textContaining('참석을 찍어요'), findsOneWidget,
        reason: '펼쳐도 내용이 안 나온다');

    // 다시 눌러 접기
    await t.tap(find.text('📗 앱 사용설명서'));
    await t.pumpAndSettle();
    expect(find.textContaining('참석을 찍어요'), findsNothing,
        reason: '다시 못 접는다');
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('펼친 설명서 — 360px · 글자 ${scale}배 안 넘침', (t) async {
      t.view.physicalSize = const Size(360, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

      await t.pumpWidget(host());
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('📗 앱 사용설명서'), 300,
          scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      await t.tap(find.text('📗 앱 사용설명서'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull,
          reason: '펼친 설명서가 360px·${scale}배에서 넘친다');
    });
  }
}
