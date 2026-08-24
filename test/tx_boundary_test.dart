import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 트랜잭션 경계 — 「없는 문서에 쓰면 없던 것이 생긴다」.
   총괄이 방을 지운 «그 순간» 회원이 「내가 방장 맡기」를 누르거나
   총괄이 「방장 자리 열기」를 누르면, `mutateCouple` 이 없는 문서에 그대로 써서
   **지운 방이 되살아났다.** 되살아난 방은 총괄 목록(META)에 없어 콘솔에 안 보이고,
   그래서 다시 지울 수도 없다 — 텅 빈 방이 영영 남는다.
   `mutateItem` 은 처음부터 `!s.exists` 면 안 썼다. `mutateCouple` 만 빠져 있었다. */

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// [from] 뒤 첫 `async {` 부터 짝이 맞는 `}` 까지.
/// (함수 «이름» 뒤에서 짝을 맞추면 이름 있는 매개변수 괄호가 잡힌다 — 120회차 함정)
String bodyOf(String src, String name) {
  final at = src.indexOf(name);
  if (at < 0) return '';
  final open = src.indexOf('async {', at);
  if (open < 0) return '';
  var d = 0;
  for (var i = src.indexOf('{', open); i < src.length; i++) {
    if (src[i] == '{') d++;
    if (src[i] == '}') {
      d--;
      if (d == 0) return src.substring(open, i + 1);
    }
  }
  return src.substring(open);
}

void main() {
  final store = stripComments(File('lib/store.dart').readAsStringSync());

  test('모임 문서를 고칠 때 «없으면» 새로 만들지 않는다', () {
    final body = bodyOf(store, 'Future<bool> mutateCouple(');
    expect(body.contains('!s.exists'), isTrue,
        reason: '없는 문서에 쓰면 지운 방이 되살아난다');
    expect(body.contains('createIfMissing'), isTrue,
        reason: '만들어도 되는 자리는 따로 켜서 쓴다');
  });

  test('기록을 고칠 때도 «없으면» 만들지 않는다 (원래 그랬다 — 지키기)', () {
    expect(bodyOf(store, 'Future<bool> mutateItem(').contains('!s.exists'), isTrue);
  });

  test('«만들어도 되는» 자리는 총괄 등록 문서 하나뿐이다', () {
    final where = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final code = stripComments(f.readAsStringSync());
      if (code.contains('createIfMissing: true')) {
        where.add(f.path.replaceAll(r'\', '/'));
      }
    }
    expect(where, ['lib/ui/admin.dart'],
        reason: '모임 방에 켜면 지운 방이 되살아난다 — META(총괄 등록)만 허용');
    // 그 한 곳도 «META 문서»에 대고 쓰는 것이라야 한다
    final admin = stripComments(File('lib/ui/admin.dart').readAsStringSync());
    expect(
        RegExp(r'mutateCouple\(\s*_metaDoc\s*,\s*createIfMissing:\s*true')
            .hasMatch(admin),
        isTrue,
        reason: 'META 아닌 곳에 켜져 있다');
  });

  test('트랜잭션 콜백은 «맨 위에서» 밖에 둔 표시를 되돌린다', () {
    /* 부딪히면 콜백이 처음부터 다시 돈다 — 안 되돌리면 앞선 시도의 결과가 남아
       «아무것도 안 썼는데 됐다»고 돌려준다(86회차). 콜백을 쓰는 곳 전부에 해당한다. */
    for (final name in ['Future<bool> mutateCouple(', 'Future<bool> mutateItem(']) {
      final body = bodyOf(store, name);
      final tx = body.indexOf('runTransaction');
      final reset = body.indexOf('wrote = false', tx);
      final read = body.indexOf('tx.get(', tx);
      expect(reset, greaterThan(0), reason: '$name: 되돌리는 줄이 없다');
      expect(reset, lessThan(read), reason: '$name: 읽기보다 «먼저» 되돌려야 한다');
    }
  });

  test('트랜잭션은 읽기를 «먼저», 쓰기를 나중에 한다', () {
    // Firestore 는 쓰기 뒤의 읽기를 금지한다 — 순서가 뒤집히면 통째로 실패한다
    for (final name in ['Future<bool> mutateCouple(', 'Future<bool> mutateItem(']) {
      final body = bodyOf(store, name);
      expect(body.indexOf('tx.get('), lessThan(body.indexOf('tx.set(')),
          reason: '$name: 읽기가 쓰기보다 뒤에 있다');
    }
  });
}
