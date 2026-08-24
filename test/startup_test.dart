// 앱이 «켜지는 첫 순간» (130회차).
//
// `main()` 안에서 하나라도 터지면 `runApp` 이 아예 안 불려 **흰 화면**이 된다.
// 회원에게는 아무 말도 안 보이고 껐다 켜도 그대로다 — 빠져나올 길이 없다.
// 터질 수 있는 자리가 실제로 여럿이다:
//   · SharedPreferences.getInstance() — 기기에 남은 값이 깨졌을 때
//   · Firebase.initializeApp — 갈래(woori/apsan)와 열쇠가 어긋난 앱일 때
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

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
  final src = stripComments(File('lib/main.dart').readAsStringSync());

  test('시작하다 터져도 «흰 화면»이 되지 않는다', () {
    final boot = bodyOf(src, 'Future<bool> bootstrap(');
    expect(boot, isNotEmpty, reason: 'bootstrap 을 못 찾았다');
    expect(boot.contains('try {'), isTrue);
    expect(boot.contains('catch'), isTrue);
    expect(boot.contains('return false;'), isTrue,
        reason: '터졌으면 «안 됐다»고 돌려줘야 안내 화면으로 간다');
    for (final must in [
      'Firebase.initializeApp',
      'Store.i.init()',
      'AppState.i.loadProfile()',
      'Cfg.detectBrand()',
    ]) {
      expect(boot.contains(must), isTrue, reason: '$must 이 감싸진 안에 없다');
    }
  });

  test('시작 차례가 «뒤집히면 조용히 망가지는» 곳을 못 박는다', () {
    /* 있는지만 보면 모자란다 — **차례**가 뜻을 갖는 자리가 둘 있다.
       ① 갈래 알아내기 → Firebase 켜기
          Firebase 열쇠가 앱마다 다르다. 뒤집히면 «겉은 앞산인데 속은 우리 모임»인 앱이 서고,
          알림이 엉뚱한 곳으로 가거나 아예 안 온다(config.dart 의 경고 그대로).
       ② 그릇 준비(Store.init) → 프로필 읽기(loadProfile)
          `loadProfile` 은 `Store.i.getStr` 로 기기 저장을 읽는데, 그 저장은 `Store.init` 에서 선다.
          뒤집히면 **회원의 «모임 기억»이 조용히 사라져** 앱을 켤 때마다 가입 화면이 뜬다. */
    final boot = bodyOf(src, 'Future<bool> bootstrap(');
    final brand = boot.indexOf('Cfg.detectBrand()');
    final fb = boot.indexOf('Firebase.initializeApp');
    final init = boot.indexOf('Store.i.init()');
    final prof = boot.indexOf('AppState.i.loadProfile()');
    for (final x in [brand, fb, init, prof]) {
      expect(x, greaterThan(0), reason: '시작 차례를 못 읽었다 — 이 시험이 헛돌고 있다');
    }
    expect(brand, lessThan(fb),
        reason: '갈래를 «먼저» 알아야 그 앱의 Firebase 열쇠를 고른다 — '
            '뒤집히면 알림이 엉뚱한 곳으로 가거나 아예 안 온다');
    expect(init, lessThan(prof),
        reason: '기기 저장을 «먼저» 세워야 프로필을 읽는다 — '
            '뒤집히면 회원의 모임 기억이 조용히 사라져 앱을 켤 때마다 가입 화면이 뜬다');
  });

  test('프로필 읽기가 «기기 저장»에 기대고 있다 — 그래서 차례가 중요하다', () {
    // 이 기댐이 사라지면 위 차례 검사도 뜻이 없어진다
    final st = stripComments(File('lib/state.dart').readAsStringSync());
    final body = bodyOf(st, 'Future<void> loadProfile(');
    expect(body, contains('Store.i.getStr'),
        reason: '프로필을 기기 저장에서 안 읽는다 — 차례 검사를 다시 봐야 한다');
  });

  test('main 은 감싸진 길 «하나»만 쓴다 — 밖에서 기다리는 것이 없다', () {
    final body = bodyOf(src, 'void main(');
    expect(body.contains('runApp('), isTrue);
    // main 안에서 기다리는 것은 bootstrap() 뿐이라야 한다
    final awaits = RegExp(r'await\s+([\w.]+)').allMatches(body).map((m) => m.group(1)).toList();
    expect(awaits, ['bootstrap'],
        reason: 'main 안에서 감싸지 않고 기다리면 그게 터질 때 흰 화면이 된다: $awaits');
  });

  test('「다시 시도」는 «같은 길»을 다시 밟는다', () {
    /* Store.init 만 다시 부르면, Firebase 가 안 선 경우에는 아무리 눌러도 안 살아난다. */
    final at = src.indexOf('_busy = true');
    expect(at, greaterThan(0));
    final after = src.substring(at, (at + 700).clamp(0, src.length));
    expect(after.contains('bootstrap()'), isTrue,
        reason: 'Store.init 만 다시 부르면 Firebase 가 안 선 경우 못 살아난다');
    expect(after.contains('catch'), isTrue);
    expect(after.contains('_busy = false'), isTrue,
        reason: '터진 갈래에서도 «도는 중»을 풀어야 다시 눌린다');
  });

  test('뒤에서 오는 알림 걸기는 «한 번»만 한다', () {
    // bootstrap 은 「다시 시도」에서 또 불린다 — 그때마다 걸면 겹겹이 쌓인다
    final boot = bodyOf(src, 'Future<bool> bootstrap(');
    final at = boot.indexOf('onBackgroundMessage');
    expect(at, greaterThan(0));
    expect(boot.substring(0, at).contains('_bgBound'), isTrue,
        reason: '다시 시도할 때마다 또 걸린다');
  });
}
