import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 📸 「사진 여러 장 올리기」는 오래 걸리는 일이다.

   한 장마다 작은 그림을 만들고(실측 ~370㎳) 보관함에 올린다. 30장이면 값싼 폰에서 1분이 넘는다.
   그런데 처음 띄운 「…장 올리는 중」 토스트는 몇 초 뒤 사라진다 →
   회원은 끝난 줄 알고 **단추를 다시 누른다** → 같은 사진이 **두 번** 올라간다
   (사진첩에도 두 장, 보관 요금도 두 배).
   그래서 ① 올리는 동안 단추를 못 누르게 하고 ② 몇 장째인지 단추에 계속 보여 준다. */
void main() {
  String bare(String p) => File(p)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  String bodyOf(String src, String decl) {
    final at = src.indexOf(decl);
    if (at < 0) return '';
    var i = src.indexOf('(', at), d = 0;
    for (; i < src.length; i++) {
      if (src[i] == '(') d++;
      if (src[i] == ')') { d--; if (d == 0) break; }
    }
    final open = src.indexOf('{', i);
    d = 0;
    for (var j = open; j < src.length; j++) {
      if (src[j] == '{') d++;
      if (src[j] == '}') { d--; if (d == 0) return src.substring(open, j + 1); }
    }
    return '';
  }

  late String src;
  late String body;
  setUpAll(() {
    src = bare('lib/ui/board.dart');
    body = bodyOf(src, 'Future<void> _addPhotos(');
    expect(body, isNotEmpty, reason: '사진 올리기를 못 찾았다 — 이 시험이 헛돌고 있다');
  });

  test('올리는 중에는 «다시 들어오지» 못한다', () {
    expect(body, contains('if (_upBusy) return;'),
        reason: '올리는 중에 또 부르면 같은 사진이 두 번 올라간다');
    // 막이는 사진을 고르기 «전»에 있어야 한다
    expect(body.indexOf('_upBusy'), lessThan(body.indexOf('pickMultiImage')),
        reason: '막이가 사진 고르기보다 뒤에 있다');
  });

  test('올리는 중에는 «단추가 안 눌린다»', () {
    final fab = bodyOf(src, 'Widget build(');
    expect(fab, contains('onPressed: _upBusy'),
        reason: '단추가 그대로 눌린다 — 회원은 끝난 줄 알고 다시 누른다');
    expect(fab, contains('_upDone'), reason: '몇 장째인지 안 보여 준다');
    expect(fab, contains('_upTotal'), reason: '몇 장 가운데인지 안 보여 준다');
  });

  /// `finally { … }` 덩어리들을 괄호를 맞춰 떼어낸다
  List<String> finallyBlocks(String src) {
    final out = <String>[];
    for (final m in RegExp(r'finally\s*\{').allMatches(src)) {
      var d = 0, i = m.end - 1;
      for (; i < src.length; i++) {
        if (src[i] == '{') d++;
        if (src[i] == '}') { d--; if (d == 0) break; }
      }
      out.add(src.substring(m.end, i));
    }
    return out;
  }

  test('어느 길로 끝나든 «단추는 되살아난다»', () {
    /* 도중에 하나가 터졌을 때 표시를 안 되돌리면 그 뒤로 **다시는 못 올린다.**
       (`flushDeletes` 가 같은 갈래로 한 번 당한 자리다)
       ⚠️ 「`finally` 라는 낱말이 있나」로 보면 안 된다 — 이 함수에는 «안쪽 finally»도 있어서
          바깥 것을 빼도 그냥 통과했다. **덩어리 안에 들어 있는지**를 봐야 한다. */
    final blocks = finallyBlocks(body);
    expect(blocks.any((b) => b.contains('_upBusy = false')), isTrue,
        reason: '터졌을 때 단추를 «반드시» 되살리지 않는다 — '
            '그 뒤로 사진을 영영 못 올린다 (찾은 finally ${blocks.length}개)');
  });

  test('진행 수는 «건너뛰는 길에서도» 오른다', () {
    /* 올리기 실패로 `continue` 하는 길에서 진행 수를 빠뜨리면
       실패한 장부터 숫자가 멈춰 「멎은 것」처럼 보인다. */
    final blocks = finallyBlocks(body);
    expect(blocks.any((b) => b.contains('_upDone = ok + fail')), isTrue,
        reason: '진행 수를 «어느 길로 끝나든» 올리지 않는다 — '
            '실패한 장에서 숫자가 멈춘다');
  });

  test('끝나고 «사실대로» 알린다', () {
    expect(body, contains("fail == 0 ? '사진 \$ok장을 올렸어요 📸'"),
        reason: '몇 장 올랐는지 안 알려 준다');
    expect(body, contains('\$fail장 실패'), reason: '실패한 장수를 안 알려 준다');
  });
}
