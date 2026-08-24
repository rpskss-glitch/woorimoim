// 방을 비울 때 «남는 것이 없는지» (133회차).
//
// `setItems` 가 세우는 자리는 하나도 빠짐없이 `clearProfile` 이 비워야 한다.
// `_byId`(번호로 한 건 찾기)가 남아 있었다 — 답장 인용이 그걸 쓰므로
// 없어진 모임의 대화가 번호로 그대로 나올 수 있었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

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

Map<String, dynamic> msg(String id) =>
    {'id': id, 'type': 'msg', 'text': '말 $id', 'by': 'u1', 'createdAt': 1700000000000};

void main() {
  test('방을 비우면 «번호로 찾기»에도 안 남는다', () {
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'u1': {'uid': 'u1', 'name': '갑', 'role': 'owner'}
      }
    });
    AppState.i.setItems([msg('m1'), msg('m2')]);
    expect(AppState.i.byId('m1'), isNotNull);

    AppState.i.resetRoom();
    expect(AppState.i.byId('m1'), isNull,
        reason: '없어진 모임의 대화가 답장 인용으로 뜬다');
    expect(AppState.i.by('msg'), isEmpty);
    expect(AppState.i.items, isEmpty);
  });

  test('방을 비우면 「채팅 탭으로 가라」는 신호도 지운다', () {
    /* 이 신호는 «그 방의 것»이다. 안 지우면:
       모임을 나간 뒤 트레이에 남아 있던 옛 알림을 누르면 신호가 서는데
       그때는 아무도 안 듣는다(본 화면이 없다) → 값이 그대로 남고,
       **나중에 «다른 모임»에 들어가는 순간 뜬금없이 채팅 탭이 열린다.** */
    AppState.i.openTab.value = 1;
    AppState.i.resetRoom();
    expect(AppState.i.openTab.value, isNull);
  });

  test('신호를 지워도 듣는 쪽이 안 터진다', () {
    // 비우는 것도 «알림»이라 듣는 쪽으로 간다 — 빈 값에 놀라면 안 된다
    var seen = 0;
    void onIt() => seen++;
    AppState.i.openTab.addListener(onIt);
    addTearDown(() => AppState.i.openTab.removeListener(onIt));
    AppState.i.openTab.value = 1;
    AppState.i.resetRoom();
    expect(seen, 2);
    expect(AppState.i.openTab.value, isNull);
  });

  test('«세우는 자리»와 «비우는 자리»의 짝이 맞다', () {
    /* 새 표를 하나 더 두면서 비우는 것을 잊으면 옛 방의 값이 그대로 남는다.
       기계가 짝을 지킨다 — 손으로 기억하지 않게. */
    final src = stripComments(File('lib/state.dart').readAsStringSync());
    final set = bodyOf(src, 'void setItems(');
    final clear = bodyOf(src, 'void resetRoom(');
    expect(set, isNotEmpty);
    expect(clear, isNotEmpty);
    final assigned = RegExp(r'(?:^|\s)(_?\w+)\s*=\s*[^=]')
        .allMatches(set)
        .map((m) => m.group(1)!)
        .where((n) => n != 'final' && n != 'var')
        .toSet();
    // setItems 안에서만 쓰는 «임시 값»은 뺀다
    assigned.removeAll({'m', 'ids', 'prev', 'id', 'x', 'e', 'a', 'b'});
    final missing =
        assigned.where((n) => !RegExp('$n' r'\s*=').hasMatch(clear)).toList();
    expect(missing, isEmpty,
        reason: 'setItems 가 세우는데 clearProfile 이 안 비우는 자리: $missing');
  });

  test('읽음 표시도 함께 지운다 — 다음 모임에 따라가지 않게', () {
    final clear = bodyOf(
        stripComments(File('lib/state.dart').readAsStringSync()),
        'Future<void> clearProfile(');
    expect(clear.contains('resetRoom()'), isTrue,
        reason: '방을 비우는 길이 둘로 갈리면 언젠가 한쪽만 고친다');
    for (final k in ['club_seenchat', 'club_seendiary']) {
      expect(clear.contains(k), isTrue,
          reason: '$k 가 남으면 새 모임의 옛 대화가 전부 «읽음»으로 잡힌다');
    }
  });
}
