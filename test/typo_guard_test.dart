import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* ✍️ 회원 눈에 보이는 글자에 «한 번 잡은 오타»가 다시 들어오지 않게.

   2026-09-25 조사: 인터넷이 안 될 때 뜨는 화면에 「잠깐 끉겼을 수 있어요」
   (끊겼을 → 끉겼을)가 있었다. 앱이 막 켜질 때 서버에 못 닿으면 누구나 보는 화면이다.
   잡은 오타를 여기 적어 두면 다음부터는 기계가 막는다. */
const _typos = {
  '끉': '끊',
};

void main() {
  test('lib 에 알려진 오타가 없다', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final e in _typos.entries) {
          if (lines[i].contains(e.key)) {
            bad.add('${f.path}:${i + 1}  「${e.key}」→「${e.value}」');
          }
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
