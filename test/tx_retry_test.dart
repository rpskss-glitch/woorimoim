// 트랜잭션 덩어리는 부딪히면 «처음부터 다시 돈다».
//
// 그 안에서 «밖에 둔 값»에 담아 두면, 다시 돌 때 앞 시도의 결과가 남는다.
//   · store.dart 의 `wrote` → 아무것도 안 썼는데 **「됐다」고 돌려준다.**
//   · onboarding 의 `old`  → 다른 기기가 먼저 이어받았는데 **「이어받았어요」**라고 알리고
//                            그대로 들여보내, 회원은 영문도 모른 채 승인 대기 화면에 놓인다.
// admin.dart 는 이 함정을 알고 맨 위에서 되돌리고 있었다 — 나머지가 안 하고 있었다 (86회차).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _heads = ['runTransaction(', 'mutateCouple(', 'mutateItem('];

String _noComments(String s) {
  final noBlock = s.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return noBlock.split(String.fromCharCode(10)).map((l) => l.split('//').first).join(String.fromCharCode(10));
}

/// `head` 로 시작하는 호출들의 «콜백 몸통»을 괄호를 세어 잘라낸다.
List<(int, String)> _bodies(String src, String head) {
  final out = <(int, String)>[];
  var i = 0;
  while (true) {
    i = src.indexOf(head, i);
    if (i < 0) break;
    final o = src.indexOf('{', i);
    if (o < 0) break;
    var d = 0;
    for (var k = o; k < src.length; k++) {
      if (src[k] == '{') d++;
      if (src[k] == '}') {
        d--;
        if (d == 0) {
          out.add((i, src.substring(o + 1, k)));
          break;
        }
      }
    }
    i = o + 1;
  }
  return out;
}

/// 그 소스에서 «다시 돌 때 앞 시도의 값이 남는» 자리를 찾는다.
List<String> retryTainted(String src, String name) {
  final reset = RegExp(r'^(\w+)\s*=\s*(null|false|0)\s*;');
  final bad = <String>[];
  for (final head in _heads) {
    for (final (at, raw) in _bodies(src, head)) {
      final body = _noComments(raw);
      final inner = RegExp(r'\b(?:final|var)\s+(\w+)')
          .allMatches(body)
          .map((m) => m.group(1)!)
          .toSet();
      final assigns = RegExp(r'^\s*(\w+)\s*=\s*', multiLine: true)
          .allMatches(body)
          .map((m) => m.group(1)!)
          .toSet();
      final outer = assigns.where((a) => !inner.contains(a)).toList();
      if (outer.isEmpty) continue;
      // 맨 위에서 «되돌리는» 줄만 인정한다 — 조건·읽기가 한 번이라도 나오면 거기서 끝
      final done = <String>{};
      for (final t in body
          .split(String.fromCharCode(10))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)) {
        final m = reset.firstMatch(t);
        if (m == null) break;
        done.add(m.group(1)!);
      }
      final miss = outer.where((a) => !done.contains(a)).toList();
      if (miss.isEmpty) continue;
      final line = String.fromCharCode(10).allMatches(src.substring(0, at)).length + 1;
      bad.add('$name:$line  $head  «${miss.join(', ')}»');
    }
  }
  return bad;
}

void main() {
  test('트랜잭션 콜백은 «밖의 값»을 맨 위에서 되돌린다', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      bad.addAll(retryTainted(
          f.readAsStringSync(), f.path.split(RegExp(r'[\/]')).last));
    }
    expect(bad, isEmpty,
        reason: '다시 돌 때 앞 시도의 값이 남아 «안 됐는데 됐다»고 말한다:\n  ${bad.join('\n  ')}');
  });
  test('기기 이어받기는 «트랜잭션이 돌려준 값»을 믿는다', () {
    final src = File('lib/ui/onboarding.dart').readAsStringSync();
    final at = src.indexOf('Store.i.mutateCouple(');
    expect(at, greaterThan(0));
    expect(src.substring((at - 120).clamp(0, at), at).contains('= await'), isTrue,
        reason: '돌려준 값을 안 받으면 밖에 담아둔 값만 믿게 된다');
    expect(src.contains('if (!took || old == null)'), isTrue,
        reason: '「썼는지」는 트랜잭션이 돌려준 값이 사실이다');
  });

  test('검사기 자신이 헛돌지 않는다', () {
    const ok = '''
      Future<bool> f() async {
        var wrote = false;
        await db.runTransaction((tx) async {
          wrote = false;
          final s = await tx.get(r);
          if (!s.exists) return;
          wrote = true;
        });
        return wrote;
      }''';
    const no = '''
      Future<bool> f() async {
        var wrote = false;
        await db.runTransaction((tx) async {
          final s = await tx.get(r);
          if (!s.exists) return;
          wrote = true;
        });
        return wrote;
      }''';
    expect(retryTainted(ok, 'ok.dart'), isEmpty);
    expect(retryTainted(no, 'no.dart').length, 1);
    expect(retryTainted(no, 'no.dart').first, contains('wrote'));
  });
}
