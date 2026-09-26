import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';

/* 🎨 기본색을 «산호»로 (2026-09-26 사장님: 「두 번째 줄 두 번째 색(핑크 비슷한 색)을 전체 기본색으로,
   지금 처음 나오는 푸른색과 자리 바꿔 줘」 · 이미 있는 모임도 하늘색 그대로면 새 기본색으로).

   ⚠️ 모임 문서에는 만들 때 'sky' 가 «저절로» 적혀 있다 — 그건 누가 고른 게 아니므로 새 기본색으로 본다.
      하지만 «일부러» 하늘색을 고른 사람은 하늘색이어야 한다 → 하늘색은 이제 'blue' 로 적는다.
        · 모임의 'sky'(옛 저절로 값)  → 산호
        · 이 폰에서 고른 'sky'(개인 선택) → 하늘('blue') 그대로 */
void main() {
  test('산호가 맨 앞, 하늘은 산호가 있던 여덟째 자리', () {
    expect(clubThemes.first.key, 'coral');
    expect(clubThemes[7].label, '하늘');
    expect(clubThemes[7].key, 'blue');
    expect(defaultThemeKey, 'coral');
  });

  test('모르는 값·빈 값·옛 저절로 값(sky)은 기본색(산호)', () {
    expect(themeOf(null).key, 'coral');
    expect(themeOf('sky').key, 'coral', reason: '모임을 만들 때 저절로 적힌 하늘색은 새 기본색으로');
    expect(themeOf('blue').label, '하늘', reason: '일부러 고른 하늘색은 하늘색이다');
  });

  test('모임이 옛 하늘(sky)이면 산호로 보인다 — 이 폰에서 하늘을 고른 사람은 하늘', () async {
    SharedPreferences.setMockInitialValues({});
    await Store.i.loadPrefsForTest();
    final st = AppState.i;
    st.setCouple({'theme': 'sky'});
    await st.setMyTheme(null);
    expect(themeOf(st.effectiveTheme).key, 'coral');
    // 옛 판에서 이 폰에 «하늘»을 골라 둔 사람
    SharedPreferences.setMockInitialValues({'club_my_theme_v1': 'sky'});
    await Store.i.loadPrefsForTest();
    await st.loadProfile();
    expect(themeOf(st.effectiveTheme).label, '하늘', reason: '일부러 고른 하늘색이 산호로 바뀌면 안 된다');
    await st.setMyTheme(null);
    st.setCouple({});
  });

  test('새 모임은 기본색으로 만든다 (앱·총괄 콘솔·체험)', () {
    for (final f in ['lib/ui/onboarding.dart', 'lib/ui/admin.dart']) {
      final s = File(f).readAsStringSync();
      expect(s.contains("'theme': 'sky'"), isFalse, reason: '$f 가 새 모임을 하늘색으로 만든다');
      expect(s, contains("'theme': defaultThemeKey"), reason: f);
    }
    expect(File('lib/demo.dart').readAsStringSync().contains("'theme': 'sky'"), isFalse);
  });

  test('설정의 테마 동그라미는 «지금 보이는 색»에 표시가 붙는다(옛 sky 면 산호에)', () {
    final s = File('lib/ui/settings.dart').readAsStringSync();
    expect(s.contains("?? 'sky'"), isFalse, reason: '옛 기본값(sky)으로 표시·저장한다');
  });
}
