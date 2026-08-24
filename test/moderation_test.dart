import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/moderation.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 🛡 신고·차단·거르기·운영자 연락처 — 194회차.

   애플 1.2(사용자 생성 콘텐츠)는 넷을 «모두» 요구한다. 하나라도 없으면 반려된다.
   구글도 UGC 정책에서 같은 것을 본다. 대화·게시판·사진첩이 있는 이 앱은 정면으로 해당된다.

   여기서 지키는 것:
     · 차단은 **내 화면에서만** 가린다 — 남의 글을 지우는 것이 아니다.
     · 폰을 바꾼 사람도 «같은 사람»으로 본다 (옛 번호로 차단해 뒀어도 계속 가려져야 한다).
     · 나 자신은 차단할 수 없다 (내 글이 안 보여 어리둥절해진다).
     · 걸러내기는 **좁게** — 멀쩡한 말을 별표로 만들면 회원이 못 쓴다. */
void main() {
  void seed({List<String>? blocked}) {
    AppState.i.profile = {'code': 'C1', 'slot': 'u1', 'name': '갑'};
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'u1': {'uid': 'u1', 'name': '갑', 'role': 'owner', if (blocked != null) 'blocked': blocked},
        'u2': {'uid': 'u2', 'name': '을', 'role': 'member'},
        'u3': {'uid': 'u3', 'name': '병', 'role': 'member'},
      },
      'former': {
        'u9': {'uid': 'u9', 'name': '을(옛폰)', 'movedTo': 'u2'}
      },
    });
    AppState.i.setItems([]);
  }

  tearDown(() {
    AppState.i.profile = null;
    AppState.i.resetRoom();
  });

  group('차단', () {
    test('차단한 사람의 글만 가린다', () {
      seed(blocked: ['u2']);
      final list = [
        {'id': 'a', 'by': 'u1', 'text': '내 글'},
        {'id': 'b', 'by': 'u2', 'text': '차단한 사람 글'},
        {'id': 'c', 'by': 'u3', 'text': '남의 글'},
      ];
      final shown = Moderation.hide(list).map((x) => x['id']).toList();
      expect(shown, ['a', 'c']);
    });

    test('폰을 바꾼 사람도 계속 가려진다 (옛 번호로 차단해 둔 경우)', () {
      seed(blocked: ['u9']); // u9 → u2 로 폰을 바꿨다
      expect(Moderation.isBlocked('u2'), isTrue, reason: '번호가 바뀌자 차단이 풀려 버린다');
      expect(Moderation.isBlocked('u3'), isFalse);
    });

    test('차단이 없으면 아무것도 안 가린다', () {
      seed();
      final list = [
        {'id': 'a', 'by': 'u2'}
      ];
      expect(Moderation.hide(list), hasLength(1));
      expect(Moderation.blocked(), isEmpty);
    });

    test('나 자신은 차단할 수 없다', () {
      seed();
      expect(Moderation.canBlock('u1', 'u1'), isFalse);
      expect(Moderation.canBlock('u2', 'u1'), isTrue);
      expect(Moderation.canBlock(null, 'u1'), isFalse);
    });

    test('차단 목록에 같은 사람이 두 번 들어가지 않는다', () {
      seed(blocked: ['u2']);
      expect(Moderation.nextBlocked('u2', true), ['u2']);
    });

    test('풀 때는 옛 번호로 적힌 것까지 함께 뺀다', () {
      seed(blocked: ['u9', 'u3']);
      final next = Moderation.nextBlocked('u2', false); // u9 는 u2 의 옛 번호
      expect(next, ['u3'], reason: '옛 번호가 남아 «풀었는데도 계속 안 보이는» 꼴이 된다');
    });
  });

  group('거르기', () {
    test('심한 욕설을 별표로 가린다', () {
      expect(Moderation.hasBad('이 씨발 뭐야'), isTrue);
      expect(Moderation.mask('이 씨발 뭐야').contains('씨발'), isFalse);
      expect(Moderation.mask('이 씨발 뭐야').contains('**'), isTrue);
    });

    test('띄어써서 피해 가는 것도 잡는다', () {
      expect(Moderation.hasBad('이 씨 발 뭐야'), isTrue);
    });

    test('멀쩡한 말은 건드리지 않는다', () {
      for (final ok in ['오늘 모임 7시예요', '셔틀콕 챙겨갈게요', '개나리 피었어요', '시발점이 어디죠']) {
        expect(Moderation.mask(ok), ok, reason: '멀쩡한 말이 별표가 되면 회원이 앱을 못 쓴다: $ok');
      }
    });

    test('빈 글·null 에도 안 터진다', () {
      expect(Moderation.hasBad(null), isFalse);
      expect(Moderation.hasBad(''), isFalse);
      expect(Moderation.mask(null), '');
    });
  });

  group('스토어가 요구하는 넷이 다 있는가', () {
    String bare(String p) => File(p)
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//.*'), '');

    test('① 신고 — 대화에서 사유를 골라 신고할 수 있다', () {
      final chat = bare('lib/ui/chat.dart');
      expect(chat.contains("Navigator.pop(c, 'report')"), isTrue, reason: '신고 메뉴가 없다');
      expect(chat.contains('Store.i.reportContent('), isTrue, reason: '신고가 서버에 안 남는다');
      expect(chat.contains('Moderation.reasons'), isTrue, reason: '무엇을 신고하는지 못 고른다');
    });

    test('② 차단 — 대화에서 차단할 수 있고, 설정에서 풀 수 있다', () {
      expect(bare('lib/ui/chat.dart').contains("Navigator.pop(c, 'block')"), isTrue);
      final st = bare('lib/ui/settings.dart');
      expect(st.contains('차단한 회원'), isTrue, reason: '푸는 길이 없으면 차단이 «되돌릴 수 없는 것»이 된다');
      expect(st.contains('Moderation.nextBlocked'), isTrue);
    });

    test('③ 거르기 — 화면에 그릴 때 걸러진다', () {
      final chat = bare('lib/ui/chat.dart');
      expect(chat.contains('Moderation.hide('), isTrue, reason: '차단해도 대화가 그대로 보인다');
      expect(bare('lib/ui/board.dart').contains('Moderation.hide('), isTrue,
          reason: '게시판·사진첩에서는 차단이 안 먹는다 — 한 화면만 되면 반려된다');
    });

    test('④ 운영자 연락처가 앱 안에 있다', () {
      expect(bare('lib/ui/settings.dart').contains('운영자에게 연락'), isTrue);
      expect(Moderation.contactEmail.contains('@'), isTrue);
    });

    test('내 자료 지우기(계정 삭제)가 앱 안에 있다 — 애플 5.1.1(v)', () {
      final st = bare('lib/ui/settings.dart');
      expect(st.contains('내 자료 지우기'), isTrue);
      expect(st.contains('Store.i.deleteMyData('), isTrue);
      final store = bare('lib/store.dart');
      final at = store.indexOf('Future<bool> deleteMyData(');
      expect(at, greaterThan(0));
      final body = store.substring(at, at + 900);
      expect(body.contains("'members.\$uid': null"), isTrue, reason: '회원 자리가 안 지워진다');
      expect(body.contains("'push.\$uid': null"), isTrue, reason: '지운 뒤에도 알림이 계속 온다');
    });
  });
}
