// 방을 지울 때 «모임 문서 자신»이 든 사진도 치우는가 (144회차).
//
// 상징 사진과 회원 아바타의 번호는 items·msgs 가 아니라 **couples 문서 안**에 있다.
// 그래서 방 지우기의 기록 훑기에 한 장도 안 걸렸고, 문서를 지우고 나면
// 보관함 목록 보기는 규칙이 막아 두어 **원본을 영영 못 찾는다** — 매달 보관 요금만 나간다.
// (`purgeClubData` 가 스스로 경계하던 바로 그 일인데, 문서 자신에게는 안 쓰고 있었다)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

void main() {
  test('상징·회원·탈퇴·신청에 든 사진을 모두 찾는다', () {
    final ids = Store.photoIdsOfCouple({
      'emblem': {'kind': 'photo', 'photo': 'st:c/emblem'},
      'members': {
        'u1': {'uid': 'u1', 'photo': 'st:c/u1'},
        'u2': {'uid': 'u2'}, // 사진 없는 회원
      },
      'former': {
        'u3': {'uid': 'u3', 'photo': 'st:c/u3'}
      },
      'pending': {
        'u4': {'uid': 'u4', 'photo': 'st:c/u4'}
      },
    });
    expect(ids.toSet(), {'st:c/emblem', 'st:c/u1', 'st:c/u3', 'st:c/u4'});
  });

  test('사진이 없거나 모양이 망가져도 안 터진다', () {
    expect(Store.photoIdsOfCouple(null), isEmpty);
    expect(Store.photoIdsOfCouple({}), isEmpty);
    expect(Store.photoIdsOfCouple({'emblem': '글자', 'members': '글자'}), isEmpty);
    expect(Store.photoIdsOfCouple({'members': {'u1': '사람이 아님'}}), isEmpty);
    expect(Store.photoIdsOfCouple({'members': {'u1': {'photo': ''}}}), isEmpty);
  });

  test('방 지우기가 «기록보다 먼저» 그 사진들을 챙긴다', () {
    final src = stripComments(File('lib/store.dart').readAsStringSync());
    final at = src.indexOf('purgeClubData(');
    expect(at, greaterThan(0));
    final body = src.substring(src.indexOf('async {', at));
    final grab = body.indexOf('photoIdsOfCouple(');
    final loop = body.indexOf("for (final name in ['items'");
    expect(grab, greaterThan(0), reason: '상징·아바타 원본이 영영 남는다');
    expect(grab, lessThan(loop),
        reason: '기록을 먼저 지우면 번호를 어디서도 못 찾는다');
  });

  test('탈퇴 처리도 그 사람 아바타를 치운다', () {
    // 탈퇴 기록(former)에는 사진을 안 남기므로 아무도 그 원본을 못 찾는다
    final src = stripComments(File('lib/ui/members.dart').readAsStringSync());
    final at = src.indexOf("'members.\$uid': null");
    expect(at, greaterThan(0));
    expect(src.substring(at, (at + 900).clamp(at, src.length)).contains('dropPhotos('),
        isTrue);
  });

  test('문서 «안»에 들어 있던 옛 사진은 지우려 들지 않는다', () {
    /* `data:` 값은 그림이 문서에 통째로 들어 있던 옛 방식이라 지울 원본이 없다.
       걸러 내지 않으면 보관함에 없는 것을 지우려다 대기줄에서 10번을 헛돈다.
       부르는 곳마다 챙기면 언젠가 빠뜨리므로 «들어오는 문 한 곳»에서 거른다. */
    final src = stripComments(File('lib/store.dart').readAsStringSync());
    final at = src.indexOf('void dropPhotos(');
    expect(at, greaterThan(0));
    expect(src.substring(at, (at + 400).clamp(at, src.length)).contains("startsWith('data:')"),
        isTrue, reason: '문 한 곳에서 걸러야 한다');
  });
}
