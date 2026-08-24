// 트랜잭션(참석 투표·출석·반응·권한)은 **서버에 닿아야만** 된다 — 연결이 끊기면 실패한다.
// 감싸지 않으면 실패가 그대로 새어 나가 «눌렀는데 아무 일도 안 일어나는» 단추가 된다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('트랜잭션을 부르는 모든 화면이 실패를 잡는다', () {
    // 이 한 곳만 예외: _doJoin 은 부르는 쪽(_join)이 통째로 감싸 「서버에 연결하지 못했어요」를 띄운다
    const wrappedFarAway = {'lib/ui/onboarding.dart'};

    final bad = <String>[];
    /* ⚠️ 훑는 범위도 «값»이다 — `lib/ui` 로 좁혀 두면 그 밖에 생긴 것을 못 잡는다.
       지금은 화면들에만 있지만, 나중에 딴 곳에서 불러도 걸리게 lib 전체를 본다. */
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (!l.contains('mutateItem(') && !l.contains('mutateCouple(')) continue;
        // «만드는 자리»(선언)는 부르는 자리가 아니다 — 범위를 넓히니 이것까지 잡혔다
        if (l.contains('Future<')) continue;
        if (wrappedFarAway.any(rel.endsWith)) continue;
        final before = lines.sublist((i - 8).clamp(0, i), i + 1).join('\n');
        if (!before.contains('try {')) {
          bad.add('$rel:${i + 1}');
        }
      }
    }
    expect(bad, isEmpty,
        reason: '실패하면 아무 말도 없이 끝난다 — 회원은 눌린 건지 아닌지 알 수 없다: ${bad.join(', ')}');
  });

  test('결과를 «안 보고» 넘어가는 트랜잭션이 없다', () {
    /* 성공/실패를 받아만 두고 안 보면 감싼 보람이 없다.
       ⚠️ 예전에는 「그 자리에서 800자 안에 문구가 있나」로 봤는데,
          주석 몇 줄만 늘어도 문구가 **창 밖으로 밀려** 애먼 곳에서 울었다(174회차).
          고정 글자 수 대신 **중괄호를 맞춰 그 덩어리만** 떼어낸다. */
    final chat = File('lib/ui/chat.dart').readAsStringSync();
    final at = chat.indexOf("pick == 'react'");
    expect(at, greaterThan(0), reason: '좋아요 갈래를 못 찾았다 — 이 시험이 헛돌고 있다');
    final open = chat.indexOf('{', at);
    var d = 0, i = open;
    for (; i < chat.length; i++) {
      if (chat[i] == '{') d++;
      if (chat[i] == '}') { d--; if (d == 0) break; }
    }
    final block = chat.substring(open, i);
    expect(block.contains('반응을 남기지 못했어요'), isTrue,
        reason: '좋아요가 실패해도 아무 말이 없다 — 회원은 눌린 건지 아닌지 알 수 없다');
    expect(block.contains('if (!ok)'), isTrue,
        reason: '성공/실패를 받아만 두고 «안 본다»');
  });
}
