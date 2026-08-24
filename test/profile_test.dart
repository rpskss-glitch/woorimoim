// 기기에 남은 «내 자리» 정보가 망가졌을 때.
//
// 이 값은 앱이 켜질 때 가장 먼저 읽히고 `code`·`slot` 은 곧바로 `as String?` 으로 읽힌다.
// 글자가 아니면 그 자리에서 터지는데, 값이 기기에 남아 있어 **껐다 켜도 계속 터진다** — 90회차.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';

void main() {
  test('제대로 된 값은 그대로 쓴다', () {
    final p = AppState.tidyProfile({'code': 'ABC123', 'slot': 'u1', 'name': '홍길동'});
    expect(p, {'code': 'ABC123', 'slot': 'u1', 'name': '홍길동'});
  });

  test('숫자·참거짓이 들어 있어도 글자로 바꿔 쓴다', () {
    final p = AppState.tidyProfile({'code': 123456, 'slot': 'u1', 'name': true});
    expect(p?['code'], '123456');
    expect(p?['name'], 'true');
  });

  test('이름이 없어도 자리는 살린다 (모임까지 잃으면 안 된다)', () {
    final p = AppState.tidyProfile({'code': 'ABC123', 'slot': 'u1'});
    expect(p?['code'], 'ABC123');
    expect(p?['name'], '');
  });

  test('모임 코드나 내 번호가 없으면 «없는 것»으로 본다', () {
    for (final bad in [
      {'slot': 'u1'},
      {'code': 'ABC123'},
      {'code': '', 'slot': 'u1'},
      {'code': 'ABC123', 'slot': ''},
      {'code': ['배열'], 'slot': 'u1'},
      {'code': 'ABC123', 'slot': {'묶음': 1}},
    ]) {
      expect(AppState.tidyProfile(bad), isNull, reason: '$bad');
    }
  });

  test('묶음이 아닌 것도 «없는 것»으로 본다', () {
    for (final bad in [null, '글자', 42, ['배열'], true]) {
      expect(AppState.tidyProfile(bad), isNull, reason: '$bad');
    }
  });

  test('다듬은 값에는 «군더더기»가 안 남는다', () {
    // 옛 버전이 남긴 방장 코드 같은 것이 따라오면 안 된다
    final p = AppState.tidyProfile(
        {'code': 'ABC123', 'slot': 'u1', 'name': '나', 'ownerCode': 'ZZZ999'});
    expect(p!.keys.toSet(), {'code', 'slot', 'name'});
  });

  test('앱이 켜질 때 이 다듬기를 실제로 거친다', () {
    final src = File('lib/state.dart').readAsStringSync();
    final at = src.indexOf('Future<void> loadProfile()');
    expect(at, greaterThan(0));
    final body = src.substring(at, src.indexOf('\n  }\n', at));
    expect(body.contains('tidyProfile('), isTrue,
        reason: '안 다듬으면 망가진 값에 앱이 켜지자마자 터지고 껐다 켜도 그대로다');
    expect(body.contains('.cast<String, dynamic>()'), isFalse,
        reason: '옛 방식(모양을 안 보는 것)이 남아 있다');
  });

  test('가입 화면도 생년월일을 «글자일 때만» 쓴다', () {
    final src = File('lib/ui/onboarding.dart').readAsStringSync();
    expect(src.contains("last['birth'] as String?"), isFalse,
        reason: '숫자가 들어 있으면 가입 화면이 통째로 안 뜬다');
    expect(src.contains('b is String'), isTrue);
  });
}
