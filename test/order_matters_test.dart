import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

/* 🔢 «차례가 곧 규칙»인 자리.

   179회차에 차례를 뒤집어 시험 전체를 돌려 봤다. 대부분은 이미 잡혔는데
   («정리(tidy)의 글자→날짜», «방 지울 때 기록 먼저», «상징 저장→옛 원본 치우기»)
   **두 곳은 뒤집어도 아무도 안 울었다.** 둘 다 «부르기만 하면 되는» 것이 아니라
   «어느 차례로 부르는가»가 곧 규칙인 자리다. */
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

  late String store;
  setUpAll(() => store = bare('lib/store.dart'));

  test('사진은 «대기줄에 적고 나서» 지운다', () {
    /* 지우는 그 순간은 보통 «앱을 닫는 때»라 요청이 끝까지 갈 보장이 없다.
       먼저 적어 두지 않으면, 앱이 죽는 사이 요청이 서버에 안 닿았을 때
       그 번호를 «아무도 모르게» 잃어버린다 → 못 보는 원본에 보관 요금만 매달 나간다. */
    final body = bodyOf(store, 'void dropPhotos(');
    expect(body, isNotEmpty, reason: 'dropPhotos 를 못 찾았다 — 이 시험이 헛돌고 있다');
    final pend = body.indexOf('_pend(id, true)');
    final del = body.indexOf('deletePhoto(id)');
    expect(pend, greaterThan(0));
    expect(del, greaterThan(0));
    expect(pend, lessThan(del),
        reason: '지우기를 «먼저» 보내면, 앱이 그 사이 죽었을 때 '
            '그 사진 번호가 대기줄에도 없어 영영 못 찾는다');
  });

  group('창 밖으로 밀려난 대화', () {
    test('같은 묶음끼리 견주면 «아무것도» 안 나온다', () {
      // 그래서 바꿔치기 «전»에 골라내야 한다 — 뒤에 하면 늘 빈손이 된다
      final win = [
        {'id': 'a', 'createdAt': 1},
        {'id': 'b', 'createdAt': 2},
      ];
      expect(Store.fellOutOfWindow(win, win), isEmpty);
    });

    test('밀려난 것은 «새 창의 가장 오래된 것보다 오래된» 것이다', () {
      final prev = [
        {'id': 'a', 'createdAt': 1},
        {'id': 'b', 'createdAt': 2},
      ];
      final next = [
        {'id': 'b', 'createdAt': 2},
        {'id': 'c', 'createdAt': 3},
      ];
      expect(Store.fellOutOfWindow(prev, next).map((m) => m['id']), ['a']);
    });

    test('«바꿔치기 전»에 골라낸다', () {
      final body = bodyOf(store, 'void subItems(');
      final pick = body.indexOf('fellOutOfWindow(_recent, next)');
      final swap = body.indexOf('_recent = next;');
      expect(pick, greaterThan(0), reason: '밀려난 대화를 안 골라낸다');
      expect(swap, greaterThan(0));
      expect(pick, lessThan(swap),
          reason: '바꿔치기 «뒤»에 고르면 같은 묶음끼리 견주게 되어 늘 빈손이다 — '
              '「더 보기」로 펼친 뒤 새 말이 올 때마다 옛 대화가 하나씩 사라진다');
    });
  });
}
