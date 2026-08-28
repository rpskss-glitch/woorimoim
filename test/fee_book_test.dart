import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee_book.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';

/* 💵 회비를 «적는 셈».

   여기가 틀리면 통장 잔액이 장부와 안 맞는데, 총무는 몇 달 뒤에야 알아채고
   그때는 어느 달이 틀렸는지 찾을 수가 없다. 그래서 셈을 화면과 떼어 놓고 못 박는다.

   ⚠️ 서버에 실제로 쓰는 부분(`Store.i.addItem`)은 여기서 못 부른다(파이어베이스가 없다).
      그래서 «서버에 닿기 전에 끝나는 길»과 «코드가 지켜야 하는 모양»을 본다. */
void main() {
  final st = AppState.i;

  void seed({
    required String role,
    String? title,
    int amount = 20000,
    List<String> paid = const [],
  }) {
    st.profile = {'code': 'C', 'slot': 'u1', 'name': '나'};
    st.setCouple({
      'fee': {'amount': amount},
      'members': {
        'u1': {
          'uid': 'u1',
          'name': '나',
          'role': role,
          if (title != null) 'title': title,
          'joinedAt': DateTime(2020, 1, 1).millisecondsSinceEpoch,
        },
      },
    });
    st.setItems([
      for (final m in paid)
        {
          'id': 'p_$m',
          'type': 'ledger',
          'kind': 'in',
          'payer': 'u1',
          'amount': amount,
          'feeMonths': [m],
          'date': '$m-05',
        },
    ]);
  }

  group('누가 적을 수 있나', () {
    test('평회원은 회비를 적을 수 없다', () async {
      seed(role: 'member');
      final r = await FeeBook.receive(uid: 'u1', name: '나', months: 1);
      expect(r.done, isFalse);
      expect(r.why, contains('회장·총무'),
          reason: '왜 안 되는지 말해줘야 총무에게 부탁할 생각을 한다');
    });

    test('총무 직책이면 적을 수 있다 (서버에 닿기 전까지 통과)', () {
      seed(role: 'member', title: '총무');
      expect(st.isTreasurer, isTrue);
    });

    test('방장은 언제나 적을 수 있다', () {
      seed(role: 'owner');
      expect(st.isTreasurer, isTrue);
    });
  });

  group('개월 수', () {
    test('0이나 음수는 막는다', () async {
      seed(role: 'owner');
      for (final m in [0, -3]) {
        final r = await FeeBook.receive(uid: 'u1', name: '나', months: m);
        expect(r.done, isFalse, reason: '$m개월이 통과했다');
        expect(r.why, contains('1 이상'));
      }
    });

    test('한계를 넘으면 막는다 — 손이 미끄러진 「120개월」', () async {
      seed(role: 'owner');
      final r = await FeeBook.receive(uid: 'u1', name: '나', months: 120);
      expect(r.done, isFalse);
      expect(r.why, contains('${FeeBook.maxMonths}개월'));
    });

    test('1~36개월은 자유롭게 — 5개월도 된다', () {
      seed(role: 'owner');
      // 5개월치를 받으면 «메울 달»도 정확히 5개여야 한다
      expect(Logic.feeMonthsToFill('u1', 5).length, 5);
      expect(Logic.feeMonthsToFill('u1', 7).length, 7);
    });
  });

  group('돈 셈', () {
    test('이미 낸 달은 건너뛰고 «빈 달»만 메운다', () {
      final now = DateTime.now();
      final thisMonth = Logic.ymKey(Logic.ymOf(now));
      seed(role: 'owner', paid: [thisMonth]);
      final fill = Logic.feeMonthsToFill('u1', 3);
      expect(fill.contains(thisMonth), isFalse,
          reason: '이미 낸 달에 또 얹으면 회원이 낸 돈만큼 미납이 안 줄어든다');
      expect(fill.length, 3);
    });

    test('적는 돈은 «메운 달 수 × 월 회비»다', () {
      /* ⚠️ 요청한 달수로 곱하면 안 된다 — feeMonthsToFill 이 한계에 걸려
         요청보다 적게 돌려줄 수 있고, 그때 요청 수로 곱하면 받지도 않은 돈이
         통장에 더해져 잔액이 영영 안 맞는다. */
      final src = File('lib/fee_book.dart').readAsStringSync();
      expect(src.contains('final filled = feeMonths.length;'), isTrue);
      expect(src.contains('final total = won * filled;'), isTrue,
          reason: '요청한 달수(months)로 곱하면 «받지도 않은 달»의 돈이 장부에 들어간다');
      expect(RegExp(r"'amount': *won \* months").hasMatch(src), isFalse,
          reason: '아직 요청 달수로 곱하는 자리가 남아 있다');
      expect(src.contains("'months': filled"), isTrue,
          reason: '적어 두는 개월 수도 실제로 메운 수라야 장부 줄과 표가 같은 말을 한다');
    });

    test('두 번 눌러도 같은 달이 두 번 적히지 않게 문서 이름을 못 박는다', () {
      final src = File('lib/fee_book.dart').readAsStringSync();
      expect(src.contains('docId: Store.feeDocId(code, uid, feeMonths.first)'), isTrue,
          reason: '총무 둘이 거의 동시에 누르면 같은 달치가 두 번 들어간다');
    });
  });

  group('여러 명 한 번에', () {
    test('한 사람이 실패해도 나머지를 계속 적는다', () async {
      // 평회원이라 모두 실패하지만 «건너뛰지 않고 사람 수만큼» 답이 와야 한다
      seed(role: 'member');
      final res = await FeeBook.receiveMany(
        members: [
          {'uid': 'a', 'name': '가'},
          {'uid': 'b', 'name': '나'},
          {'uid': 'c', 'name': '다'},
        ],
        months: 1,
      );
      expect(res.length, 3,
          reason: '중간에 멈추면 총무는 어디까지 적혔는지 모른 채 다시 눌러야 한다');
      expect(res.map((r) => r.name).toList(), ['가', '나', '다']);
    });

    test('화면이 «못 적은 사람»을 이름으로 알려준다', () {
      final ui = File('lib/ui/wallet.dart').readAsStringSync();
      expect(ui.contains(r'· ${r.name}'), isTrue,
          reason: '「몇 명 실패」로는 누구를 다시 받아야 할지 알 수 없다');
    });
  });
}
