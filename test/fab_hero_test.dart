import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/* 💥 「둥근 단추(FloatingActionButton)에 이름을 안 주면 앱이 터진다」

   2026-08-29 에뮬레이터에서 설정의 「월 회비」를 고치고 **저장을 누르는 순간** 빨간 화면이 떴다:
     There are multiple heroes that share the same tag: <default FloatingActionButton tag>

   왜: 이 앱은 탭 다섯을 `IndexedStack` 으로 **동시에 살려 둔다**(탭을 옮겨도 화면이 안 지워지게).
   그래서 회비의 「기록하기」, 게시판의 「글 쓰기」, 일정의 「모임 만들기」가 **한 화면에 함께** 있다.
   FloatingActionButton 은 이름을 안 주면 전부 «같은 기본 이름»을 쓰는데,
   화면을 옮길 때 Flutter 가 그 이름으로 짝을 지으려다 「같은 이름이 둘」이라며 터진다.

   ⚠️ 이건 **이미 나간 판에 들어 있던 버그**다 — 시험 940개가 다 통과하는데도 살아 있었다.
      화면으로 눌러 보지 않았으면 이번에도 그대로 나갔다. */
void main() {
  testWidgets('한 화면에 이름 없는 둥근 단추가 둘이면 터진다 (미끼)', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: Stack(children: [
            // IndexedStack 처럼 «동시에 살아 있는» 두 화면
            Scaffold(
              floatingActionButton:
                  FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
            ),
            Scaffold(
              floatingActionButton:
                  FloatingActionButton(onPressed: () {}, child: const Icon(Icons.edit)),
            ),
          ]),
        ),
      ),
    ));
    await t.pumpAndSettle();

    // 화면을 옮기는 순간 Hero 가 짝을 찾다가 터진다
    final ctx = t.element(find.byType(Stack).first);
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => const Scaffold()));
    await t.pumpAndSettle();

    expect(t.takeException(), isNotNull,
        reason: '미끼가 안 물렸다 — 이 시험은 아무것도 지키지 못한다');
  });

  testWidgets('이름을 주면 안 터진다 (고친 모양)', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: Stack(children: [
            Scaffold(
              floatingActionButton: FloatingActionButton(
                  heroTag: 'a', onPressed: () {}, child: const Icon(Icons.add)),
            ),
            Scaffold(
              floatingActionButton: FloatingActionButton(
                  heroTag: 'b', onPressed: () {}, child: const Icon(Icons.edit)),
            ),
          ]),
        ),
      ),
    ));
    await t.pumpAndSettle();
    final ctx = t.element(find.byType(Stack).first);
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => const Scaffold()));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: '이름을 줬는데도 터진다');
  });

  test('앱의 둥근 단추는 «모두» 자기 이름을 갖는다', () {
    /* 새 화면을 만들 때 이름을 빠뜨리기 쉽다 — 그러면 그 화면을 연 채로
       다른 화면으로 옮기는 순간 앱이 터진다. 여기서 잡는다. */
    final naked = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final s = f.readAsStringSync();
      for (final m in RegExp(r'FloatingActionButton(\.extended)?\(').allMatches(s)) {
        final tail = s.substring(m.end, (m.end + 400).clamp(0, s.length));
        // 다음 단추가 나오기 «전»에 heroTag 가 있어야 한다
        final next = tail.indexOf('FloatingActionButton');
        final look = next > 0 ? tail.substring(0, next) : tail;
        if (!look.contains('heroTag')) {
          naked.add(f.path.replaceAll(r'\', '/'));
        }
      }
    }
    expect(naked, isEmpty,
        reason: '이름 없는 둥근 단추가 있다 — 탭이 «동시에 살아 있는» 이 앱에서는 '
            '화면을 옮기는 순간 터진다: $naked');
  });

  test('창을 닫자마자 «입력 그릇»을 버리는 자리가 없다', () {
    /* 2026-08-29 설정에서 「월 회비」를 저장하는 순간 터진 두 번째 원인:
         A TextEditingController was used after being disposed.
       `Navigator.pop` 은 창을 곧바로 없애지 않는다 — 닫히는 동안 몇 프레임을 더 그린다.
       그 사이에 그릇을 버리면 아직 살아 있는 입력칸이 죽은 그릇을 읽는다.
       그래서 그릇은 «창이 스스로» 들게 했다(common.dart 의 askText). */
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final s = f.readAsStringSync();
      for (final m in RegExp(r'await showDialog<[^>]*>\(').allMatches(s)) {
        final tail = s.substring(m.start, (m.start + 2500).clamp(0, s.length));
        if (RegExp(r'\n\s*\w+\.dispose\(\);').hasMatch(tail)) {
          bad.add(f.path.replaceAll(r'\', '/'));
        }
      }
    }
    expect(bad, isEmpty,
        reason: '창을 닫자마자 입력 그릇을 버린다 — 저장을 누르는 순간 앱이 터진다: $bad');
  });

  test('여러 명 고르는 중에는 둥근 단추를 치운다', () {
    /* 2026-08-29 화면에서 잡은 버그: 「여러 명 한 번에」를 켜면
       아래에 「N명 회비 한 번에 받기」 가로 단추가 생기는데,
       그 위에 「기록하기」 둥근 단추가 겹쳠 앉아 **오른쪽 절반을 덮었다.**
       돈을 기록하는 단추라 잘못 눌리면 엉뚱한 창이 뜨고,
       회원이 많으면 스크롤해도 그 단추를 계속 덮어 누를 길이 없다. */
    final s = File('lib/ui/wallet.dart').readAsStringSync();
    final at = s.indexOf('floatingActionButton:');
    expect(at, greaterThan(0));
    // 그 줄만 본다 — 뒤에 오는 단추 속살까지 읽으면 엉뚱한 곳의 _pickMode 를 물어온다
    final line = s.substring(at, (at + 80).clamp(0, s.length));
    expect(line.contains('_pickMode'), isTrue,
        reason: '고르는 중에도 둥근 단추가 남아 확정 단추를 덮는다: $line');
  });
}
