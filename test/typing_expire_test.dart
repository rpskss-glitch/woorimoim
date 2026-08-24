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

  test('화면이 «남은 시간»에 맞춰 스스로 다시 그린다', () {
    final code = stripComments(File('lib/ui/chat.dart').readAsStringSync());
    final at = code.indexOf('List<String> _typers()');
    expect(at, greaterThan(0));
    final body = code.substring(at, (at + 700).clamp(at, code.length));
    expect(body.contains('expiresInMs'), isTrue);
    expect(body.contains('Timer('), isTrue,
        reason: '다시 그릴 까닭이 없으면 멈춘 뒤에도 표시가 남는다');
    expect(code.contains('_typingTick?.cancel()'), isTrue,
        reason: '화면을 떠날 때 시계를 꺼야 한다');
  });
}
