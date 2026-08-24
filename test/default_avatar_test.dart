import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/config.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 🏸 「아바타를 안 골랐을 때의 얼굴」은 **한 곳에만** 있어야 한다.

   184회차에 기본값을 바꿔 보는 흠내기를 넣었더니 이 자리가 안 물렸다:
     `((m['emoji'] …) ?? '🏸') == ((p['emoji'] …) ?? '🏸')`
   같은 이름·같은 아바타를 막는 검사인데 **기본값 «둘»을 서로 견준다.**
   그 둘이 어긋나면 «아바타를 안 고른 사람끼리»가 서로 다른 것으로 보여
   **검사가 조용히 멈춘다** — 같은 이름·같은 얼굴이 그대로 들어온다.
   그때 흩어져 있던 같은 글자가 **아홉 곳**이었다 → 한 곳으로 모았다. */
void main() {
  test('기본 얼굴이 «한 곳에만» 적혀 있다', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final p = f.path.replaceAll(r'\', '/');
      if (!p.endsWith('.dart') || p.endsWith('lib/config.dart')) continue;
      final s = f
          .readAsStringSync()
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
          .replaceAll(RegExp(r'//.*'), '');
      if (s.contains("?? '$defaultAvatar'")) bad.add(p);
    }
    expect(bad, isEmpty,
        reason: '기본 얼굴이 여러 곳에 흩어져 있다 — 하나만 어긋나도 '
            '«같은 이름·같은 아바타» 막기가 조용히 멈춘다: $bad');
  });

  test('겹침 검사의 «두 기본값»이 같은 이름을 쓴다', () {
    /* ⚠️ 「그 이모지 글자가 있나」로만 보면, 한쪽을 «다른 이모지»로 바꿔 놓아도 통과한다
       (184회차에 그렇게 틀렸다). **두 쪽이 같은 이름을 쓰는지**를 본다. */
    final s = File('lib/ui/members.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//.*'), '');
    final at = s.indexOf("(m['emoji'] as String?)");
    expect(at, greaterThan(0), reason: '겹침 검사를 못 찾았다 — 이 시험이 헛돌고 있다');
    final line = s.substring(s.lastIndexOf('\n', at) + 1, s.indexOf('\n', at));
    expect('defaultAvatar'.allMatches(line).length, 2,
        reason: '두 쪽이 «같은 기본 얼굴»을 안 쓴다 — '
            '아바타를 안 고른 사람끼리가 서로 다른 것으로 보여 겹침 검사가 조용히 멈춘다: $line');
    expect(RegExp(r"\?\?\s*'").hasMatch(line), isFalse,
        reason: '기본 얼굴을 «글자 그대로» 적어 두면 다시 어긋날 수 있다: $line');
  });

  test('아바타를 «둘 다 안 고른» 두 사람은 겹침으로 잡힌다', () {
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'u1': {'uid': 'u1', 'name': '갑'} // emoji 없음
      },
    });
    final clash = Logic.avatarClash(
        AppState.i.memberList, '갑', defaultAvatar, skipUid: 'u2');
    expect(clash, isNotNull,
        reason: '둘 다 기본 얼굴인데 «다른 사람»으로 본다 — '
            '채팅·출석·순위 어디서도 누가 누군지 구분이 안 된다');
  });

  test('아바타가 다르면 겹침이 아니다 — 거르기가 너무 넓지 않다', () {
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'u1': {'uid': 'u1', 'name': '갑', 'emoji': '🎾'}
      },
    });
    expect(Logic.avatarClash(AppState.i.memberList, '갑', defaultAvatar, skipUid: 'u2'),
        isNull);
  });

  test('회원 승인이 그 «한 이름»을 쓴다', () {
    final s = File('lib/ui/members.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//.*'), '');
    final at = s.indexOf('Future<void> _approve(');
    expect(at, greaterThan(0));
    final body = s.substring(at, s.indexOf('Future<', at + 30));
    expect(body, contains('defaultAvatar'),
        reason: '승인 자리가 기본 얼굴을 «직접» 적어 두면 다시 어긋날 수 있다');
  });
}
