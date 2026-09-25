import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* ⏳ 기다린(await) 뒤에 «화면이 아직 살아 있는지»를 안 보고 setState 를 부르면 —
   그 사이 뒤로 가기로 화면을 닫은 경우 오류가 난다(글자가 안 바뀌고 로그에 빨간 줄).
   2026-09-25: 가입 화면이 서버에 「총괄 아이디인가」를 묻고 난 뒤 확인 없이 안내·setState 를 썼다.
   한 줄씩 훑는 거친 그물이다 — 함수가 바뀌면 await 기억을 지우고, mounted 를 보면 지운다.
   `() => setState(` 처럼 단추에 달린 것은 그 자리에서 도는 게 아니라 뺀다. */
void main() {
  test('await 다음 setState 앞에는 mounted 확인이 있다', () {
    final bad = <String>[];
    for (final f in Directory('lib/ui').listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      int? lastAwait;
      for (var i = 0; i < lines.length; i++) {
        final s = lines[i].trim();
        if (s.startsWith('//') || s.startsWith('*') || s.startsWith('/*')) continue;
        if (RegExp(r'^\s*(Future<|void |Widget |static |@override)').hasMatch(lines[i]) &&
            s.contains('(')) {
          lastAwait = null;
        }
        if (s.contains('await ')) lastAwait = i;
        if (s.contains('mounted')) lastAwait = null;
        if (lastAwait != null &&
            RegExp(r'\bsetState\(').hasMatch(s) &&
            !RegExp(r'\(\)\s*=>\s*setState\(').hasMatch(s) &&
            i > lastAwait) {
          bad.add('${f.path}:${i + 1} (await ${lastAwait + 1}줄)');
          lastAwait = null;
        }
      }
    }
    expect(bad, isEmpty, reason: '기다린 뒤 화면이 닫혔을 수 있다 — mounted 를 먼저 본다');
  });
}
