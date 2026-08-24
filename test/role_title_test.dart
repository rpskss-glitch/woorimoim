// 권한(role)과 직책(title)의 «경계».
//
// 서버 규칙 canHandleMoney 는 role «또는» title 만 맞아도 회비 장부를 열어 준다.
// 그래서 「운영진 해제」만 하면 그 사람은 **회비를 계속 쓸 수 있는데 방장은 뗐다고 믿는다.**
// 79회차에 이 어긋남을 찾았다 — 올릴 때는 짝을 맞추면서(직책→권한) 내릴 때는 안 맞췄다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/config.dart';
import 'package:woorimoim/logic.dart';

const _rules = r'C:\Users\asas3\Desktop\데이트장부\firestore.rules';

void main() {
  test('돈을 다루는 직책이면 권한을 내려도 그대로다', () {
    for (final t in treasurerTitles) {
      expect(Logic.keepsMoneyByTitle(t), isTrue, reason: t);
    }
    for (final t in ['회장', '부회장', '경기이사', '섭외이사', '감사', '고문', '주장', '']) {
      expect(Logic.keepsMoneyByTitle(t), isFalse, reason: '$t 는 직책만으로 돈을 다루지 않는다');
    }
    expect(Logic.keepsMoneyByTitle(null), isFalse);
  });

  test('권한을 내릴 때 «남는 직책»을 알려주고 뗄 기회를 준다', () {
    final src = File('lib/ui/members.dart').readAsStringSync();
    final at = src.indexOf('Future<void> _setRole(');
    expect(at, greaterThan(0));
    final body = src.substring(at, src.indexOf('\n  }\n', at));
    expect(body.contains('keepsMoneyByTitle'), isTrue,
        reason: '권한만 내리고 끝내면 회비 장부가 열린 채로 남는다');
    expect(body.contains("'members.\$uid.title': null"), isTrue,
        reason: '직책도 뗄 수 있어야 한다');
    expect(body.contains('회비'), isTrue, reason: '무엇이 남는지 방장에게 말해야 한다');
  });

  test('올릴 때도 짝이 그대로 있다 (직책 → 권한)', () {
    final src = File('lib/ui/members.dart').readAsStringSync();
    expect(src.contains('adminTitles.contains(picked)'), isTrue);
    expect(src.contains("'members.\$uid.role': 'admin'"), isTrue);
  });

  /* 앱이 아는 「돈 직책」과 서버 규칙이 아는 것이 어긋나면,
     앱에서는 총무인데 서버가 거절하거나(눌러도 안 되는 단추) 그 반대가 된다. */
  test('앱의 돈 직책 목록이 서버 규칙과 같다', () {
    final f = File(_rules);
    if (!f.existsSync()) {
      markTestSkipped('서버 규칙 파일이 없다: $_rules');
      return;
    }
    final rules = f.readAsStringSync();
    final m = RegExp(r"get\('title', ''\) in \[(.*?)\]", dotAll: true).firstMatch(rules);
    expect(m, isNotNull, reason: '규칙에서 돈 직책 목록을 못 찾았다');
    final server = RegExp("'([^']+)'")
        .allMatches(m!.group(1)!)
        .map((x) => x.group(1)!)
        .toList();
    expect(server, treasurerTitles,
        reason: '앱(config.dart)과 서버(firestore.rules)가 다르게 안다');
  });

  /* 방장이 「운영진 해제」로 뗄 수 있어야 하는데 서버가 role 만 보고 열어 주는 자리도
     같이 잠가 둔다 — 규칙이 바뀌어 title 을 안 보게 되면 위 흐름은 헛수고가 된다. */
  test('서버 규칙이 role 과 title 을 «둘 다» 본다', () {
    final f = File(_rules);
    if (!f.existsSync()) {
      markTestSkipped('서버 규칙 파일이 없다');
      return;
    }
    final rules = f.readAsStringSync();
    final at = rules.indexOf('function canHandleMoney');
    expect(at, greaterThan(0));
    final body = rules.substring(at, at + 400);
    expect(body.contains("m.role == 'admin'"), isTrue);
    expect(body.contains("get('title', '')"), isTrue);
  });
}
