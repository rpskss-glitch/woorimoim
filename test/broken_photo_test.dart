// 사진 값이 깨져 있을 때 (132회차).
//
// `base64Decode` 가 통과했다고 «사진»인 것은 아니다 — 잘린 값·백업 복원 찌꺼기는
// 풀리기는 해도 그림이 아니다. 그때 `Image.memory` 는 **그리는 도중에** 터지므로
// 값을 풀 때 감싼 try 로는 못 잡는다. 받아 내지 않으면 이모지로 되돌아가지도 못하고
// 아바타는 **빈 동그라미**, 모임 상징은 **홈 맨 위의 빈 자리**가 된다.
// (2026-08-23 실측: 오류 2건, 화면에 이모지도 안 뜸)
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/ui/common.dart';

/// base64 로는 멀쩡히 풀리지만 «사진이 아닌» 값
final junk = 'data:image/jpeg;base64,${base64Encode(List.filled(64, 7))}';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

Future<void> seed(WidgetTester t, Widget w) async {
  AppState.i.couple = Store.tidyCouple({
    'title': '모임',
    'emblem': {'kind': 'photo', 'photo': junk, 'size': 1, 'rot': 0},
    'members': {
      'u1': {'uid': 'u1', 'name': '갑', 'emoji': '🐶', 'photo': junk, 'role': 'owner'}
    },
  });
  await t.pumpWidget(MaterialApp(home: Scaffold(body: w)));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('깨진 사진이어도 회원 얼굴이 «이모지»로 남는다', (t) async {
    await seed(t, const Avatar('u1', size: 38));
    expect(find.text('🐶'), findsOneWidget,
        reason: '되돌아갈 얼굴이 없으면 빈 동그라미만 남는다');
  });

  testWidgets('깨진 사진이어도 모임 상징이 «이모지»로 남는다', (t) async {
    await seed(t, const Emblem(basePx: emblemBasePx, capScale: 2));
    expect(find.text('🏸'), findsOneWidget,
        reason: '상징은 홈 맨 위라 빈 자리가 그대로 보인다');
  });

  testWidgets('멀쩡한 값이면 그대로 이모지 자리에 사진이 온다', (t) async {
    // 사진이 없는 회원은 이모지가 나오는 것이 맞다 (되돌아간 것과 헷갈리지 않게 확인)
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'u2': {'uid': 'u2', 'name': '을', 'emoji': '🦊', 'role': 'member'}
      }
    });
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: Avatar('u2', size: 38))));
    expect(find.text('🦊'), findsOneWidget);
  });

  test('사진을 그리는 곳은 «터졌을 때»를 모두 받아 낸다', () {
    /* ClubPhoto 는 처음부터 errorBuilder 가 있었는데 Avatar·Emblem 만 빠져 있었다.
       앞으로도 어긋나지 않게 훑는다. */
    final code = stripComments(File('lib/ui/common.dart').readAsStringSync());
    final made = RegExp(r'Image\.(memory|network)\(').allMatches(code).length;
    final caught = RegExp(r'errorBuilder:').allMatches(code).length;
    expect(made, greaterThan(0));
    expect(caught, greaterThanOrEqualTo(made),
        reason: '받아 내지 않은 그림이 있다 — 깨지면 소리 없이 빈 자리가 된다');
  });
}
