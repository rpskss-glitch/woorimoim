import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 이 코드밑천은 «왜 그렇게 했는지»를 주석에 적어 두고 산다 —
   다음에 고치는 사람이 그 경고를 보고 멈추도록.
   그런데 새 함수를 «설명문과 그 함수 사이»에 끼워 넣으면 경고가 엉뚱한 함수에 붙는다.
   123회차에 실제로 그랬다: 「운영진 해제해도 직책 때문에 회비는 그대로 열린다」는
   돈 권한 경고가 `keepsMoneyByTitle` 에서 떨어져 나가, 그 함수는 한 줄짜리 민짜가 됐다.
   → 안전 경고와 그 함수의 «짝»을 여기에 못 박아 둔다. */

/// [decl] 바로 위에 «붙어 있는» 주석 덩어리 (빈 줄이나 코드를 만나면 멈춘다).
///
/// ⚠️ 「//·///·*로 시작하나」만 보면 안 된다 — 덩어리 주석(/* … */)의 «가운뎃줄»은
///    아무 글자로나 시작해서, 거기서 멈추면 정작 경고가 든 첫 줄을 못 읽는다.
///    끝줄(*/)을 만나면 시작줄(/*)까지 통째로 삼킨다.
String commentAbove(String src, String decl) {
  final lines = src.split(String.fromCharCode(10));
  final at = lines.indexWhere((l) => l.contains(decl));
  if (at < 0) return '';
  final out = <String>[];
  var i = at - 1;
  while (i >= 0) {
    final t = lines[i].trim();
    if (t.isEmpty) break;
    if (t.endsWith('*/')) {
      // 덩어리 주석 — 시작줄까지 거슬러 올라가 통째로 담는다
      while (i >= 0) {
        out.add(lines[i].trim());
        if (lines[i].trimLeft().startsWith('/*')) break;
        i--;
      }
      i--;
      continue;
    }
    if (t.startsWith('///') || t.startsWith('//')) {
      out.add(t);
      i--;
      continue;
    }
    break;
  }
  return out.reversed.join(String.fromCharCode(10));
}

void main() {
  // (파일, 함수, 그 함수의 주석에 «반드시» 있어야 할 말)
  const pinned = <(String, String, String)>[
    // 돈 권한 — 운영진을 내려도 직책 때문에 회비가 열린다는 경고
    ('lib/logic.dart', 'static bool keepsMoneyByTitle(', 'canHandleMoney'),
    // 죽은 단추 — 서버 규칙과 같은 뜻이라야 한다는 경고 (121회차)
    ('lib/logic.dart', 'static bool canClaimOwner(', 'notSelfPromotingToOwner'),
    // 「맡겼다」로 넘어가면 안 되는 자리 (120회차)
    ('lib/store.dart', 'static Future<void> mustSettle(', '맡겼다'),
    // 회원 칸을 통째로 쓰면 남의 갱신을 지운다 (117회차)
    ('lib/store.dart', 'static Map<String, dynamic> memberPatch(', '통째로'),
    // 인용 띠는 글씨의 반대쪽 (122회차)
    ('lib/theme.dart', 'Color quoteTintFor(', '반대쪽'),
  ];

  for (final (file, decl, must) in pinned) {
    test('$file 의 $decl 위에 그 경고가 붙어 있다', () {
      final src = File(file).readAsStringSync();
      expect(src.contains(decl), isTrue, reason: '함수를 못 찾았다 — 이름이 바뀌었나?');
      expect(commentAbove(src, decl).contains(must), isTrue,
          reason: '「$must」 경고가 이 함수에서 떨어져 나갔다 — '
              '사이에 다른 것을 끼워 넣으면 경고가 엉뚱한 함수에 붙는다');
    });
  }

  test('돈 권한 경고는 «다른» 함수에 붙어 있지 않다', () {
    /* 123회차의 실제 모습: 경고가 `canClaimOwner` 위로 옮겨 붙어 있었다. */
    final src = File('lib/logic.dart').readAsStringSync();
    expect(
        commentAbove(src, 'static bool canClaimOwner(')
            .contains('canHandleMoney'), // 주석이어도 된다
        isFalse,
        reason: '돈 권한 경고가 엉뚱한 함수에 붙었다');
  });
}
