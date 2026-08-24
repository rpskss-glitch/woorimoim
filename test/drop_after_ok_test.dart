import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🧹 「지웠는지 «보고 나서» 원본을 치운다」.

   180회차에 «부르는 자리를 막이 밖으로 옮겨» 보았다 — 글자는 그대로 두고 **자리만** 옮겼다.
   기존 검사기는 「그 부름이 있는가」만 봐서 **네 곳이 그냥 통과**했다.
   실제로 그렇게 되면:
     · 기록은 못 지웠는데 **원본만 사라져** 그 글·사진이 «영영 깨진 그림»으로 남는다(되돌릴 수 없다)
     · 대화는 서버가 거절했는데 **내 화면에서만 사라져** 다시 열면 되살아난다
   그래서 «있는가»가 아니라 **«결과를 보고 나서 하는가»**를 못 박는다. */
void main() {
  String bare(String p) => File(p)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  /// [call] 하나하나에 대해, «바로 앞의 [after]» 부터 그 사이에 [must] 가 있는지 본다.
  /// 고정 글자 창을 안 쓴다 — 주석 몇 줄에 흔들리지 않게(174회차 교훈).
  List<String> gapsMissing(String src, String after, String call, String must) {
    final bad = <String>[];
    for (final m in RegExp(RegExp.escape(call)).allMatches(src)) {
      final prev = src.lastIndexOf(after, m.start);
      if (prev < 0) {
        bad.add('«$after» 를 앞에서 못 찾음');
        continue;
      }
      if (!src.substring(prev, m.start).contains(must)) {
        bad.add('${src.substring(prev, prev + 24).trim()}… 뒤에 «$must» 가 없다');
      }
    }
    return bad;
  }

  test('글·사진·장부 — 지우기 «결과를 보고 나서» 원본을 치운다', () {
    for (final f in const ['lib/ui/board.dart', 'lib/ui/wallet.dart']) {
      final s = bare(f);
      final call = 'dropPhotos(Store.photoIdsOf(item))';
      expect(s, contains(call), reason: '$f 가 원본을 아예 안 치운다');
      final bad = gapsMissing(s, 'deleteItem(', call, 'if (!done)');
      expect(bad, isEmpty,
          reason: '$f — 지우기가 «됐는지 보기 전»에 원본을 치운다. '
              '못 지웠는데 사진만 사라지면 그 기록은 «영영 깨진 그림»으로 남는다: $bad');
    }
  });

  test('대화 — 서버가 «받아들였을 때만» 화면에서 뺀다', () {
    final s = bare('lib/ui/chat.dart');
    const call = "syncOlder(m['id'] as String, 'msg', removed: true)";
    expect(s, contains(call), reason: '펼친 옛 대화에서 지운 것을 안 뺀다');
    final bad = gapsMissing(s, 'deleteItem(', call, 'if (ok)');
    expect(bad, isEmpty,
        reason: '서버가 거절했는데도 화면에서 뺀다 — '
            '지워지지 않은 대화가 «내 화면에서만» 사라지고, 다시 열면 되살아난다: $bad');
  });

  test('세 화면 모두 «지우지 못했어요»라고 말한다', () {
    // 결과를 보고 나서 하려면 그 결과로 «말도» 해야 한다
    for (final f in const [
      'lib/ui/board.dart',
      'lib/ui/wallet.dart',
      'lib/ui/chat.dart',
    ]) {
      expect(bare(f), contains('지우지 못했어요'), reason: '$f 가 실패를 안 알린다');
    }
  });
}
