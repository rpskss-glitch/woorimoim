import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* ❤️ 좋아요도 «폰 바꾸기»를 이어야 한다.

   출석·회비·참석 투표·읽음은 모두 옛 번호를 이어 주는데 **반응만 빠져 있었다.**
   폰을 바꾼 회원이 옛날에 누른 좋아요를 다시 누르면
     · 하트가 **둘**로 보이고 (한 사람인데)
     · 옛 하트는 «내 것»으로 안 잡혀 **영영 뗄 수 없었다.**
   읽는 쪽에서 고친다 — 옛 기록이 그대로 있어도 바르게 보인다. */
void main() {
  /// u9 → u1 로 폰을 바꾼 방
  void seedMoved() {
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'u1': {'uid': 'u1', 'name': '갑'},
        'u2': {'uid': 'u2', 'name': '을'},
      },
      'former': {
        'u9': {'uid': 'u9', 'name': '갑', 'movedTo': 'u1'}
      },
    });
    AppState.i.setItems([]);
  }

  test('폰 바꾸기 전후는 «한 사람»으로 센다', () {
    seedMoved();
    // 옛 번호로 남긴 하트 + 새 번호로 남긴 하트 = 사실은 같은 사람
    expect(Logic.reactEmojis({'u9': '❤️', 'u1': '❤️'}), '❤️',
        reason: '한 사람인데 하트가 둘로 보인다');
  });

  test('다른 사람의 반응은 그대로 센다 — 거르기가 너무 넓지 않다', () {
    seedMoved();
    /* ⚠️ 글자 «길이»로 세면 안 된다 — 하트 한 개가 이미 길이 2다(이모지).
       한 사람일 때의 답과 «곧바로» 견준다. */
    final one = Logic.reactEmojis({'u9': '❤️'});
    final two = Logic.reactEmojis({'u9': '❤️', 'u2': '❤️'});
    expect(two, one + one, reason: '남의 반응까지 지워 버린다');
    expect(two, isNot(one));
  });

  test('망가진 값이 섞여도 안 터진다', () {
    seedMoved();
    expect(Logic.reactEmojis({'u1': 7, 'u2': '', 'u9': '❤️'}), '❤️');
    expect(Logic.reactEmojis(null), '');
    expect(Logic.reactEmojis('배열아님'), '');
  });

  group('내가 남긴 것 찾기', () {
    test('옛 번호로 남긴 것도 «내 것»이다', () {
      seedMoved();
      expect(Logic.myReactKeys({'u9': '❤️'}, 'u1'), ['u9'],
          reason: '옛 하트를 내 것으로 못 알아본다 — 영영 못 뗀다');
    });

    test('뗄 때는 «전부» 뗀다', () {
      seedMoved();
      final mine = Logic.myReactKeys({'u9': '❤️', 'u1': '❤️', 'u2': '❤️'}, 'u1');
      expect(mine.toSet(), {'u9', 'u1'});
      expect(mine, isNot(contains('u2')), reason: '남의 것까지 뗀다');
    });

    test('안 남겼으면 빈손', () {
      seedMoved();
      expect(Logic.myReactKeys({'u2': '❤️'}, 'u1'), isEmpty);
    });
  });

  test('대화방이 «그 잣대를 거쳐서» 그리고 뗀다', () {
    final s = File('lib/ui/chat.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//.*'), '');
    expect(s, contains("Logic.reactEmojis(msg['reacts'])"),
        reason: '말풍선이 반응을 그대로 이어 붙인다 — 폰 바꾼 사람이 둘로 보인다');
    expect(s, contains('Logic.myReactKeys(r, Store.i.myUid)'),
        reason: '좋아요를 뗄 때 «옛 번호로 남긴 것»을 안 본다 — 옛 하트가 영영 남는다');
    expect(s, contains('for (final k in mine) k: Store.del'),
        reason: '하나만 떼고 나머지를 남긴다');
  });
}
