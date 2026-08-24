// 알림 «뒷자리»가 조용히 죽지 않는가 (150회차).
//
// 앱이 꺼져 있을 때 오는 알림은 이 자리가 처리한다. 여기서 오류가 새어 나가면
// **아무도 못 받는다** — 그 알림 한 통이 조용히 사라지고,
// 안드로이드가 이 뒷자리를 접으면 뒤이은 알림까지 안 올 수 있다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

/// 함수 몸통만 — 매개변수 괄호를 짝 맞춰 닫은 «뒤»의 `{` 부터 (120회차 함정).
String bodyOf(String src, String decl) {
  final at = src.indexOf(decl);
  if (at < 0) return '';
  var i = src.indexOf('(', at), d = 0;
  for (; i < src.length; i++) {
    if (src[i] == '(') d++;
    if (src[i] == ')') {
      d--;
      if (d == 0) break;
    }
  }
  final open = src.indexOf('{', i);
  d = 0;
  for (var j = open; j < src.length; j++) {
    if (src[j] == '{') d++;
    if (src[j] == '}') {
      d--;
      if (d == 0) return src.substring(open, j + 1);
    }
  }
  return src.substring(open);
}

void main() {
  final body = bodyOf(stripComments(File('lib/push.dart').readAsStringSync()),
      'Future<void> pushBackgroundHandler(');

  test('뒷자리는 «걸음마다» 받아 낸다', () {
    expect(body, isNotEmpty);
    expect(RegExp(r'catch \(_\)').allMatches(body).length, greaterThanOrEqualTo(3),
        reason: '준비·길 만들기·띄우기가 각각 받아 내야 «준비가 실패해도 띄운다»');
  });

  test('«준비»가 실패해도 «띄우기»는 해 본다', () {
    /* 알림 띄우기 자체는 Firebase 가 없어도 된다 — 준비 실패로 통째로 멈추면 안 된다. */
    final init = body.indexOf('Firebase.initializeApp');
    final show = body.indexOf('local.show(');
    expect(init, greaterThan(0));
    expect(show, greaterThan(init));
    final between = body.substring(init, show);
    expect(between.contains('catch (_)'), isTrue,
        reason: '준비가 던지면 띄우기까지 못 간다');
  });

  test('어느 앱인지 «여기서 다시» 알아낸다', () {
    // 뒷자리는 따로 도는 자리라 main() 에서 정한 것이 하나도 안 넘어온다
    expect(body.contains('Cfg.detectBrand()'), isTrue);
    final brand = body.indexOf('Cfg.detectBrand()');
    expect(brand, lessThan(body.indexOf('Firebase.initializeApp')),
        reason: 'Firebase 를 켜기 전에 갈래를 알아야 열쇠를 고른다');
  });

  test('알림 길(채널)이 «높음»이라 소리·헤드업이 뜬다', () {
    /* 채널 중요도가 낮으면 알림마다 높게 줘도 안드로이드가 무시한다. */
    final push = stripComments(File('lib/push.dart').readAsStringSync());
    final at = push.indexOf('static const channel = AndroidNotificationChannel(');
    expect(at, greaterThan(0));
    expect(push.substring(at, at + 220).contains('importance: Importance.high'),
        isTrue);
  });
}
