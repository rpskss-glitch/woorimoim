import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/theme.dart';

/* 👈 «왼쪽 가장자리를 밀면 앞 화면으로» — 아이폰 사람들이 몸에 밴 동작.

   아이폰에는 안드로이드 같은 시스템 뒤로가기 단추가 없다. 이 동작이 막히면
   나가는 길이 좌측 상단 화살표 하나뿐이 되고, 애플은 그것을 지침 위반으로 본다.

   ⚠️ 이건 «따로 넣는 기능»이 아니라 Flutter 가 아이폰에서 기본으로 주는 것이다.
      대신 테마에서 `pageTransitionsTheme` 을 통째로 덮으면 **조용히 죽는다**
      (모든 판에 ZoomPageTransitionsBuilder 를 거는 것이 흔한 실수다).
      죽어도 화면은 멀쩡히 나와서 «밀어 보기» 전에는 아무도 모른다 — 그래서 여기서 민다.

   ⚠️ 시험을 짤 때 밟은 함정 두 개를 적어 둔다(다시 밟지 말라고):
      ① 테마를 `debugDefaultTargetPlatformOverride` «전에» 만들면 이 PC 기준(안드로이드)으로 굳는다.
      ② 화면 폭의 «딱 절반»만 밀면 안 돌아온다 — 넘겨야 넘어간다. 넉넉히 민다. */
void main() {
  Widget app(ThemeData th) => MaterialApp(
        theme: th,
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push(
                  c,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('다음 화면')),
                      body: const Center(child: Text('둘째', key: Key('second'))),
                    ),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );

  testWidgets('아이폰에서 왼쪽 가장자리를 밀면 앞 화면으로 돌아온다', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await t.pumpWidget(app(buildTheme('sky'))); // 테마는 «건 뒤에» 만든다
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('second')), findsOneWidget);

    // 왼쪽 끝에서 오른쪽으로 — 사람이 미는 것처럼 조금씩, 절반보다 넉넉히
    final g = await t.startGesture(const Offset(5, 200));
    await t.pump(); // 눌린 것을 먼저 알린다 (안 하면 인식기가 못 잡는다)
    for (var i = 0; i < 16; i++) {
      await g.moveBy(const Offset(40, 0));
      await t.pump(const Duration(milliseconds: 20));
    }
    final nav = Navigator.of(t.element(find.byType(Scaffold).last));
    expect(nav.userGestureInProgress, isTrue,
        reason: '미는 것을 «뒤로가기»로 못 알아들었다 — 가장자리 감지기가 없다');
    await g.up();
    await t.pumpAndSettle();

    final left = find.byKey(const Key('second'));
    debugDefaultTargetPlatformOverride = null; // 시험 끝나기 «전에» 되돌린다
    expect(left, findsNothing,
        reason: '밀어도 안 돌아온다 — 아이폰에서 나갈 길이 좌측 상단 화살표 하나뿐이다');
    expect(find.text('열기'), findsOneWidget);
  });

  test('테마가 화면전환을 통째로 덮어쓰지 않는다', () {
    /* 위 시험이 통과해도, 나중에 누가 테마에 pageTransitionsTheme 을 걸면 조용히 죽는다.
       정말 필요하면 «아이폰 몫은 Cupertino» 로 남겨야 한다. */
    final src = File('lib/theme.dart').readAsStringSync();
    final at = src.indexOf('pageTransitionsTheme');
    if (at < 0) return; // 안 건드림 = 기본값 = 스와이프 살아 있음
    final near = src.substring(at, (at + 400).clamp(0, src.length));
    expect(near.contains('CupertinoPageTransitionsBuilder'), isTrue,
        reason: '화면전환을 덮어쓰면서 아이폰 몫을 안 남겼다 — 가장자리 스와이프가 죽는다');
  });

  test('나가는 길을 막는 것(PopScope)이 없다', () {
    /* `PopScope(canPop: false)` 를 걸면 그 화면에서는 스와이프도 함께 죽는다.
       쓸 일이 생기면 «저장 안 함/취소» 같은 물음을 띄우고 결국 나갈 수 있게 해야 한다. */
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      expect(f.readAsStringSync().contains('canPop: false'), isFalse,
          reason: '${f.path} 가 나가는 길을 막았다 — 아이폰에서는 갇힌 것처럼 느낀다');
    }
  });
}
