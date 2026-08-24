// 새 방 만들기는 «끝난 것을 확인해야» 한다 (139회차).
//
// 총괄은 만들어진 코드를 방장에게 «말이나 문자로» 전한다.
// 보통 저장은 6초 뒤 「맡겼다」로 넘어가는데(기기에 쌓였다가 연결되면 간다),
// 여기서 그러면 **실제로는 안 들어갔는데 「만들었어요」가 뜨고 방장이 못 들어온다.**
// 목록(META)에 못 적어도 마찬가지 — 콘솔에 «안 보이는 방»이 된다.
// (120회차 「방 지우기」와 같은 갈래: 다음 걸음이 앞 걸음의 «확인»에 기대는 자리)
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

void main() {
  const quick = Duration(milliseconds: 60);

  test('«확인해야 하는» 저장은 답이 없으면 던진다', () async {
    await expectLater(
      Store.mustSettle(() => Completer<void>().future, '시험', wait: quick),
      throwsA(isA<StateError>()),
    );
  });

  test('보통 저장은 답이 없어도 조용히 넘어간다 (그게 맞는 자리다)', () async {
    // 대화·투표는 기기에 쌓였다가 연결되면 간다 — 여기서 막으면 오히려 못 쓴다
    await Store.settleVoid(() => Completer<void>().future, '시험')
        .timeout(const Duration(seconds: 8));
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('방 만들기는 두 걸음 모두 «확인»을 건다', () {
    final admin = stripComments(File('lib/ui/admin.dart').readAsStringSync());
    final body = bodyOf(admin, 'Future<void> _create(');
    expect(body, isNotEmpty);
    expect(RegExp(r'setClubTitle\([^;]*?,\s*true\s*\)', dotAll: true).hasMatch(body),
        isTrue, reason: '방을 못 만들었는데 코드를 방장에게 보내게 된다');
    expect(body.contains('sure: true'), isTrue,
        reason: '목록에 못 적으면 콘솔에 안 보이는 방이 된다');
  });

  test('못 만들었으면 만든 것을 되돌리고 «못 만들었다»고 말한다', () {
    final admin = stripComments(File('lib/ui/admin.dart').readAsStringSync());
    final body = bodyOf(admin, 'Future<void> _create(');
    expect(body.contains('roomMade'), isTrue);
    expect(body.contains('deleteCouple('), isTrue, reason: '이름을 차지한 채로 남는다');
    expect(body.contains('방을 만들지 못했어요'), isTrue);
  });

  test('「확인」을 걸면 «진짜로» 끝난 것을 확인한다', () {
    /* 화면에서 `sure: true` 를 넘겨도, 문 안에서 「맡겼다」로 넘어가면 아무 소용이 없다.
       (139회차에 이 미끼가 한 번 새어 나갔다 — 화면 쪽 모양만 보고 있었다) */
    final store = stripComments(File('lib/store.dart').readAsStringSync());
    final branches = RegExp(r'sure\s*\?').allMatches(store).toList();
    expect(branches.length, 2, reason: '확인 갈래는 모임 저장·고치기 둘이다');
    for (final m in branches) {
      final w = store.substring(m.end, (m.end + 170).clamp(0, store.length));
      expect(w.contains('mustSettle('), isTrue,
          reason: '「확인」인데 맡기고 넘어가면 확인이 아니다');
    }
  });

  test('«확인 거는 문»은 방 만들기에서만 쓴다', () {
    /* 대화·투표·읽음까지 확인을 걸면, 신호가 약한 체육관에서 아무것도 못 쓰게 된다. */
    final where = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      if (rel.endsWith('lib/store.dart')) continue; // 문 자체가 있는 곳
      if (stripComments(f.readAsStringSync()).contains('sure: true')) where.add(rel);
    }
    expect(where, ['lib/ui/admin.dart']);
  });
}
