// 모임 상징을 «기울였을 때» 자리도 같이 넓어지는지 (93회차).
//
// `Transform.rotate` 는 그릴 때만 돌린다 — 자리는 안 돈 그대로다.
// 실측: 홈 카드에서 30°에 아래로 28.2px 삐져나와 모임 이름과 18.2px 겹쳤고, 45°면 21.9px였다.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/ui/common.dart';

Future<Rect> emblemBox(WidgetTester t, num rot, {num size = 2}) async {
  AppState.i.couple = {
    'title': '앞산 배드민턴',
    'emblem': {'kind': 'emoji', 'emoji': '🏸', 'size': size, 'rot': rot},
  };
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Emblem(basePx: 54, capScale: 2),
            SizedBox(height: 10),
            Text('앞산 배드민턴', key: Key('name')),
          ],
        ),
      ),
    ),
  ));
  return t.getRect(find.byType(Emblem));
}

void main() {
  testWidgets('안 돌렸을 때는 예전과 같은 자리를 쓴다', (t) async {
    final r = await emblemBox(t, 0);
    // 이모지 글자 상자 그대로 (돌리지 않았으니 넓힐 이유가 없다)
    expect(r.height, closeTo(154, 1));
  });

  testWidgets('기울이면 «정확히 돌린 만큼» 자리가 넓어진다', (t) async {
    final flat = await emblemBox(t, 0);
    for (final deg in [15, 30, 45, 60, 75]) {
      final r = await emblemBox(t, deg);
      // w×h 상자를 θ 만큼 돌리면 차지하는 폭·높이는 이렇게 된다
      final a = deg * math.pi / 180;
      final c = math.cos(a).abs(), sn = math.sin(a).abs();
      expect(r.width, closeTo(flat.width * c + flat.height * sn, 1),
          reason: '$deg° — 자리가 모자라면 그림만 밖으로 삐져나와 글씨를 파고든다');
      expect(r.height, closeTo(flat.width * sn + flat.height * c, 1), reason: '$deg°');
      /* 세로로 긴 상자를 눕히면 «세로가 줄어드는» 것이 맞다(75°가 그렇다) —
         「무조건 커진다」로 보면 안 된다. 지켜야 할 것은 «정확히 돌린 만큼»이다. */
    }
  });

  testWidgets('90°는 가로세로가 뒤바뀐다', (t) async {
    final flat = await emblemBox(t, 0);
    final r = await emblemBox(t, 90);
    expect(r.width, closeTo(flat.height, 1));
    expect(r.height, closeTo(flat.width, 1));
  });

  testWidgets('기울여도 모임 이름 글씨를 파고들지 않는다', (t) async {
    for (final deg in [0, 30, 45, 90, 180]) {
      await emblemBox(t, deg);
      final box = t.getRect(find.byType(Emblem));
      final name = t.getRect(find.byKey(const Key('name')));
      expect(name.top - box.bottom, closeTo(10, 0.5),
          reason: '$deg° — 자리가 맞으면 사이 간격(10px)이 그대로여야 한다');
    }
  });

  testWidgets('180°·음수 각도에서도 자리가 원래대로 돌아온다', (t) async {
    final flat = await emblemBox(t, 0);
    for (final deg in [180, -180, -90, 360]) {
      final r = await emblemBox(t, deg);
      final same = deg.abs() % 180 == 0;
      expect(r.height, closeTo(same ? flat.height : flat.width, 1), reason: '$deg°');
    }
  });

  testWidgets('상징이 없어도 (기본 이모지) 죽지 않는다', (t) async {
    AppState.i.couple = {'title': '이름만 있는 모임'};
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Emblem())));
    expect(find.text('🏸'), findsOneWidget);
  });

  /* 꾸미기 화면의 «미리보기»는 실제 홈과 같은 방식·같은 값이라야 한다 (94회차).
     예전에는 미리보기만 `Transform.rotate` + 110px 고정 상자 + 사진 기준 60px 이었다:
       · 크기 2배면 글자 상자가 154px 이라 자리가 모자라 눌리거나 아래 슬라이더를 덮었다
       · 기울여도 자리를 안 차지해, 여기서 맞춰 놓고 저장하면 홈에서 딴판으로 보였다
       · 사진이 홈보다 11% 크게 보였다 (60 vs 54) */
  test('꾸미기 미리보기가 실제 화면과 같은 방식·같은 값을 쓴다', () {
    final st = File('lib/ui/settings.dart').readAsStringSync();
    final at = st.indexOf('Future<void> _editEmblem()');
    expect(at, greaterThan(0));
    final body = st.substring(at, at + 4000);

    expect(body.contains('RotateAndFit('), isTrue,
        reason: '미리보기만 옛 회전을 쓰면 저장한 뒤 홈에서 딴판으로 보인다');
    expect(body.contains('Transform.rotate('), isFalse, reason: '옛 방식이 남아 있다');
    expect(body.contains('SizedBox(\n                  height: 110,'), isFalse,
        reason: '고정 상자면 큰 상징이 눌리거나 아래를 덮는다');
    expect(body.contains('minHeight: 110'), isTrue);

    // 크기·둥글기는 반드시 «한 곳»에서 가져온다
    expect(body.contains('emblemBasePx * size'), isTrue,
        reason: '미리보기만 다른 기준을 쓰면 보이는 대로 저장되지 않는다');
    expect(RegExp(r'\b60 \* size').hasMatch(body), isFalse, reason: '옛 기준(60)이 남아 있다');
    expect(RegExp(r'\b54 \* size').hasMatch(body), isFalse, reason: '숫자를 박아 두면 또 어긋난다');
    expect(body.contains('emblemRadius(emblemBasePx)'), isTrue);
  });

  test('홈도 같은 기준을 쓴다', () {
    final home = File('lib/ui/home.dart').readAsStringSync();
    expect(home.contains('Emblem(basePx: emblemBasePx'), isTrue);
    final common = File('lib/ui/common.dart').readAsStringSync();
    expect(common.contains('const emblemBasePx = 54.0;'), isTrue);
    expect(common.contains('emblemRadius(basePx)'), isTrue,
        reason: '둥글기도 한 곳에서 셈해야 미리보기와 어긋나지 않는다');
    // 한 자리라도 숫자를 박아 두면 다음에 또 어긋난다
    expect(common.contains('basePx * .28'), isFalse,
        reason: '둥글기 셈이 두 군데로 갈렸다');
  });
}
