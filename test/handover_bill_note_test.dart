import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee.dart';
import 'package:woorimoim/state.dart';

/* 👑💳 방장을 넘기면 이용권 갱신이 끊긴다 — 그런데 아무 말도 안 했다 (2026-09-26 77회차).

   이용권은 «넘기는 방장»의 스토어 계정으로 매달 청구된다. 그런데
     · 서버(verifySubApsan)는 **지금 방장**의 영수증만 받는다
     · 앱은 **방장 폰에서만** 스토어 소식을 듣는다(Billing.shouldListen)
   그래서 넘긴 뒤에는 갱신 영수증이 아무 데로도 안 들어가, 옛 방장은 계속 돈을 내는데
   끝나는 날 + 사흘 뒤 모임이 잠긴다. 새 방장은 「구매 복원」해도 자기 계정이라 되살릴 게 없다.
   → 넘기기 전에 이 사실을 알려야 한다(새 방장 결제 + 내 정기결제 해지). */
void main() {
  final st = AppState.i;
  final future = DateTime.now().add(const Duration(days: 20)).millisecondsSinceEpoch;

  void club(Map<String, dynamic> extra) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': 'owner'},
        'u2': {'uid': 'u2', 'name': '을', 'role': 'admin'},
      },
      ...extra,
    });
  }

  tearDown(() {
    st.setCouple({});
    st.profile = null;
  });

  test('내가 내고 있는 이용권이 살아 있으면 넘기기 전에 알린다', () {
    club({'paidUntil': future, 'subBy': 'me'});
    final n = Fee.handoverNote();
    expect(n, contains('새 방장'));
    expect(n, contains('해지'));
  });

  test('결제한 사람이 적혀 있지 않은 옛 자료도 방장이 낸 것으로 본다', () {
    club({'paidUntil': future});
    expect(Fee.handoverNote(), isNotEmpty);
  });

  test('면제 모임·끝난 이용권·남이 낸 이용권이면 말하지 않는다', () {
    club({'free': true, 'paidUntil': future});
    expect(Fee.handoverNote(), isEmpty);
    club({'paidUntil': DateTime.now().subtract(const Duration(days: 9)).millisecondsSinceEpoch});
    expect(Fee.handoverNote(), isEmpty);
    club({});
    expect(Fee.handoverNote(), isEmpty);
    club({'paidUntil': future, 'subBy': 'someone'});
    expect(Fee.handoverNote(), isEmpty);
  });

  test('방장 넘기기 확인창이 그 말을 싣는다', () {
    final s = File('lib/ui/members.dart').readAsStringSync();
    final at = s.indexOf('Future<void> _handOver(');
    final body = s.substring(at, s.indexOf('confirmSheet(', at) + 400);
    expect(body, contains('Fee.handoverNote()'));
  });
}
