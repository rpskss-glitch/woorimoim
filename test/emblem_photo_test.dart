// 모임 상징을 «이모지로 되돌릴 때» 사진이 남는가 (149회차).
//
// 앱은 이모지로 바꿔도 문서에 사진 번호를 «그대로 두고» 있었다.
//   · 아무 데도 안 보이는 사진에 **보관 요금만 계속** 나간다
//   · 웹앱은 처음부터 지운다 (`photo: kind === 'photo' ? photo : null`) — 두 앱이 어긋나 있었다
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

const _web = r'C:\Users\asas3\Desktop\앞산배드민턴\index.html';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

void main() {
  final settings = stripComments(File('lib/ui/settings.dart').readAsStringSync());

  test('이모지로 바꾸면 사진 번호를 «지운다»', () {
    expect(settings.contains("'photo': kind == 'photo' ? photo : null"), isTrue,
        reason: '번호가 남으면 아무도 안 보는 사진에 요금만 나간다');
    expect(settings.contains("if (photo != null) 'photo': photo"), isFalse,
        reason: '넣을 때만 적던 옛 방식이 돌아왔다');
  });

  test('사진을 그만 쓸 때도 «옛 원본»을 치운다', () {
    expect(settings.contains("(picked != null || kind != 'photo')"), isTrue,
        reason: '새 사진으로 바꿀 때만 치우면, 이모지로 갈 때 원본이 남는다');
  });

  test('웹앱도 같은 규칙이다 (두 앱이 같은 것을 지운다)', () {
    final f = File(_web);
    if (!f.existsSync()) {
      markTestSkipped('웹앱 파일이 없는 기기 — 앱 쪽만 확인했다');
      return;
    }
    expect(
        RegExp(r"photo:\s*this\._e\.kind === 'photo' \? this\._e\.photo : null")
            .hasMatch(f.readAsStringSync()),
        isTrue,
        reason: '웹앱 규칙이 바뀌었다 — 앱도 같이 봐야 한다');
  });

  test('사진 상징이면 지울 원본으로 잡히고, 이모지면 안 잡힌다', () {
    expect(
        Store.photoIdsOfCouple({
          'emblem': {'kind': 'photo', 'photo': 'st:c/e1'}
        }),
        ['st:c/e1']);
    expect(
        Store.photoIdsOfCouple({
          'emblem': {'kind': 'emoji', 'emoji': '🏸', 'photo': null}
        }),
        isEmpty);
    /* ⚠️ 이 고침 «전»에 저장된 문서는 이모지인데 사진 번호가 남아 있다.
       그것도 반드시 지울 대상으로 잡아야 한다 — 안 그러면 그 원본은
       방을 지울 때조차 안 걸려 영영 남는다. 그래서 `kind` 를 보지 않고 챙긴다. */
    expect(
        Store.photoIdsOfCouple({
          'emblem': {'kind': 'emoji', 'emoji': '🏸', 'photo': 'st:c/old'}
        }),
        ['st:c/old'],
        reason: '옛 문서에 남은 사진을 못 챙기면 영영 남는다');
  });

  test('사진 번호가 null 이어도 정리가 안 터진다', () {
    final c = Store.tidyCouple({
      'emblem': {'kind': 'emoji', 'emoji': '🏸', 'photo': null, 'size': 1, 'rot': 0}
    })!;
    expect((c['emblem'] as Map)['photo'], isNull);
    expect((c['emblem'] as Map)['emoji'], '🏸');
  });
}
