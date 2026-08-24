// 목록 안의 «상태 가진» 위젯은 자리가 아니라 «누구»로 짝지어야 한다 (129회차).
//
// 출석 칩은 「도는 중」 표시를 스스로 들고 있다. 키가 없으면 플러터가 «자리»로 짝지으므로,
// 누르는 동안 회원 목록이 바뀌면(가입 승인·권한 바꿈·탈퇴로 차례가 달라진다)
// 그 표시가 **엉뚱한 사람에게 옮겨 붙어 그 사람 칩이 잠긴다.**
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// 출석 칩과 같은 모양 — 스스로 「눌린 표시」를 든다.
class _Chip extends StatefulWidget {
  final String name;
  const _Chip(this.name, {super.key});
  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool busy = false;
  @override
  Widget build(BuildContext c) => GestureDetector(
        onTap: () => setState(() => busy = true),
        child: Text('${widget.name}${busy ? "(도는 중)" : ""}',
            textDirection: TextDirection.ltr),
      );
}

Widget row(List<String> names, {required bool keyed}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          for (final n in names) _Chip(n, key: keyed ? ValueKey(n) : null),
        ],
      ),
    );

void main() {
  testWidgets('키가 없으면 「도는 중」이 엉뚱한 사람에게 옮겨 붙는다 (재현)', (t) async {
    await t.pumpWidget(row(['갑', '을'], keyed: false));
    await t.tap(find.text('갑'));
    await t.pump();
    expect(find.text('갑(도는 중)'), findsOneWidget);

    // 그 사이 회원 목록의 차례가 바뀐다
    await t.pumpWidget(row(['을', '갑'], keyed: false));
    expect(find.text('을(도는 중)'), findsOneWidget,
        reason: '누르지도 않은 «을»이 도는 것으로 보인다 — 이게 고치려는 버그');
    expect(find.text('갑'), findsOneWidget);
  });

  testWidgets('키가 있으면 «누른 사람»에게 그대로 남는다', (t) async {
    await t.pumpWidget(row(['갑', '을'], keyed: true));
    await t.tap(find.text('갑'));
    await t.pump();
    expect(find.text('갑(도는 중)'), findsOneWidget);

    await t.pumpWidget(row(['을', '갑'], keyed: true));
    expect(find.text('갑(도는 중)'), findsOneWidget);
    expect(find.text('을'), findsOneWidget);
  });

  test('목록 안에서 «상태 가진» 위젯을 만들 때는 키를 붙인다', () {
    // 상태를 가진 위젯 이름을 먼저 모은다
    final stateful = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      stateful.addAll(RegExp(r'class\s+(\w+)\s+extends\s+StatefulWidget')
          .allMatches(f.readAsStringSync())
          .map((m) => m.group(1)!));
    }
    expect(stateful, isNotEmpty);

    final bad = <String>[];
    for (final f in Directory('lib/ui').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = stripComments(f.readAsStringSync()).split(String.fromCharCode(10));
      for (var i = 0; i < lines.length; i++) {
        if (!RegExp(r'for \(final \w+ in ').hasMatch(lines[i])) continue;
        /* 「그 for 문이 만드는 것」만 본다 — 여덟 줄이면 한 위젯을 여는 데 넉넉하고,
           다음 for 문까지 넘어가지 않는다. */
        final chunk = lines.sublist(i, (i + 8).clamp(0, lines.length)).join(' ');
        for (final w in stateful) {
          final at = chunk.indexOf('$w(');
          if (at < 0) continue;
          if (!chunk.substring(at).contains('key:')) {
            bad.add('${f.path.replaceAll(r'\', '/')}:${i + 1} $w');
          }
        }
      }
    }
    expect(bad, isEmpty,
        reason: '자리로 짝지어져 «남의 상태»가 옮겨 붙는다: ${bad.join(', ')}');
  });
}
