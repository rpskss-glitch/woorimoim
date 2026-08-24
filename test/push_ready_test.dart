// 알림 화면이 «사실»을 말하는지.
//
// Push.mode 는 적힌 것이 없으면 'all' 을 돌려준다. 그래서 알림을 한 번도 켠 적 없는 회원에게도
// 설정 화면이 「모두 받기」를 켜진 것처럼 보여 줬다 — 서버에 토큰이 없어 한 통도 안 오는데도.
// (80회차)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/push.dart';

const me = 'u1';

/// 그 회원의 「알림 칸」만 담은 묶음 (서버 문서의 push 자리와 같은 모양)
Map? seat(Map<String, dynamic>? mine) => mine == null ? null : {me: mine};

void main() {
  test('한 번도 안 켠 회원은 «준비 안 됨»이다 (범위는 모두 받기로 보이더라도)', () {
    expect(Push.modeIn(null, me), 'all', reason: '적힌 것이 없으면 모두 받기가 기본');
    expect(Push.readyIn(null, me), isFalse, reason: '토큰이 없으면 한 통도 안 온다');
  });

  test('범위만 골라 두고 토큰이 없으면 여전히 «준비 안 됨»', () {
    expect(Push.modeIn(seat({'mute': 'admin'}), me), 'admin');
    expect(Push.readyIn(seat({'mute': 'admin'}), me), isFalse, reason: '기록만 있고 토큰이 없는 자리');
  });

  test('토큰이 적혀 있어야 준비된 것', () {
    expect(Push.readyIn(seat({'mute': 'all', 'token': 'abc123'}), me), isTrue);
    expect(Push.readyIn(seat({'mute': 'all', 'token': ''}), me), isFalse, reason: '빈 토큰은 없는 것과 같다');
    expect(Push.readyIn(seat({'mute': 'all', 'token': 12345}), me), isFalse, reason: '글자가 아닌 값도 없는 것으로 본다');
  });

  test('알림 칸이 아예 없거나 남의 것이어도 죽지 않는다', () {
    expect(Push.modeIn(null, me), 'all');
    expect(Push.readyIn(null, me), isFalse);
    expect(Push.readyIn({}, ''), isFalse);
    expect(Push.readyIn(seat({'token': 'x'}), '다른사람'), isFalse);
  });

  test('설정 화면이 토큰 없이 「모두 받기」를 고른 것으로 보여주지 않는다', () {
    final src = File('lib/ui/settings.dart').readAsStringSync();
    final at = src.indexOf('for (final m in Push.modes)');
    expect(at, greaterThan(0));
    final body = src.substring(at, at + 700);
    expect(body.contains('Push.i.ready'), isTrue,
        reason: '토큰이 없으면 고른 것으로 보이면 안 된다');
    expect(body.contains("m[0] == 'off'"), isTrue,
        reason: '「끄기」는 토큰이 없어도 말이 맞으므로 그대로 보여야 한다');
    expect(src.contains('아직 알림을 켜지 않았어요'), isTrue,
        reason: '왜 안 오는지 회원에게 말해야 한다');
  });

  test('홈의 알림 권유 카드도 «토큰»을 보고 판단한다', () {
    final src = File('lib/ui/home.dart').readAsStringSync();
    expect(src.contains('!Push.i.ready'), isTrue,
        reason: '기록만 보면, 범위만 골라 둔 회원에게서 카드가 사라져 켠 줄 안다');
    expect(src.contains('containsKey(Store.i.myUid)'), isFalse,
        reason: '옛 판단이 남아 있다');
  });
}
