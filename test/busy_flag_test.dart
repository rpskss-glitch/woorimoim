import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 「도는 중」 표시(_busy·_loading…)는 **실패했을 때도 반드시 풀려야 한다.**
   안 풀리면 단추가 그 자리에 굳는다 — 다시 눌리지도 않고, 화면을 나갔다 와야 산다.
   126회차 실제: 「↑ 이전 대화 더 보기」가 터지면 `_loadingOlder` 가 참으로 남아
   ① 단추가 「불러오는 중…」인 채 굳고 ② `_keepPosition` 이 참이라
   **새 대화가 와도 화면이 안 내려갔다**(까닭을 알 수 없는 고장). */

/// 표시를 세운 뒤 «다른 함수»가 받아 내는 자리에 붙이는 표시.
const _ok = ' // 부른 함수가 받아 낸다';

/// [at] 을 감싸고 있는 «메서드 한 덩어리» — 2칸 들여쓴 선언과 선언 사이.
///
/// ⚠️ 「몇 글자 뒤까지」로 창을 잡으면 **다음 함수까지 넘어간다.**
///    126회차에 실제로 그랬다: 창이 옆 메서드의 `catch` 를 보고
///    「받아 내고 있다」고 우겨 미끼를 놓쳤다. (85·111·119회차와 같은 함정)
String methodAround(String src, int at) {
  final decl = RegExp(r'^  (Future|void|static|bool|int|String|[A-Z]\w*)[ <]',
      multiLine: true);
  var start = 0, end = src.length;
  for (final m in decl.allMatches(src)) {
    if (m.start <= at) {
      start = m.start;
    } else {
      end = m.start;
      break;
    }
  }
  return src.substring(start, end);
}

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  test('「도는 중」 표시는 실패해도 풀린다', () {
    final bad = <String>[];
    /* ⚠️ `lib/ui` 만 훑으면 **main.dart 를 놓친다** — 130회차에 실제로 놓쳤다.
       「연결하는 중…」 단추가 터지면 굳는 자리가 거기 있었다. lib 전체를 본다. */
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final raw = f.readAsStringSync();
      final code = stripComments(raw);
      final rel = f.path.replaceAll(r'', '/');
      for (final m
          in RegExp(r'_(\w*(?:usy|oading)\w*)\s*=\s*true').allMatches(code)) {
        final name = m.group(1)!;
        final body = methodAround(code, m.start);
        final after = body.substring(body.indexOf('_$name = true'));
        /* 풀리는 길은 셋 중 하나다:
             · catch / finally 로 받아 내거나
             · 「못 했으면 null」 갈래에서 풀거나 (addItem 은 던지지 않고 null 을 준다)
             · 표시를 세운 뒤 «다른 함수»가 받아 내거나 — 그때는 그 줄에 표시를 붙인다
               (`// 부른 함수가 받아 낸다`). 기계가 함수를 따라가게 만들어 봤더니
               되레 헛돌아서, 101회차의 「주석이어도 된다」와 같은 방식으로 바꿨다. */
        final ok = after.contains('catch') ||
            after.contains('finally') ||
            (after.contains('== null') && after.contains('_$name = false')) ||
            raw.contains('_$name = true;$_ok');
        if (!ok) bad.add('$rel: _$name');
      }
    }
    expect(bad, isEmpty,
        reason: '실패하면 표시가 굳어 단추가 그 자리에서 멈춘다: ${bad.join(', ')}');
  });

  test('옛 대화 불러오기는 «터져도» 풀고 알려준다', () {
    final code = stripComments(File('lib/ui/chat.dart').readAsStringSync());
    final at = code.indexOf('Store.i.loadOlder(');
    expect(at, greaterThan(0));
    final before = code.substring((at - 400).clamp(0, at), at);
    expect(before.contains('try {'), isTrue, reason: '감싸지 않으면 표시가 굳는다');
    final after = code.substring(at, (at + 700).clamp(0, code.length));
    expect(after.contains('catch'), isTrue);
    expect(after.contains('_loadingOlder = false'), isTrue,
        reason: '터진 갈래에서도 «도는 중»을 풀어야 한다');
  });

  test('불러오다 터져도 «다시 눌러 볼» 수 있어야 한다', () {
    // 단추 자체는 hasOlder() 로 그리므로, 터졌을 때 그 값이 안 꺼져야 한다
    final store = stripComments(File('lib/store.dart').readAsStringSync());
    final at = store.indexOf('Future<int> loadOlder(');
    final body = store.substring(at, store.indexOf('return s.docs.length;', at));
    expect(body.indexOf('.get()'), lessThan(body.indexOf('_hasMore =')),
        reason: '읽기가 터지면 그 뒤 줄은 안 돈다 — 단추 상태가 그대로 남아 다시 눌린다');
  });
}
