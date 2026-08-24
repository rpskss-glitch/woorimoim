import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🧯 183회차 흔들기에서 «안 물린» 자리 셋 — 셋 다 회원 눈에 바로 보이는 것이다.
     · 「더 불러올 대화가 없어요」가 **잘 불러왔을 때도** 뜬다
     · 「↑ 이전 대화 더 보기」가 **더 볼 것이 없어도** 떠서 눌러도 헛걸음이다
     · 다시 그리기가 «없어진 화면»을 고치려다 터진다 */
void main() {
  String bare(String p) => File(p)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  test('「더 불러올 대화가 없어요」는 «정말 없을 때만» 말한다', () {
    final s = bare('lib/ui/chat.dart');
    const msg = "'더 불러올 대화가 없어요'";
    final at = s.indexOf(msg);
    expect(at, greaterThan(0), reason: '그 안내를 못 찾았다 — 이 시험이 헛돌고 있다');
    final line = s.substring(s.lastIndexOf('\n', at) + 1, at);
    expect(line, contains('if (n == 0)'),
        reason: '옛 대화를 «잘 불러왔는데도» 「없어요」라고 말한다 — 회원은 더 못 보는 줄 안다');
  });

  test('「이전 대화 더 보기」는 «더 있을 때만» 보인다', () {
    final s = bare('lib/ui/chat.dart');
    const label = "'↑ 이전 대화 더 보기'";
    final at = s.indexOf(label);
    expect(at, greaterThan(0), reason: '그 단추를 못 찾았다 — 이 시험이 헛돌고 있다');
    // 그 단추를 그리기 «전»에 더 있는지 물어봐야 한다
    final guard = s.lastIndexOf('hasOlder()', at);
    expect(guard, greaterThan(0),
        reason: '더 볼 것이 있는지 안 물어본다 — 단추가 늘 떠 있고 눌러도 헛걸음이다');
    expect(s.substring(guard, at), isNot(contains('itemBuilder')),
        reason: '물어보는 자리가 그 단추와 «다른 줄»에 있다');
  });

  test('다시 그리기는 «아직 화면이 있는지» 보고 그린다 (여섯 곳 모두)', () {
    /* 이 함수는 «오래 걸리는 일이 끝난 뒤» 자식 화면이 불러 준다 —
       그 사이 모임에서 빠지거나 방이 없어졌을 수 있다.
       ⚠️ 분석기는 `BuildContext` 만 보고 `setState` 는 안 본다(182·183회차). */
    final bad = <String>[];
    var n = 0;
    for (final f in Directory('lib/ui').listSync().whereType<File>()) {
      final p = f.path.replaceAll(r'\', '/');
      if (!p.endsWith('.dart')) continue;
      final s = bare(p);
      final at = s.indexOf('void _r()');
      if (at < 0) continue;
      n++;
      /* ⚠️ 두 가지 꼴이 있다 — `void _r() => …;` 와 `void _r() { … }`.
         한 줄짜리인데 «다음 함수의 닫는 괄호»까지 창을 잡으면 아래 코드에 든 `mounted` 를 보고
         그냥 통과한다(183회차에 그렇게 틀렸다). **첫 세미콜론까지**만 본다. */
      final semi = s.indexOf(';', at);
      final brace = s.indexOf('\n  }', at);
      final end = (brace < 0 || (semi > 0 && semi < brace)) ? semi : brace;
      final body = s.substring(at, end < 0 ? at + 60 : end);
      if (!body.contains('mounted')) bad.add(p);
    }
    expect(n, greaterThanOrEqualTo(6), reason: '다시 그리기를 못 찾았다 — 이 시험이 헛돌고 있다');
    expect(bad, isEmpty,
        reason: '없어진 화면을 고치려다 터진다 — '
            '사진·기록을 지운 «뒤»에 불리는 자리라 실제로 그럴 수 있다: $bad');
  });
}
