import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/settings.dart';

/* 🎨 테마 — 「둘 다」(2026-09-01 사장님 결정).
   · 방장이 «모임 기본 색»을 정한다 (couple.theme)
   · 회원 누구나 «자기 폰 색»을 바꾼다 (setMyTheme, 이 폰에만)
   · 안 바꾼 회원은 모임 기본 색으로 보인다 (effectiveTheme = 내폰 ?? 모임기본) */
void main() {
  final st = AppState.i;

  Finder circleOf(Color c) => find.byWidgetPredicate((w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration as BoxDecoration).color == c &&
      (w.decoration as BoxDecoration).shape == BoxShape.circle);

  Future<void> openThemes(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'), home: const SettingsScreen()));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.textContaining('내 화면 색'), 300,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
  }

  tearDown(() async {
    await st.setMyTheme(null);
    st.setCouple({});
    st.setItems([]);
  });

  test('effectiveTheme — 내 폰이 우선, 없으면 모임 기본', () async {
    Demo.start();
    await st.setMyTheme(null);
    st.setCouple({'theme': 'mint', 'members': {'me': {'uid': 'me', 'role': 'owner'}}});
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    expect(st.effectiveTheme, 'mint', reason: '내 폰 설정이 없으면 모임 기본');
    await st.setMyTheme('grape');
    expect(st.effectiveTheme, 'grape', reason: '내 폰 설정이 있으면 그것');
    await st.setMyTheme(null);
    expect(st.effectiveTheme, 'mint', reason: '되돌리면 다시 모임 기본');
  });

  const mint = Color(0xFF4FBF9C);

  testWidgets('회원(방장 아님)도 자기 폰 색을 바꿀 수 있다', (t) async {
    Demo.start();
    // 데모를 회원으로 바꾼다
    final slot = st.slot!;
    final c = Map<String, dynamic>.from(st.couple ?? {});
    (c['members'] as Map)[slot] = {'uid': slot, 'name': '나', 'role': 'member'};
    st.setCouple(c);
    expect(st.isAdmin, isFalse, reason: '이 시험은 «회원»이라야 뜻이 있다');

    await openThemes(t);
    await t.tap(circleOf(mint));
    await t.pumpAndSettle();
    expect(st.myThemeOverride, 'mint', reason: '회원이 눌러도 자기 폰 색이 안 바뀐다');
  });

  testWidgets('방장은 «이 색을 모임 기본으로» 정할 수 있다', (t) async {
    Demo.start(); // 데모는 방장
    expect(st.isAdmin, isTrue);
    await st.setMyTheme('grape'); // 내 폰 색을 포도로
    await openThemes(t);
    await t.tap(find.text('모임 기본으로'));
    await t.pumpAndSettle();
    expect(st.couple?['theme'], 'grape', reason: '모임 기본이 내 색으로 안 바뀐다');
  });

  testWidgets('«모임 기본색으로 되돌리기»가 내 폰 설정을 지운다', (t) async {
    Demo.start();
    await st.setMyTheme('coral');
    await openThemes(t);
    expect(find.text('모임 기본색으로'), findsOneWidget);
    await t.tap(find.text('모임 기본색으로'));
    await t.pumpAndSettle();
    expect(st.myThemeOverride, isNull);
  });
}
