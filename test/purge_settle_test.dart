import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

/* 총괄 콘솔의 「방 지우기」는 ① 기록을 전부 지우고 ② 방 문서를 지우고 ③ 목록에서 뺀다.
   ②를 먼저 하면 규칙상 아무도 남은 기록에 손댈 수 없어 **영영 남는다**(보관 요금만 나간다).
   그래서 ①이 「맡겼다」로 넘어가면 안 된다 — 못 끝냈으면 던져서 멈춰야 방 문서가 남아
   다음에 마저 지울 수 있다.
   또 ②를 날것으로 부르면 신호가 끊겼을 때 답이 영영 안 와서
   「기록을 지우는 중…」 화면이 그대로 굳는다 (콘솔이 통째로 잠긴다). */

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

String blockAt(String src, int from) {
  final open = src.indexOf('{', from);
  if (open < 0) return '';
  var d = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '{') d++;
    if (src[i] == '}') {
      d--;
      if (d == 0) return src.substring(from, i + 1);
    }
  }
  return src.substring(from);
}

void main() {
  const quick = Duration(milliseconds: 60);

  test('끝나면 그대로 지나간다', () async {
    await Store.mustSettle(() => Future<void>.value(), '시험', wait: quick);
  });

  test('거절은 그대로 던진다', () async {
    await expectLater(
      Store.mustSettle(() => Future<void>.error(StateError('막힘')), '시험', wait: quick),
      throwsA(isA<StateError>()),
    );
  });

  test('답이 없으면 «맡겼다»로 넘어가지 않고 던진다', () async {
    // 이게 settle 과 다른 점이다 — settle 은 여기서 참을 돌려준다
    await expectLater(
      Store.mustSettle(() => Completer<void>().future, '시험', wait: quick),
      throwsA(isA<StateError>()),
    );
  });

  test('늦게 온 거절이 «처리 안 된 오류»로 새지 않는다', () async {
    final c = Completer<void>();
    await expectLater(
      Store.mustSettle(() => c.future, '시험', wait: quick),
      throwsA(isA<StateError>()),
    );
    c.completeError(StateError('늦게 온 거절'));
    // 여기서 안 잡혀 있으면 이 시험이 «처리 안 된 오류»로 깨진다
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });

  test('기록 지우기는 끝난 것을 확인하고 넘어간다', () {
    final src = stripComments(File('lib/store.dart').readAsStringSync());
    final at = src.indexOf('purgeClubData(');
    expect(at, greaterThan(0));
    /* ⚠️ 이름 바로 뒤에서 중괄호를 짝 맞추면 안 된다 — 다트에서는 그게
       **이름 있는 매개변수**(`{void Function(int)? onProgress}`) 괄호라서
       함수 «몸통»이 아니라 매개변수 목록만 읽힌다. `async {` 부터 잡는다. */
    final body = blockAt(src, src.indexOf('async {', at));
    expect(body.contains('mustSettle('), isTrue,
        reason: '「맡겼다」로 넘어가면 방 문서가 먼저 없어져 남은 기록을 못 지운다');
    expect(RegExp(r'await\s+batch\.commit\(\)\s*;').hasMatch(body), isFalse,
        reason: '날것 commit 이 돌아왔다');
  });

  test('화면 쪽에서 서버를 날것으로 부르지 않는다', () {
    final offenders = <String>[];
    for (final f
        in Directory('lib/ui').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final code = stripComments(f.readAsStringSync());
      if (RegExp(r'docRef\([^)]*\)\s*\.\s*(delete|set|update)\(')
          .hasMatch(code)) {
        offenders.add(f.path.replaceAll(r'\', '/'));
      }
    }
    expect(offenders, isEmpty,
        reason: '매듭을 안 거치면 신호가 끊겼을 때 화면이 영영 안 끝난다 — Store 를 거쳐야 한다');
  });
}
