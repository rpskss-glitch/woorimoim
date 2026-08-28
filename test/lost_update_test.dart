import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 「내가 안 고친 칸」을 같이 써 보내면 남이 방금 바꾼 것이 되돌아간다.
   setCouple 은 set(merge:true) 라 **안 보낸 칸은 그대로 남는다** — 그러니
   화면이 고친 것만 보내면 된다. 화면이 들고 있는 «전에 본» 사본에서 값을
   퍼다 같이 보내는 순간, 그 사이 남이 바꾼 값이 옛 값으로 덮인다.
   (설정 > 월 회비가 「내는 날」을 같이 보내고 있었다. 이 앱엔 「내는 날」 칸이
    아예 없어서, 웹앱(아이폰 회원)에서 정해 둔 날짜를 조용히 지웠다.) */

/// Firestore set(merge:true) 흉내 — 안쪽 묶음끼리 «합친다»(갈아끼우지 않는다).
Map<String, dynamic> mergeSet(
    Map<String, dynamic> doc, Map<String, dynamic> data) {
  final out = Map<String, dynamic>.from(doc);
  data.forEach((k, v) {
    final cur = out[k];
    out[k] = (v is Map && cur is Map)
        ? mergeSet(Map<String, dynamic>.from(cur), Map<String, dynamic>.from(v))
        : v;
  });
  return out;
}

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// `name(` 뒤의 괄호를 짝 맞춰 «호출 안 내용»만 떼어낸다.
List<String> callBodies(String code, String name) {
  final out = <String>[];
  var at = 0;
  while (true) {
    final i = code.indexOf(name, at);
    if (i < 0) return out;
    var d = 0;
    var j = i + name.length - 1; // '(' 자리
    for (; j < code.length; j++) {
      if (code[j] == '(') d++;
      if (code[j] == ')') {
        d--;
        if (d == 0) break;
      }
    }
    final end = j.clamp(i, code.length);
    out.add(code.substring(i, end));
    at = end + 1;
  }
}

void main() {
  test('merge 흉내가 맞는지 먼저 — 안 보낸 칸은 남는다', () {
    final after = mergeSet({
      'fee': {'amount': 20000, 'day': 5}
    }, {
      'fee': {'amount': 30000}
    });
    expect(after['fee'], {'amount': 30000, 'day': 5});
  });

  test('안 고친 칸을 같이 보내면 남이 방금 바꾼 값이 되돌아간다 (재현)', () {
    // 서버: 아이폰 운영진이 웹에서 「매달 5일까지」로 방금 바꿔 놓았다
    final server = {
      'fee': {'amount': 20000, 'day': 5}
    };
    // 내 화면: 그 전에 열어 둔 것이라 날짜가 아직 0이다
    const staleDay = 0;

    final oldWay = mergeSet(server, {
      'fee': {'amount': 30000, 'day': staleDay}
    });
    expect((oldWay['fee'] as Map)['day'], 0,
        reason: '「내는 날」이 되돌아간다 — 이게 고치려는 버그');

    final newWay = mergeSet(server, {
      'fee': {'amount': 30000}
    });
    expect((newWay['fee'] as Map)['day'], 5, reason: '금액만 보내면 날짜는 그대로');
    expect((newWay['fee'] as Map)['amount'], 30000);
  });

  test('회비 저장은 금액만 보낸다', () {
    final code = stripComments(File('lib/ui/settings.dart').readAsStringSync());
    final fee = callBodies(code, 'setCouple(')
        .where((b) => b.contains("'fee'"))
        .toList();
    /* 203회차: 「회비 보내는 곳(계좌)」이 생겨 회비를 저장하는 자리가 둘이 됐다.
       지켜야 하는 것은 그대로 — **저마다 자기 칸만** 보낸다.
       set(merge:true) 가 안쪽 묶음을 합쳐 주므로, 안 고친 칸을 같이 보내면
       남이 방금 바꾼 값을 조용히 되돌린다(예전에 「내는 날」이 실제로 그렇게 지워졌다). */
    expect(fee, hasLength(2), reason: '회비를 저장하는 곳이 늘거나 줄었다 — 무엇을 보내는지 확인해라');
    for (final b in fee) {
      expect(b.contains("'day'"), isFalse,
          reason: '고치지도 않은 「내는 날」을 같이 보내면 웹에서 정한 날짜를 지운다');
    }
    final amountOnly = fee.where((b) => b.contains("'amount'")).toList();
    final accountOnly = fee.where((b) => b.contains("'account'")).toList();
    expect(amountOnly, hasLength(1), reason: '금액을 저장하는 곳은 하나여야 한다');
    expect(accountOnly, hasLength(1), reason: '계좌를 저장하는 곳은 하나여야 한다');
    expect(amountOnly.single.contains("'account'"), isFalse,
        reason: '금액만 고치는 자리가 계좌까지 덮어쓴다');
    expect(accountOnly.single.contains("'amount'"), isFalse,
        reason: '계좌만 고치는 자리가 금액까지 덮어쓴다');
  });

  test('저장할 값을 «화면이 들고 있는 사본»에서 퍼오지 않는다', () {
    final offenders = <String>[];
    for (final f
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      final code = stripComments(f.readAsStringSync());
      for (final body in callBodies(code, 'setCouple(')) {
        if (RegExp(r'(st|AppState\.i)\??\.couple').hasMatch(body)) {
          offenders.add(rel);
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '보낼 값은 «지금 화면이 고친 것»이라야 한다 — '
            '사본에서 퍼오면 그 사이 남이 바꾼 값을 옛 값으로 덮는다');
  });
}
