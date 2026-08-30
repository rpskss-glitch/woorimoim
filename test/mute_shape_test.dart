import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/push.dart';
import 'package:woorimoim/store.dart';

/* 🔔 「알림 범위」를 앱과 서버가 **같게 읽는가**.

   서버(functions/index.js)는 이렇게 본다:
     const mute = v.mute || 'all';
     if (mute === 'off') continue;
     if (mute === 'admin' && !senderIsStaff) continue;
   즉 **off 도 admin 도 아니면 전부 「모두 받기」**다 — 빈 글자도 그렇다.

   앱은 「적힌 것이 없을 때만」 모두 받기로 봤다. 그래서 빈 글자·모르는 값이 오면
   설정 화면의 칩이 **셋 다 안 골라진 채**로 보였다 — 알림은 전부 오고 있는데도
   회원은 무엇이 켜져 있는지 알 수 없다.
   ※ 빈 글자는 남이 준 값이 아니라 **우리 다듬기가 스스로 만드는 값**이다
     (`push.<uid>.mute` 에 숫자·배열이 오면 `''` 로 바꾼다). */
void main() {
  Map<String, dynamic> push(Object? mute) {
    final seat = <String, dynamic>{'token': 't'};
    if (mute != null) seat['mute'] = mute;
    return {'u1': seat};
  }

  test('off·admin 은 그대로', () {
    expect(Push.modeIn(push('off'), 'u1'), 'off');
    expect(Push.modeIn(push('admin'), 'u1'), 'admin');
  });

  test('적힌 것이 없으면 모두 받기', () {
    expect(Push.modeIn(push(null), 'u1'), 'all');
    expect(Push.modeIn(null, 'u1'), 'all');
    expect(Push.modeIn(push('all'), 'u1'), 'all');
  });

  test('«빈 글자»도 모두 받기 — 다듬기가 스스로 만드는 값이다', () {
    expect(Push.modeIn(push(''), 'u1'), 'all',
        reason: '서버는 빈 글자를 「모두 받기」로 본다 — '
            '앱이 다르게 보면 칩이 하나도 안 골라진 채 알림만 온다');
  });

  test('«모르는 값»도 모두 받기 — 서버가 그렇게 보낸다', () {
    for (final v in ['digest', '모두', 'ALL']) {
      expect(Push.modeIn(push(v), 'u1'), 'all', reason: v);
    }
  });

  test('망가진 값이 와도 «다듬은 뒤»에는 모두 받기로 읽힌다', () {
    final c = Store.tidyCouple({
      'members': {'u1': {'uid': 'u1', 'name': '갑'}},
      'push': {
        'u1': {'token': 't', 'mute': ['배열']}
      },
    })!;
    expect(Push.modeIn(c['push'] as Map?, 'u1'), 'all');
    // 토큰은 살아 있어야 한다 — 「이 폰은 알림을 켰다」가 거짓이 되면 안 된다
    expect(Push.readyIn(c['push'] as Map?, 'u1'), isTrue);
  });

  test('세 갈래 가운데 «하나는 반드시» 골라진다', () {
    // 설정 화면은 `Push.i.mode == m[0]` 으로 칩을 고른다 —
    // 어떤 값이 와도 modes 안의 하나와 맞아야 칩이 비지 않는다
    final names = Push.modes.map((m) => m[0]).toSet();
    for (final v in [null, '', 'off', 'admin', 'all', '모르는값', 123]) {
      expect(names, contains(Push.modeIn(push(v), 'u1')),
          reason: '$v 일 때 어느 칩과도 안 맞는다 — 셋 다 빈 채로 보인다');
    }
  });

  test('서버가 아직 «그 두 가지만» 특별히 본다', () {
    final f = File('../앞산배드민턴/functions/index.js');
    if (!f.existsSync()) return;
    final s = f.readAsStringSync();
    expect(s, contains("mute === 'off'"),
        reason: '서버의 「끄기」 판정이 바뀌었다 — 앱의 modeIn 도 맞춰야 한다');
    expect(s, contains("mute === 'admin'"),
        reason: '서버의 「공지만」 판정이 바뀌었다');
    expect(s, contains("v.mute || 'all'"),
        reason: '서버가 빈 값을 「모두 받기」로 보던 것이 바뀌었다');
  });
}
