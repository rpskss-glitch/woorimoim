import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/onboarding.dart';

/* 🏷 「제목보다 설명이 먼저 읽히지 않는가」 — 가입 화면

   🔴 실기기에서 본 것(2026-08-30, 글자 1.8배):
        들어갈 모임 이름 · 새로 만들 이
     모임 이름  름 · 받은 코드
     설명이 길어져 두 줄이 되자, **설명의 첫 줄이 제목보다 위**로 올라갔다.
     제목보다 설명이 먼저 읽혀 무슨 칸인지 알 수 없다.
     (아래쪽 맞춤 `CrossAxisAlignment.end` 였다 — 첫 줄끼리 맞춰야 한다)

   ⚠️ 이건 «넘침»이 아니라서 좁은화면·큰글자 그물에 안 걸린다.
      넘치지 않고도 읽는 차례가 뒤집힌다 — 자리를 직접 재야 잡는다.
   ⚠️ 이 앱은 중장년 회원이 많아 글자를 키워 쓰는 사람이 흔하다. */
void main() {
  Future<void> open(WidgetTester t, double scale) async {
    t.view.physicalSize = const Size(360, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    t.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: OnboardingScreen(onJoined: () {}),
    ));
    await t.pumpAndSettle();
  }

  /// 제목과 그 설명이 «읽는 차례»대로 놓였는가
  /// ⚠️ 글자를 키우면 아래쪽 칸은 화면 밖으로 밀린다 — 먼저 보이게 굴린 뒤 잰다.
  Future<void> readsInOrder(
      WidgetTester t, String title, String hint, double scale) async {
    if (find.text(title).evaluate().isEmpty ||
        !t.any(find.text(title))) {
      await t.scrollUntilVisible(find.text(title), 200);
      await t.pumpAndSettle();
    }
    await t.ensureVisible(find.text(title));
    await t.pumpAndSettle();
    final titleBox = t.getRect(find.text(title));
    final hintBox = t.getRect(find.text(hint));

    /* 설명이 제목보다 «위»에서 시작하면 안 된다.
       (2픽셀은 글꼴 윗공간 차이 — 그만큼은 봐준다) */
    expect(hintBox.top, greaterThanOrEqualTo(titleBox.top - 2),
        reason: '글자 ${scale}배에서 «$hint» 가 «$title» 보다 위에서 시작한다 — '
            '설명이 제목보다 먼저 읽혀 무슨 칸인지 모른다');

    // 설명은 제목 «오른쪽»에서 시작한다 (한 줄이든 여러 줄이든)
    expect(hintBox.left, greaterThan(titleBox.left),
        reason: '설명이 제목 왼쪽으로 가 있다');
  }

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('가입 화면 — 제목이 설명보다 먼저 읽힌다 (글자 ${scale}배)', (t) async {
      await open(t, scale);
      await readsInOrder(t, '모임 이름', '들어갈 모임 이름 · 새로 만들 이름 · 받은 코드', scale);
      await readsInOrder(t, '내 이름', '실명이나 부르는 이름', scale);
      await readsInOrder(t, '생년월일', '폰을 바꿔도 이름+생년월일로 바로 이어받아요', scale);
      expect(t.takeException(), isNull);
    });
  }
}
