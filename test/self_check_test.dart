import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🪞 「스스로를 재는 잣대」를 막는다.

   172회차에 이런 시험이 있었다:
     expect(Logic.unpaidMonths('u1').length, Logic.unpaidMaxBack);
   상수를 12→6 으로 바꿔도 **양쪽이 같이 바뀌어 그냥 통과**한다 — 아무것도 안 지킨다.

   그래서 두 가지를 못 박는다.
     ① `expect(A, B)` 의 두 쪽이 «글자까지 똑같으면» 안 된다.
     ② 두 쪽이 «같은 이름»을 쓰는 견줌(관계 시험)이 있으면,
        그 이름에 대해 «값을 못 박는» 견줌도 어딘가에 반드시 있어야 한다.
        (관계만 있으면 「늘 같은 값을 돌려주기」로 바꿔도 통과할 수 있다)
   173회차에 손으로 훑은 12곳은 전부 ②를 갖추고 있었다 — 이 시험은 그 상태를 지킨다. */
void main() {
  final lib = RegExp(r'\b(Logic|Store|Push|AppState|Cfg)\.(\w+)');
  const quiet = {'isTrue', 'isFalse', 'isNull', 'isNotNull', 'isEmpty', 'isNotEmpty'};

  /// `expect(` 의 «최상위» 인자들을 괄호·따옴표를 맞춰 나눈다
  List<String> argsOf(String s, int open) {
    var d = 0, i = open;
    String? q;
    final parts = <String>[];
    final cur = StringBuffer();
    while (i < s.length) {
      final c = s[i];
      if (q != null) {
        cur.write(c);
        if (c == r'\') {
          i++;
          if (i < s.length) cur.write(s[i]);
        } else if (c == q) {
          q = null;
        }
        i++;
        continue;
      }
      if (c == "'" || c == '"') { q = c; cur.write(c); i++; continue; }
      if (c == '(' || c == '[' || c == '{') {
        d++;
        if (d > 1) cur.write(c);
        i++;
        continue;
      }
      if (c == ')' || c == ']' || c == '}') {
        d--;
        if (d == 0) { parts.add(cur.toString()); return parts; }
        cur.write(c);
        i++;
        continue;
      }
      if (c == ',' && d == 1) { parts.add(cur.toString()); cur.clear(); i++; continue; }
      cur.write(c);
      i++;
    }
    return parts;
  }

  String tidy(String s) => s.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).join(' ');

  late List<({String file, String a, String b})> pairs;
  late String allTests;

  setUpAll(() {
    pairs = [];
    final buf = StringBuffer();
    for (final f in Directory('test').listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final s = f
          .readAsStringSync()
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
          .replaceAll(RegExp(r'//.*'), '');
      buf.writeln(s);
      for (final m in RegExp(r'\bexpect\s*\(').allMatches(s)) {
        final p = argsOf(s, m.end - 1);
        if (p.length < 2) continue;
        final a = tidy(p[0]), b = tidy(p[1]);
        if (a.isEmpty || b.isEmpty || b.startsWith('reason:')) continue;
        pairs.add((file: f.path.split(RegExp(r'[\/]')).last, a: a, b: b));
      }
    }
    allTests = buf.toString();
    expect(pairs.length, greaterThan(500), reason: '견줌을 못 읽었다 — 이 시험이 헛돌고 있다');
  });

  test('견주는 두 쪽이 «글자까지 똑같은» 자리가 없다', () {
    final same = pairs.where((p) => p.a == p.b).toList();
    expect(same, isEmpty,
        reason: '스스로를 재는 잣대다 — 무엇이 바뀌어도 절대 울지 않는다: '
            '${same.map((p) => '${p.file}: ${p.a}').take(5).toList()}');
  });

  test('«관계만» 재는 이름은 «값을 못 박는» 견줌도 함께 있다', () {
    final relational = <String>{};
    for (final p in pairs) {
      if (quiet.contains(p.b)) continue;
      final sa = lib.allMatches(p.a).map((m) => '${m[1]}.${m[2]}').toSet();
      final sb = lib.allMatches(p.b).map((m) => '${m[1]}.${m[2]}').toSet();
      relational.addAll(sa.intersection(sb));
    }
    final naked = <String>[];
    for (final name in relational) {
      /* 「값을 못 박는」 견줌 = 그 이름을 왼쪽에 두고 오른쪽이 «글자·숫자·없음·크기»인 것.
         하나라도 있으면, 「늘 같은 값 돌려주기」로 바꿨을 때 그쪽이 운다. */
      final pinned = pairs.any((p) {
        if (!p.a.contains(name)) return false;
        final b = p.b;
        if (b.contains(name)) return false; // 이건 관계 시험이다
        return RegExp(r"^('|\d|isNull|isEmpty|greaterThan|lessThan|isNot\()").hasMatch(b);
      });
      if (!pinned) naked.add(name);
    }
    expect(naked, isEmpty,
        reason: '이 이름들은 «관계»만 재고 «값»은 아무도 안 본다 — '
            '「늘 같은 값을 돌려주기」로 바꿔도 시험이 통과한다: $naked');
  });

  test('이 시험이 실제로 견줌을 읽고 있다', () {
    // 172회차에 실제로 있었던 꼴이 지금은 없어야 한다
    expect(allTests.contains('Logic.unpaidMonths(\'u1\').length, Logic.unpaidMaxBack'), isFalse,
        reason: '상수를 상수와 견주던 자리가 되살아났다');
  });
}
