import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🕳 「아무도 안 보고 있던 자리」 여섯 곳 (168회차).

   대화방·설정·가입 쪽 20군데에 흠을 내니 5곳이 안 물렸다(+ 1곳은 글자 실수로 건너뜀).
   여섯 다 지금 코드는 맞다 — 지키는 시험이 없었을 뿐이다. */
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

  group('대화방', () {
    test('① 창 밖으로 «밀려난» 대화를 붙든다', () {
      /* `fellOutOfWindow` 자체를 재는 시험은 있었지만, **대화 구독이 그것을 실제로 부르는지**를
         아무도 안 봤다. 안 부르면 「더 보기」로 펼친 뒤 새 대화가 올 때마다
         화면 «중간»에서 대화가 하나씩 소리 없이 사라진다. */
      final body = bodyOf(bare('lib/store.dart'), 'void subItems(');
      expect(body, contains('fellOutOfWindow(_recent, next)'),
          reason: '대화 구독이 밀려난 대화를 안 붙든다 — '
              '「더 보기」로 펼친 뒤 새 말이 올 때마다 옛 대화가 하나씩 사라진다');
      expect(body, contains('_older = [..._older, ...fell]'),
          reason: '골라내기만 하고 펼친 목록에 안 담는다');
    });

    test('② 창 «안»의 대화는 서버에 다시 묻지 않는다', () {
      final body = bodyOf(bare('lib/store.dart'), 'Future<void> syncOlder(');
      expect(body, contains("if (!_older.any((m) => m['id'] == id)) return;"),
          reason: '창 안이면 구독이 알아서 고쳐 주는데도 서버에 또 묻는다 — '
              '대화를 지우거나 반응을 남길 때마다 «읽기 요금»이 한 번씩 더 나간다');
    });
  });

  group('설정', () {
    test('③ 모임에서 나갈 때 «이 폰의 알림 자리»를 비운다', () {
      final s = bare('lib/ui/settings.dart');
      final at = s.indexOf("okLabel: '나가기'");
      expect(at, greaterThan(0), reason: '나가기 단추를 못 찾았다');
      final blk = s.substring(at, s.indexOf('clearProfile()', at));
      expect(blk, contains("'push."),
          reason: '나가고도 알림 자리가 남는다 — '
              '나간 모임의 대화 알림이 이 폰에 계속 오고, 눌러도 그 모임 화면이 없다');
      expect(blk, contains('Store.i.myUid'), reason: '비우는 것이 «내 자리»가 아니다');
    });
  });

  group('폰을 바꿔 이어받기 — 서버 규칙이 요구하는 것', () {
    /* 규칙(firestore.rules)의 claimsOwnSeat 는 셋을 함께 요구한다.
         · request.resource.data.claimFrom 이 «옛 자리 번호»여야 하고
         · 그 옛 자리가 새 자료에 «없어야» 하고
         · 새로 생기는 자리는 내 것 하나뿐이어야 한다
       하나만 빠져도 **폰 바꾸기가 통째로 거절된다.** */
    late String tx;

    setUpAll(() {
      final s = bare('lib/ui/onboarding.dart');
      final at = s.indexOf('mutateCouple(');
      expect(at, greaterThan(0), reason: '이어받기 트랜잭션을 못 찾았다');
      var d = 0, i = at + 'mutateCouple'.length;
      for (; i < s.length; i++) {
        if (s[i] == '(') d++;
        if (s[i] == ')') { d--; if (d == 0) break; }
      }
      tx = s.substring(at, i);
    });

    test('④ «누구 자리를 이어받는지»를 적는다', () {
      expect(tx, contains("'claimFrom': oldUid"),
          reason: '서버는 이 표시가 없으면 «남의 자리를 빼앗는 것»과 구분할 수 없어 아예 막는다 — '
              '폰을 바꾼 회원이 영영 못 들어온다');
    });

    test('⑤ «회원 자리»에서 옛 자리를 지운다', () {
      /* ⚠️ `oldUid: Store.del` 만 찾으면 안 된다 — **알림 자리에도 같은 글자가 있다**
         (`'push': {oldUid: Store.del}`). 회원 자리에서 지워 놓고도 그냥 통과했다
         (153회차와 같은 함정: 그 낱말이 근처에 있나로 보면 옆 줄에 속는다).
         그래서 «회원 묶음 안»만 떼어내서 본다. */
      final at = tx.indexOf("'members': {");
      expect(at, greaterThan(0), reason: '회원 자리를 고치는 곳을 못 찾았다');
      var d = 0, i = tx.indexOf('{', at + "'members':".length);
      final open = i;
      for (; i < tx.length; i++) {
        if (tx[i] == '{') d++;
        if (tx[i] == '}') { d--; if (d == 0) break; }
      }
      final members = tx.substring(open, i);
      expect(members, contains('oldUid: Store.del'),
          reason: '옛 자리를 안 지우면 서버 규칙이 이어받기를 거절하고(옛 자리가 남으면 안 된다), '
              '설령 들어가도 회원 목록에 같은 사람이 «둘»로 보인다');
      expect(members, contains('uid: {'), reason: '새 자리를 안 만든다');
    });

    test('⑥ 가입할 때 «같은 이름·같은 아바타»를 두 곳 모두에서 막는다', () {
      final s = bare('lib/ui/onboarding.dart');
      // 부르기만 하고 «결과를 안 보면» 소용없다 — 이름과 그 이름을 보는 곳을 함께 못 박는다
      for (final v in const ['clash', 'pendingClash']) {
        expect(s, contains('$v = Logic.avatarClash('),
            reason: '$v 를 avatarClash 로 안 구한다');
        expect(s, contains('if ($v != null)'),
            reason: '$v 를 구해 놓고 «보지 않는다» — 같은 이름·같은 아바타가 그대로 들어와 '
                '채팅·출석·순위 어디서도 누가 누군지 구분이 안 된다');
      }
    });
  });
}
