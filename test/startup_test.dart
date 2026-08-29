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
    final boot = bodyOf(src, 'Future<bool> _bootstrapOnce(');
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
    final boot = bodyOf(src, 'Future<bool> _bootstrapOnce(');
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

  test('시작이 «끝나지 않을» 때도 흰 화면에 갇히지 않는다', () {
    /* try/catch 로는 못 막는 길: 인터넷이 반쯤 죽은 곳에서는 Firebase 가
       **던지지도 끝나지도 않는다.** 그러면 runApp 이 영영 안 불려 흰 화면이 된다.
       애플 심사장이 막힌 망 뒤에 있는 일이 잦아 이 자리가 2.1(미완성) 반려로 이어진다.
       그래서 `bootstrap` 은 시간을 재고, 넘으면 «안 됐다»로 돌려 안내 화면으로 보낸다. */
    final wrap = bodyOf(src, 'Future<bool> bootstrap(');
    expect(wrap, isNotEmpty, reason: 'bootstrap 을 못 찾았다');
    expect(wrap.contains('timeout('), isTrue,
        reason: '시간을 안 재면 매달린 채로 흰 화면이 된다');
    expect(wrap.contains('_bootstrapOnce()'), isTrue,
        reason: '지킴이가 실제 시작 절차를 감싸고 있어야 뜻이 있다');
    expect(wrap.contains('return false;'), isTrue,
        reason: '시간을 넘겼으면 «안 됐다»로 돌려줘야 안내 화면으로 간다');
    // main 은 그 «하나»만 기다린다 — 밖에서 또 재면 어느 쪽이 잘랐는지 못 읽는다
    final body = bodyOf(src, 'void main(');
    expect(body.contains('.timeout('), isFalse,
        reason: 'main 에서 또 재고 있다 — 지킴이가 두 겹이다');
  });

  test('프로필 읽기가 «기기 저장»에 기대고 있다 — 그래서 차례가 중요하다', () {
    // 이 기댐이 사라지면 위 차례 검사도 뜻이 없어진다
    final st = stripComments(File('lib/state.dart').readAsStringSync());
    final body = bodyOf(st, 'Future<void> loadProfile(');
    expect(body, contains('Store.i.getStr'),
        reason: '프로필을 기기 저장에서 안 읽는다 — 차례 검사를 다시 봐야 한다');
  });

  test('main 은 «기다리지 않는다» — 그리는 일이 먼저다', () {
    /* 💥 2026-08-29 실측(인터넷을 끊고 켬): 준비가 끝나야 그리는 구조였더니
       첫 화면까지 **2분 6초**가 걸렸다. 15초 지킴이가 찍은 글조차 118초 뒤에 나왔다 —
       파이어베이스 초기화가 본 실을 붙들어 타이머까지 멈춰 세웠기 때문이다.
       그동안 회원이 보는 건 안드로이드 기본 스플래시뿐이라 「고장났다」로 읽힌다.
       그래서 `runApp` 을 먼저 부르고, 준비는 그 뒤에 돈다. */
    final body = bodyOf(src, 'void main(');
    expect(body.contains('runApp('), isTrue);
    final awaits = RegExp(r'await\s+([\w.]+)').allMatches(body).map((m) => m.group(1)).toList();
    expect(awaits, isEmpty,
        reason: 'main 이 무언가를 기다린다 — 그동안 화면이 통째로 비어 있다: $awaits');
  });

  test('준비하는 동안 보여줄 화면이 있다', () {
    // 「불러오는 중」이 없으면 준비가 끝날 때까지 아무것도 안 보인다
    expect(src.contains('불러오는 중'), isTrue,
        reason: '준비 중에 보여줄 것이 없다 — 회원 눈에는 멈춘 앱이다');
    expect(src.contains('class BootApp'), isTrue);
  });

  test('준비하다 터져도 «안내 화면»으로 간다', () {
    final body = bodyOf(src, 'Future<void> _go()');
    expect(body.contains('catch'), isTrue,
        reason: '터지면 「불러오는 중」인 채로 굳는다 — 빠져나올 길이 없다');
    expect(body.contains('setState'), isTrue);
  });

  test('「다시 시도」는 «같은 길»을 다시 밟는다', () {
    /* Store.init 만 다시 부르면, Firebase 가 안 선 경우에는 아무리 눌러도 안 살아난다. */
    final at = src.indexOf('_busy = true');
    expect(at, greaterThan(0));
    // 창을 넉넉히 — 주석이 길어지면 정작 볼 코드가 창 밖으로 밀려난다
    final after = src.substring(at, (at + 1400).clamp(0, src.length));
    // 한계를 주든 안 주든 «발 자체»를 다시 밟아야 한다
    expect(RegExp(r'bootstrap\(').hasMatch(after), isTrue,
        reason: 'Store.init 만 다시 부르면 Firebase 가 안 선 경우 못 살아난다');
    expect(after.contains('catch'), isTrue);
    expect(after.contains('_busy = false'), isTrue,
        reason: '터진 갈래에서도 «도는 중»을 풀어야 다시 눌린다');
  });

  test('뒤에서 오는 알림 걸기는 «한 번»만 한다', () {
    // bootstrap 은 「다시 시도」에서 또 불린다 — 그때마다 걸면 겹겹이 쌓인다
    final boot = bodyOf(src, 'Future<bool> _bootstrapOnce(');
    final at = boot.indexOf('onBackgroundMessage');
    expect(at, greaterThan(0));
    expect(boot.substring(0, at).contains('_bgBound'), isTrue,
        reason: '다시 시도할 때마다 또 걸린다');
  });
}
