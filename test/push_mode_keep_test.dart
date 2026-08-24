import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/push.dart';

/* 알림 「범위」(모두/공지만/끄기)는 회원이 설정에서 정하는 값이다.
   토큰을 적는 자리가 범위까지 같이 쓰면, 그 자리가 들고 있는 «전에 본» 값이 얹혀
   회원이 꺼 둔 알림이 되살아난다.
   특히 `setupIfAllowed`는 앱을 켠 지 **2초 만에** 불린다 — 그때 모임 문서가 아직
   안 왔으면 사본이 비어 있어 'all'이 얹힌다(경합이 아니라 «느린 신호»면 난다). */

/// Firestore set(merge:true) 흉내 — 안쪽 묶음끼리 합친다.
Map<String, dynamic> mergeSet(
    Map<String, dynamic> doc, Map<String, dynamic> data) {
  final out = Map<String, dynamic>.from(doc);
  data.forEach((k, v) {
    final cur = out[k];
    out[k] = (v is Map && cur is Map)
        ? mergeSet(Map<String, dynamic>.from(cur), Map<String, dynamic>.from(v))
        : v;
  });
  return out;
}

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

List<String> callBodies(String code, String name) {
  final out = <String>[];
  var at = 0;
  while (true) {
    final i = code.indexOf(name, at);
    if (i < 0) return out;
    var d = 0;
    var j = i + name.length - 1;
    for (; j < code.length; j++) {
      if (code[j] == '(') d++;
      if (code[j] == ')') {
        d--;
        if (d == 0) break;
      }
    }
    final end = j.clamp(i, code.length);
    out.add(code.substring(i, end));
    at = end + 1;
  }
}

void main() {
  test('적힌 것이 없으면 「모두 받기」로 본다 — 그래서 안 써도 된다', () {
    expect(Push.modeIn(null, 'u1'), 'all');
    expect(Push.modeIn({}, 'u1'), 'all');
    expect(Push.modeIn({'u1': <String, dynamic>{}}, 'u1'), 'all');
  });

  test('토큰만 적으면 꺼 둔 알림이 그대로 꺼져 있다', () {
    final server = {
      'push': {
        'u1': {'token': '옛토큰', 'mute': 'off'}
      }
    };
    final after = mergeSet(server, {
      'push': {
        'u1': {'token': '새토큰', 'at': 1}
      }
    });
    expect(Push.modeIn(after['push'] as Map, 'u1'), 'off');
    expect(((after['push'] as Map)['u1'] as Map)['token'], '새토큰');
  });

  test('범위를 같이 적으면 되살아난다 (재현 — 모임 문서가 아직 안 온 경우)', () {
    final server = {
      'push': {
        'u1': {'token': '옛토큰', 'mute': 'off'}
      }
    };
    // 앱을 켠 지 2초, 아직 문서가 안 와서 사본이 비어 있다 → 기본값 'all'이 잡힌다
    const Map? notYet = null;
    final staleMode = Push.modeIn(notYet, 'u1');
    expect(staleMode, 'all');

    final after = mergeSet(server, {
      'push': {
        'u1': {'token': '새토큰', 'at': 1, 'mute': staleMode}
      }
    });
    expect(Push.modeIn(after['push'] as Map, 'u1'), 'all',
        reason: '꺼 둔 알림이 되살아난다 — 이게 고치려는 버그');
  });

  test('「공지만 받기」도 마찬가지로 지켜진다', () {
    final server = {
      'push': {
        'u1': {'token': 'T', 'mute': 'admin'}
      }
    };
    final after = mergeSet(server, {
      'push': {
        'u1': {'token': 'T2', 'at': 9}
      }
    });
    expect(Push.modeIn(after['push'] as Map, 'u1'), 'admin');
  });

  test('알림 범위를 쓰는 곳은 「범위 바꾸기」 하나뿐이다', () {
    final code = stripComments(File('lib/push.dart').readAsStringSync());
    final withMute =
        callBodies(code, 'setCouple(').where((b) => b.contains("'mute'")).toList();
    expect(withMute, hasLength(1),
        reason: '토큰을 적는 자리가 범위까지 쓰면 회원이 정한 값을 되돌려 놓는다');
  });
}
