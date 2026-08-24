// 폰을 바꾼 뒤 «내 말»이 내 말로 보이는지 (110회차).
//
// 말풍선의 좌우·색·아바타·이름은 `msg['by'] == 내번호` 로 갈린다.
// 폰을 바꾸면 번호가 새로 생기므로, 안 이으면 **지난 대화가 통째로 남의 말풍선**으로 보인다
// (왼쪽에 내 아바타와 내 이름이 얹힌 채 — 같은 이름의 딴 사람처럼).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

void seed() {
  AppState.i.couple = Store.tidyCouple({
    'members': {
      'u1': {'uid': 'u1', 'name': '갑', 'role': 'member'},
      'u2': {'uid': 'u2', 'name': '을', 'role': 'member'},
    },
    'former': {
      'u1old': {'uid': 'u1old', 'name': '갑', 'movedTo': 'u1'},
      'u1older': {'uid': 'u1older', 'name': '갑', 'movedTo': 'u1old'},
      'u9': {'uid': 'u9', 'name': '정', 'leftAt': 1755000000000},
    },
  });
}

void main() {
  test('폰 바꾸기 전 번호도 «나»다', () {
    seed();
    expect(Logic.isMe('u1', 'u1'), isTrue);
    expect(Logic.isMe('u1old', 'u1'), isTrue, reason: '한 번 바꾼 것');
    expect(Logic.isMe('u1older', 'u1'), isTrue, reason: '두 번 바꾼 것 — 사슬 끝까지');
  });

  test('남은 «나»가 아니다', () {
    seed();
    expect(Logic.isMe('u2', 'u1'), isFalse);
    expect(Logic.isMe('u9', 'u1'), isFalse, reason: '탈퇴한 사람');
    expect(Logic.isMe(null, 'u1'), isFalse);
    expect(Logic.isMe('', 'u1'), isFalse);
  });

  test('폰을 안 바꿨으면 예전과 똑같이 동작한다', () {
    AppState.i.couple = Store.tidyCouple({
      'members': {'u1': {'uid': 'u1', 'name': '갑', 'role': 'member'}},
      'former': <String, dynamic>{},
    });
    expect(Logic.isMe('u1', 'u1'), isTrue);
    expect(Logic.isMe('u2', 'u1'), isFalse);
  });

  test('말풍선 좌우가 이 판단을 쓴다', () {
    final src = File('lib/ui/chat.dart').readAsStringSync();
    final at = src.indexOf("final mine = Logic.isMe(msg['by']");
    expect(at, greaterThan(0), reason: '안 이으면 내 지난 대화가 남의 것처럼 보인다');
    // 읽음 표시가 붙는 자리도 같은 판단이라야 어긋나지 않는다
    expect(src.contains("Logic.isMe(all[i]['by'] as String?, Store.i.myUid)"), isTrue);
  });

  test('«권한»에는 안 쓴다 — 헛단추가 되기 때문', () {
    /* 서버는 글에 적힌 번호(`by`)만 보고 지우기를 판단한다.
       화면에서만 단추를 띄우면 눌러도 거절당한다 — 그래서 권한 쪽은 일부러 좁게 둔다. */
    for (final f in ['lib/ui/chat.dart', 'lib/ui/board.dart']) {
      final src = File(f).readAsStringSync();
      final code = src
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
          .split(String.fromCharCode(10))
          .map((l) => l.split('//').first)
          .join(String.fromCharCode(10));
      // 지우기 메뉴를 여는 자리는 그대로 «내 번호»만 본다
      expect(code.contains("['by'] == Store.i.myUid"), isTrue,
          reason: '$f — 권한까지 넓히면 눌러도 안 되는 단추가 생긴다');
    }
  });
}
