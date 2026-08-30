// 검사기 자신이 «헛돌지» 않는지 (101회차).
//
// 이 루프에서 소스 모양을 보는 시험이 «주석»에 걸려 헛통과한 일이 네 번 있었다
// (85·94·97·99회차). 사람이 매번 알아채기는 어려우니 기계로 막는다.
//
// 규칙: `File('경로')` 로 읽은 뒤 `.contains('글자')` 로 확인하는데
//       그 «글자»가 그 파일의 **주석에만** 있으면 그 시험은 코드가 아니라 설명을 보고 있다.
// 일부러 주석을 확인하는 시험은 같은 줄에 `// 주석이어도 된다` 를 붙인다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _skip = '주석이어도 된다';

/// `.contains('글자')` 를 찾는 그물 — 원시 문자열 안에서 따옴표를 escape 할 수 없어 삼중따옴표로 쓴다
final _callRe = RegExp(r"""\.contains\(('|")(.+?)\1\)""");

/// 주석을 걷어낸 «살아 있는» 글
String live(String path, String body) {
  if (path.endsWith('.dart')) {
    final noBlock = body.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
    return noBlock.split('\n').map((l) => l.split('//').first).join('\n');
  }
  if (path.endsWith('.yaml') || path.endsWith('.yml')) {
    return body.split('\n').where((l) => !l.trimLeft().startsWith('#')).join('\n');
  }
  return body; // .md·.plist 등은 주석 개념이 없다
}

void main() {
  test('소스 모양을 보는 시험이 «주석»을 보고 있지 않다', () {
    final bad = <String>[];
    for (final f in Directory('test').listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('checker_audit_test.dart')) continue; // 이 파일은 자기 얘기를 한다
      final src = f.readAsStringSync();
      final name = f.path.split(RegExp(r'[\/]')).last;

      /* 이 시험 파일이 «읽는 파일»들 — 자리(offset)와 함께.
         ⚠️ 짝짓기가 «시험 경계»를 넘으면 안 된다. 앞 시험이 읽은 파일을 뒤 시험의 확인에
            갖다 붙이면 엉뚱한 곳을 보고 「주석에만 있다」고 우긴다 (실제로 그랬다). */
      final reads = RegExp(r"File\('([^']+)'\)").allMatches(src).toList();
      if (reads.isEmpty) continue;
      final bounds = RegExp(r"^\s*(test|testWidgets)\(", multiLine: true)
          .allMatches(src)
          .map((t) => t.start)
          .toList();
      int blockOf(int at) {
        var i = 0;
        for (final b in bounds) {
          if (b > at) break;
          i = b;
        }
        return i;
      }

      for (final m in _callRe.allMatches(src)) {
        final needle = m.group(2)!;
        if (needle.length < 4 || needle.contains(r'$')) continue;
        // 같은 줄에 면제 표시가 있으면 넘어간다
        final lineStart = src.lastIndexOf('\n', m.start) + 1;
        var lineEnd = src.indexOf('\n', m.end);
        if (lineEnd < 0) lineEnd = src.length;
        if (src.substring(lineStart, lineEnd).contains(_skip)) continue;

        /* ⚠️ 「**없어야 한다**」를 보는 확인(isFalse)은 여기서 봐준다.
           그런 시험은 «주석에만 남은 낱말»을 찾는 것이 오히려 맞다 —
           예: 「총괄 비밀번호가 앱에 글자로 남아 있지 않다」는
           lib/config.dart 의 «예전에는 adminPass 가 있었다» 설명을 지나가야 한다.
           이걸 안 봐주면 **옳은 시험이 잡혀** 사람이 시험을 지우게 된다(실제로 그랬다). */
        final tail = src.substring(m.end, (m.end + 60).clamp(0, src.length));
        if (tail.contains('isFalse')) continue;

        // 바로 «앞»에서 읽은 파일이 그 확인의 대상이다 — 단 «같은 시험 안»이어야 한다
        final block = blockOf(m.start);
        final before = reads.where((r) => r.start < m.start && r.start >= block);
        if (before.isEmpty) continue; // 어느 파일을 보는지 알 수 없으면 넘어간다
        final target = before.last.group(1)!;
        final tf = File(target);
        if (!tf.existsSync()) continue;
        final body = tf.readAsStringSync();
        if (!body.contains(needle)) continue; // 아예 없으면 그 시험이 알아서 실패한다
        if (live(target, body).contains(needle)) continue; // 코드에 있다 — 괜찮다

        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        bad.add('$name:$line  «$needle» 는 $target 의 «주석»에만 있다');
      }
    }
    expect(bad, isEmpty,
        reason: '설명을 보고 통과하는 시험이다 — 코드가 사라져도 안 잡힌다:\n  ${bad.join('\n  ')}');
  });

  test('검사기 자신이 헛돌지 않는다', () {
    // 좋은 모양: 코드에 있는 글자 / 나쁜 모양: 주석에만 있는 글자
    const code = "final x = 1; // 여기에만 있는말\nfinal y = '진짜코드';";
    expect(live('a.dart', code).contains('진짜코드'), isTrue);
    expect(live('a.dart', code).contains('여기에만 있는말'), isFalse);
    const yaml = '# - 꺼진규칙\n    - 켜진규칙\n';
    expect(live('a.yaml', yaml).contains('켜진규칙'), isTrue);
    expect(live('a.yaml', yaml).contains('꺼진규칙'), isFalse);
  });
}
