// 「입력 중…」이 스스로 사라지는가 (137회차).
//
// 이 표시는 서버 값의 «나이»로 정해진다 — 값이 그대로면 화면을 다시 그릴 일이 없다.
// 그래서 상대가 치다가 멈추면 4초가 지나도 **「○○님이 입력 중…」이 그대로 떠 있었다**
// (다음 대화나 접속 표시가 올 때에야 사라졌다 — 몇 분 뒤일 수도 있다).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/ui/chat.dart';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

const now = 1755800000000;
bool member(String uid) => uid != '남';

void main() {
  test('막 친 사람은 «입력 중»으로 보이고, 사라질 때까지 남은 시간을 알려준다', () {
    final r = typingLive({'u2': now - 1000}, member, 'u1', now);
    expect(r.uids, ['u2']);
    expect(r.expiresInMs, typingWindow - 1000);
  });

  test('시간이 지난 값은 «안» 보인다', () {
    final r = typingLive({'u2': now - typingWindow}, member, 'u1', now);
    expect(r.uids, isEmpty);
    expect(r.expiresInMs, 0, reason: '보일 것이 없으면 다시 그릴 까닭도 없다');
  });

  test('여럿이면 «가장 먼저 사라질» 사람에 맞춘다', () {
    final r = typingLive({'u2': now - 3000, 'u3': now - 500}, member, 'u1', now);
    expect(r.uids.toSet(), {'u2', 'u3'});
    expect(r.expiresInMs, typingWindow - 3000,
        reason: '먼저 사라질 사람 때에 다시 그려야 목록이 제때 줄어든다');
  });

  test('내 것과 «지금 회원이 아닌» 사람은 안 센다', () {
    final r = typingLive({'u1': now, '남': now}, member, 'u1', now);
    expect(r.uids, isEmpty);
  });

  test('시계가 앞선 값·망가진 값도 안 믿는다', () {
    expect(typingLive({'u2': now + 60000}, member, 'u1', now).uids, isEmpty,
        reason: '앞선 값을 믿으면 영영 «입력 중»으로 남는다');
    expect(typingLive({'u2': '글자'}, member, 'u1', now).uids, isEmpty);
    expect(typingLive({'u2': null}, member, 'u1', now).uids, isEmpty);
  });

  test('「입력 중」은 **아무에게도 안 보인다**', () {
    /* 2026-08-30 사장님 결정 — 누가 글을 적고 있는지 남에게 알리지 않는다.
       동호회에서는 «보고 있다»는 것이 알려지는 것 자체가 부담이고,
       쓰다 지우면 그것까지 상대에게 보였다.
       덤으로 요금도 준다 — 이 값은 «글자를 칠 때마다» 서버에 쓰이는데,
       쓰기 한 번이 구독 중인 회원 수만큼 읽기 요금으로 곱해졌다.

       ⚠️ 셈(`typingLive`)은 **지우지 않는다** — 웹앱이 아직 이 값을 쓰고,
          옛 판 앱이 적어 둔 값도 남아 있다. 앱이 «안 그릴» 뿐이다(위 시험들이 그 셈을 지킨다). */
    final code = stripComments(File('lib/ui/chat.dart').readAsStringSync());
    expect(code.contains('님이 입력 중'), isFalse,
        reason: '「○○님이 입력 중…」을 다시 그리고 있다');

    // 보내지도 않는다 — 그리지만 않으면 요금은 그대로 나간다
    final at = code.indexOf('void _onTyping()');
    expect(at, greaterThan(0), reason: '_onTyping 이 사라졌다 — 이 시험이 헛돈다');
    final body = code.substring(at, (at + 260).clamp(at, code.length));
    expect(RegExp(r'\{\s*return;').hasMatch(body), isTrue,
        reason: '「입력 중」을 아직 서버에 보내고 있다 — 안 그리면서 요금만 낸다');
  });
}
