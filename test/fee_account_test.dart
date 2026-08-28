import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

/* 🏦 「회비 보내는 곳」 — 은행·계좌번호·예금주를 한 줄로 적어 두고 회원이 눌러 복사한다.

   이게 없으면 회원은 «어디로 보내죠?»를 매번 묻고 총무는 매번 계좌를 다시 쓴다.
   모임에서 가장 자주 오가는 말인데 앱에 자리가 없었다. */
void main() {
  group('들어온 값 다듬기', () {
    test('앞뒤 빈칸을 떼고 그대로 둔다', () {
      final c = Store.tidyCouple({
        'fee': {'amount': 20000, 'account': '  우리 1002-123-456789 김총무  '}
      });
      expect((c?['fee'] as Map)['account'], '우리 1002-123-456789 김총무');
    });

    test('글자가 아니면 버린다 — 안 버리면 회비 화면이 통째로 안 뜬다', () {
      /* `as String?` 로 읽는 자리라 숫자·배열이 들어오면 그 줄에서 터진다.
         백업을 손으로 고쳤거나 옛 자료면 실제로 들어올 수 있다. */
      for (final bad in [123, ['a'], {'x': 1}, true]) {
        final c = Store.tidyCouple({
          'fee': {'amount': 20000, 'account': bad}
        });
        expect((c?['fee'] as Map).containsKey('account'), isFalse,
            reason: '$bad 를 그대로 뒀다 — 회비 화면이 터진다');
      }
    });

    test('너무 길면 자른다 — 한 줄 자리라 화면 밖으로 넘친다', () {
      final c = Store.tidyCouple({
        'fee': {'amount': 20000, 'account': 'ㄱ' * 300}
      });
      expect(((c?['fee'] as Map)['account'] as String).length, 60);
    });

    test('회비 금액은 건드리지 않는다', () {
      final c = Store.tidyCouple({
        'fee': {'amount': 20000, 'account': '우리 111'}
      });
      expect((c?['fee'] as Map)['amount'], 20000);
    });
  });

  group('코드가 지켜야 하는 것', () {
    final settings = File('lib/ui/settings.dart').readAsStringSync();
    final wallet = File('lib/ui/wallet.dart').readAsStringSync();

    test('저장할 때 «금액·내는 날»을 같이 보내지 않는다', () {
      /* set(merge:true) 는 안쪽 묶음을 합쳐 주므로 안 보낸 칸은 그대로 남는다.
         같이 보내면 남이 방금 고친 「내는 날」을 조용히 되돌린다 — 예전에 실제로 그랬다. */
      final at = settings.indexOf('Future<void> _editAccount()');
      expect(at, greaterThan(0));
      // 다음 함수까지 새면 «남의 코드»를 보게 된다 — 이 함수 안에서만 본다
      final end = settings.indexOf('\n  Future<void> ', at + 10);
      final body = settings.substring(at, end > 0 ? end : settings.length);
      expect(body.contains("'fee': {'account': v}"), isTrue);
      expect(body.contains("'amount'"), isFalse,
          reason: '계좌만 고치는 자리에서 금액을 같이 보내고 있다');
      expect(body.contains("'day'"), isFalse,
          reason: '계좌만 고치는 자리에서 「내는 날」을 같이 보내고 있다');
    });

    test('회비 화면에서 눌러 복사하고, 복사했다고 «말한다»', () {
      expect(wallet.contains('Clipboard.setData'), isTrue, reason: '복사가 안 된다');
      expect(wallet.contains("toast(context, '계좌를 복사했어요')"), isTrue,
          reason: '눌렀는데 아무 말이 없으면 안 된 줄 알고 또 누른다');
    });

    test('계좌가 없으면 아무것도 안 그린다', () {
      final at = wallet.indexOf('class _AccountBar');
      expect(at, greaterThan(0));
      final body = wallet.substring(at);
      expect(body.contains('SizedBox.shrink()'), isTrue,
          reason: '빈 줄이 남으면 «뭔가 빠진 화면»으로 보인다');
    });
  });
}
