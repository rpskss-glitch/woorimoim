// 「↑ 이전 대화 더 보기」로 펼친 옛 대화는 «실시간 창(최근 200개) 밖»이다.
// 그래서 지우거나 반응을 남겨도 구독이 알려주지 않아 화면이 하나도 안 바뀐다 — 85회차.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

List<Map<String, dynamic>> older() => [
      {'id': 'm1', 'text': '옛날 대화', 'reacts': <String, dynamic>{}},
      {'id': 'm2', 'text': '그 다음'},
      {'id': 'm3', 'text': '또 그 다음'},
    ];

void main() {
  test('지운 대화는 펼친 목록에서 빠진다', () {
    final out = Store.applyToOlder(older(), 'm2', null);
    expect(out.map((m) => m['id']), ['m1', 'm3']);
  });

  test('고친 대화는 새 값으로 갈아 끼운다 (자리는 그대로)', () {
    final fresh = {'id': 'm2', 'text': '그 다음', 'reacts': {'u1': '❤️'}};
    final out = Store.applyToOlder(older(), 'm2', fresh);
    expect(out.map((m) => m['id']), ['m1', 'm2', 'm3']);
    expect((out[1]['reacts'] as Map)['u1'], '❤️');
  });

  test('목록에 없는 번호를 줘도 그대로다', () {
    expect(Store.applyToOlder(older(), '없는것', null).length, 3);
    expect(Store.applyToOlder(older(), '없는것', {'id': 'x'}).length, 3);
  });

  test('빈 목록에서도 죽지 않는다', () {
    expect(Store.applyToOlder(const [], 'm1', null), isEmpty);
  });

  test('채팅이 지우기·반응 뒤에 창 밖을 맞춘다', () {
    final src = File('lib/ui/chat.dart').readAsStringSync();
    final del = src.indexOf("deleteItem(code, m['id'] as String, 'msg')");
    expect(del, greaterThan(0));
    expect(src.substring(del, del + 260).contains('syncOlder'), isTrue,
        reason: '안 빼면 «지운 대화가 화면에 그대로» 남는다');
    expect(src.substring(del, del + 260).contains('removed: true'), isTrue);
    final re = src.indexOf("'reacts':");
    expect(src.substring(re, re + 400).contains('syncOlder'), isTrue,
        reason: '하트가 안 붙어 회원이 계속 누른다');
  });

  test('방을 옮기면 「더 보기」 상태도 같이 지운다', () {
    final src = File('lib/store.dart').readAsStringSync();
    final nl = String.fromCharCode(10);
    /* ⚠️ 창을 넉넉히 잡으면 «다음 함수»의 줄까지 보여서 헛통과한다 (66회차와 같은 갈래).
       여는 괄호부터 짝이 맞는 닫는 괄호까지 — 그 함수 몸통만 본다. */
    String body(String head) {
      final at = src.indexOf(head);
      expect(at, greaterThan(0), reason: head);
      final open = src.indexOf('{', at);
      var d = 0;
      for (var k = open; k < src.length; k++) {
        if (src[k] == '{') d++;
        if (src[k] == '}') {
          d--;
          if (d == 0) return src.substring(open, k);
        }
      }
      return '';
    }

    for (final fn in ['void stopAll()', 'void subItems(']) {
      final b = body(fn);
      expect(b.split(nl).length, lessThan(80), reason: '$fn 몸통을 잘못 잡았다 (파일 전체를 집었나)');
      expect(b.contains('_hasMore = false'), isTrue,
          reason: '$fn — 옛 방의 값이 남아 헛도는 단추가 뜬다');
      expect(b.contains('_noMoreOlder = false'), isTrue, reason: fn);
    }
  });
}
