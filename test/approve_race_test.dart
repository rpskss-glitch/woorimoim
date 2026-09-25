import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 🤝 운영진 둘이 같은 신청을 «동시에» 처리할 때.

   2026-09-25 조사: 승인은 화면에 남은 옛 목록만 보고 회원 자리를 통째로 덮어썼다.
     · 운영진 A 가 거절한 직후, 목록이 아직 안 바뀐 B 가 「승인」 → **거절된 사람이 회원이 됐다.**
     · 이미 승인돼 방장이 직책(총무)과 운영진 권한을 준 뒤 B 의 늦은 승인이 도착하면
       → **평회원으로, 가입일은 지금으로** 덮였다(회비 셈도 틀어진다).
   이제 서버의 지금 문서를 보고, 신청이 남아 있고 아직 회원이 아닐 때만 적는다. */
void main() {
  const now = 1790000000000;
  final p = {'uid': 'u_new', 'name': '오하늘', 'emoji': '🙂', 'birth': '19900101'};

  group('적을지 말지', () {
    test('신청이 남아 있고 아직 회원이 아니면 승인한다', () {
      final patch = Logic.approvePatch({
        'members': {'me': {'role': 'owner'}},
        'pending': {'u_new': p},
      }, p, now);
      expect(patch, isNotNull);
      final m = (patch!['members'] as Map)['u_new'] as Map;
      expect(m['role'], 'member');
      expect(m['joinedAt'], now);
      expect(m['birth'], '19900101', reason: '생년월일이 안 옮겨지면 폰 바꿀 때 이어받기가 안 된다');
      expect((patch['pending'] as Map)['u_new'], Store.del);
    });

    test('다른 운영진이 먼저 거절했으면(신청 없음) 안 적는다', () {
      expect(
          Logic.approvePatch({
            'members': {'me': {'role': 'owner'}},
            'pending': <String, dynamic>{},
          }, p, now),
          isNull,
          reason: '거절된 사람이 회원이 된다');
    });

    test('이미 회원이면 안 적는다 — 준 직책·가입일을 덮지 않는다', () {
      expect(
          Logic.approvePatch({
            'members': {
              'u_new': {'role': 'admin', 'title': '총무', 'joinedAt': now - 86400000},
            },
            'pending': {'u_new': p}, // 옛 신청 흔적이 남아 있어도
          }, p, now),
          isNull,
          reason: '총무가 평회원으로, 가입일이 오늘로 덮인다');
    });
  });

  group('실제로 겹쳐 보면', () {
    tearDown(() {
      Demo.stop();
      AppState.i.setItems([]);
    });

    test('거절이 먼저 닿으면 늦은 승인은 아무것도 안 바꾼다', () {
      Demo.start();
      final pend = Map<String, dynamic>.from(
          (AppState.i.couple!['pending'] as Map)['u_new'] as Map);
      // A 가 거절
      Demo.applyCouple((cur) => {'pending': {'u_new': Store.del}});
      // B 가 옛 화면에서 승인
      final wrote = Demo.applyCouple((cur) => Logic.approvePatch(cur, pend, now));
      expect(wrote, isFalse);
      expect((AppState.i.couple!['members'] as Map).containsKey('u_new'), isFalse,
          reason: '거절된 사람이 회원이 됐다');
    });
  });

  test('승인 단추가 이 판단을 서버 트랜잭션 안에서 쓴다', () {
    final s = File('lib/ui/members.dart').readAsStringSync();
    final at = s.indexOf('Future<void> _approve(');
    final body = s.substring(at, s.indexOf('Future<void> _reject(', at));
    expect(body, contains('Store.i.mutateCouple('));
    expect(body, contains('Logic.approvePatch(cur, p,'));
    expect(body.contains("'members.\$uid': {"), isFalse,
        reason: '옛 목록만 보고 통째로 덮어쓰는 길이 남아 있다');
  });
}
