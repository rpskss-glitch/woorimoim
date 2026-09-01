// 이 폰이 모임을 그만 쓸 때 «알림도» 그치는지 (134회차).
//
// 「모임에서 나가기」는 서버의 회원 자리를 그대로 둔다(다시 들어올 수 있게 — 그게 맞다).
// 그런데 «알림 받는 자리»(push.<내 번호>)까지 그대로 두고 있었다.
// 그 자리에 든 것은 **이 폰의 살아 있는 토큰**이라, 나간 모임의 대화 알림이 계속 왔다.
// 눌러도 그 모임 화면은 없어(프로필을 지웠으니) 엉뚱한 데로 간다.
// 「탈퇴 처리」는 처음부터 push 를 비웠다 — 두 길이 어긋나 있었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

/// [from] 뒤 [n]글자 — 다음 «선언»을 넘지 않는 만큼만.
String after(String src, String from, {int n = 900}) {
  final at = src.indexOf(from);
  if (at < 0) return '';
  return src.substring(at, (at + n).clamp(at, src.length));
}

void main() {
  final settings = stripComments(File('lib/ui/settings.dart').readAsStringSync());
  final members = stripComments(File('lib/ui/members.dart').readAsStringSync());

  test('스스로 나갈 때 «알림 받는 자리»를 비운다', () {
    // 2026-09-01: 「모임에서 나가기」→「로그아웃」으로 이름을 바꿨다(탈퇴와 헷갈리지 않게)
    final at = settings.indexOf("label: const Text('로그아웃')");
    expect(at, greaterThan(0), reason: '로그아웃 단추를 못 찾았다');
    // 단추의 처리는 그 위에 있다 (onPressed 가 먼저 온다)
    final body = settings.substring((at - 2200).clamp(0, at), at);
    expect(body.contains("'push."), isTrue,
        reason: '나간 모임의 알림이 이 폰에 계속 온다');
    expect(body.contains('clearProfile()'), isTrue);
    expect(body.indexOf("'push.") < body.indexOf('clearProfile()'), isTrue,
        reason: '프로필을 먼저 지우면 어느 모임인지 알 수 없어 못 비운다');
  });

  test('못 비워도 나가기는 막지 않는다', () {
    final at = settings.indexOf("'push.");
    final body = settings.substring((at - 400).clamp(0, at), (at + 400).clamp(0, settings.length));
    expect(body.contains('try {'), isTrue);
    expect(body.contains('catch'), isTrue,
        reason: '신호가 없다고 못 나가면 더 나쁘다');
  });

  test('탈퇴 처리도 «알림 받는 자리»를 비운다 (원래 그랬다 — 지키기)', () {
    expect(after(members, "'members.\$uid': null,").contains("'push.\$uid': null"),
        isTrue);
  });

  test('회원 자리는 «그대로» 둔다 — 다시 들어올 수 있어야 한다', () {
    /* 나가기는 「이 폰에서만」이다. 서버의 members 를 지우면 이름·직책·출석이 통째로 날아간다. */
    final at = settings.indexOf("label: const Text('로그아웃')");
    expect(at, greaterThan(0), reason: '로그아웃 단추를 못 찾았다');
    final body = settings.substring((at - 2200).clamp(0, at), at);
    expect(body.contains("'members."), isFalse,
        reason: '나가기가 서버의 회원 자리를 건드리면 안 된다');
  });
}
