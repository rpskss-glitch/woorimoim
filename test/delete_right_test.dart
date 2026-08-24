import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 🗑 「지우기」 단추가 «서버가 받아 줄 때만» 보이는지.

   서버 규칙(firestore.rules)의 delete 는 두 가지를 함께 요구한다.
     ① 돈 기록이면 돈을 다룰 수 있어야 한다 (방장·운영진·총무 계열 «직책»)
     ② 그리고 «내가 쓴 것»이거나 방장·운영진이라야 한다 (직책은 안 본다)
   화면이 ①만 보고 메뉴를 띄우면, 평회원 총무가 남이 적은 기록을 지우려다
   「지우지 못했어요」만 되풀이해 본다 — 눌러도 안 되는 단추. */
void main() {
  void seed({required String role, String? title}) {
    final me = <String, dynamic>{'uid': 'me', 'name': '나', 'role': role};
    if (title != null) me['title'] = title;
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'me': me,
        'boss': {'uid': 'boss', 'name': '방장', 'role': 'owner'},
      },
      'fee': {'amount': 20000},
    });
    AppState.i.profile = {'code': 'ABC', 'slot': 'me', 'name': '나'};
  }

  final mine = {'id': 'a', 'type': 'ledger', 'by': 'me', 'uid': 'me'};
  final others = {'id': 'b', 'type': 'ledger', 'by': 'boss', 'uid': 'boss'};

  group('서버 규칙과 «같은 뜻»인지', () {
    test('내가 쓴 것은 평회원도 지울 수 있다', () {
      seed(role: 'member');
      expect(Logic.canDeleteItem(mine, 'me'), isTrue);
    });

    test('남이 쓴 것은 평회원이 못 지운다 — 「총무」 직책이어도 마찬가지', () {
      seed(role: 'member', title: '총무');
      expect(Logic.canDeleteItem(others, 'me'), isFalse,
          reason: '규칙의 isStaffOf 는 role 만 본다 — 직책으로는 남의 기록을 못 지운다');
    });

    test('운영진·방장은 남이 쓴 것도 지울 수 있다', () {
      seed(role: 'admin');
      expect(Logic.canDeleteItem(others, 'me'), isTrue);
      seed(role: 'owner');
      expect(Logic.canDeleteItem(others, 'me'), isTrue);
    });

    test('by 가 없고 uid 만 있는 옛 기록도 내 것으로 본다', () {
      seed(role: 'member');
      expect(Logic.canDeleteItem({'id': 'c', 'uid': 'me'}, 'me'), isTrue);
    });

    test('번호가 비었으면 못 지운다 (로그인 전)', () {
      seed(role: 'owner');
      expect(Logic.canDeleteItem(mine, ''), isFalse);
    });
  });

  String bare(String p) => File(p)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  test('회비 장부가 «둘 다» 보고 메뉴를 띄운다', () {
    final s = bare('lib/ui/wallet.dart');
    expect(s, contains('AppState.i.isTreasurer &&'),
        reason: '돈을 다룰 수 있는지를 안 본다');
    expect(s, contains('Logic.canDeleteItem(item, Store.i.myUid)'),
        reason: '지울 수 있는 기록인지를 안 본다 — '
            '평회원 총무에게 «남이 적은 기록»의 지우기 단추가 보이고, 눌러도 서버가 거절한다');
  });

  test('게시판·사진첩·대화방도 «내 것이거나 운영진»으로 거른다', () {
    for (final f in ['lib/ui/board.dart', 'lib/ui/chat.dart']) {
      final s = bare(f);
      expect(s, contains('isAdmin'), reason: '$f 가 운영진 예외를 안 둔다');
      expect(RegExp(r"\['by'\]\s*==\s*Store\.i\.myUid|isMe\(").hasMatch(s), isTrue,
          reason: '$f 가 «내가 쓴 것인지»를 안 본다');
    }
  });

  test('서버 규칙이 아직 «role 만» 보는지 — 바뀌면 이 잣대도 다시 봐야 한다', () {
    final f = File(r'C:\Users\asas3\Desktop\데이트장부\firestore.rules');
    if (!f.existsSync()) return;
    final r = f.readAsStringSync();
    expect(r, contains("m.role == 'owner' || m.role == 'admin'"),
        reason: 'isStaffOf 가 바뀌었다 — Logic.canDeleteItem 도 같이 맞춰야 한다');
    expect(r, contains('isMineDoc(resource.data)'),
        reason: 'delete 가 「내가 쓴 것」을 더 이상 안 본다 — 잣대를 다시 맞춰야 한다');
  });
}
