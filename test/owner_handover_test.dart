import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

/* 👑 「방장이 나가면 다음 방장이 자동으로 선다」

   사장님이 정한 차례 그대로:
     ① 직책 「회장」 → ② 「총무」 → ③ 「부회장」 → ④ 나머지 회원
     같은 칸에 여럿이면 **먼저 가입한 사람**(joinedAt).

   예전에는 방장이 직접 넘겨주기 전에는 탈퇴를 막았다 — 그 화면을 못 찾는 방장은
   앱을 지우는 걸로 «해결»했고, 방은 주인 없는 채로 남았다. */
void main() {
  Map<String, dynamic> m(String uid, {String? title, int? joined, String role = 'member'}) => {
        'uid': uid,
        'name': uid,
        'role': role,
        if (title != null) 'title': title,
        if (joined != null) 'joinedAt': joined,
      };

  test('회장이 있으면 회장에게 간다 — 총무·부회장보다 먼저', () {
    final members = {
      'owner': m('owner', role: 'owner', joined: 1),
      'chong': m('chong', title: '총무', joined: 2),
      'bu': m('bu', title: '부회장', joined: 3),
      'hoe': m('hoe', title: '회장', joined: 9), // 늦게 가입했어도 회장이 먼저
    };
    expect(Logic.nextOwnerUid(members, 'owner'), 'hoe');
  });

  test('회장이 없으면 총무 → 부회장 → 일반 순', () {
    expect(
        Logic.nextOwnerUid({
          'owner': m('owner', role: 'owner'),
          'bu': m('bu', title: '부회장', joined: 1),
          'chong': m('chong', title: '총무', joined: 5),
        }, 'owner'),
        'chong');
    expect(
        Logic.nextOwnerUid({
          'owner': m('owner', role: 'owner'),
          'plain': m('plain', joined: 1),
          'bu': m('bu', title: '부회장', joined: 9),
        }, 'owner'),
        'bu');
  });

  test('같은 직책이 여럿이면 먼저 가입한 사람', () {
    expect(
        Logic.nextOwnerUid({
          'owner': m('owner', role: 'owner'),
          'h2': m('h2', title: '회장', joined: 20),
          'h1': m('h1', title: '회장', joined: 10),
        }, 'owner'),
        'h1');
    // 일반 회원끼리도 가입 순
    expect(
        Logic.nextOwnerUid({
          'owner': m('owner', role: 'owner'),
          'b': m('b', joined: 200),
          'a': m('a', joined: 100),
        }, 'owner'),
        'a');
  });

  test('가입일이 없는 옛 회원은 뒤로 — 있는 사람이 먼저다', () {
    expect(
        Logic.nextOwnerUid({
          'owner': m('owner', role: 'owner'),
          'old': m('old'), // joinedAt 없음
          'new': m('new', joined: 999),
        }, 'owner'),
        'new');
  });

  test('운영진(role)이라도 직책이 없으면 ④다 — 직책 순서가 우선', () {
    expect(
        Logic.nextOwnerUid({
          'owner': m('owner', role: 'owner'),
          'adm': m('adm', role: 'admin', joined: 1),
          'bu': m('bu', title: '부회장', joined: 9),
        }, 'owner'),
        'bu');
  });

  test('나 혼자면 넘길 사람이 없다 — 망가진 자리도 세지 않는다', () {
    expect(Logic.nextOwnerUid({'owner': m('owner', role: 'owner')}, 'owner'), isNull);
    expect(
        Logic.nextOwnerUid({
          'owner': m('owner', role: 'owner'),
          'ghost': {'name': '유령'}, // uid 없는 망가진 자리
          'blank': '글자', // 맵도 아닌 값
        }, 'owner'),
        isNull);
  });

  group('탈퇴와 «한 몸»인가 (모양 검사)', () {
    final store = File('lib/store.dart').readAsStringSync();
    final at = store.indexOf('Future<bool> deleteMyData');
    final body = store.substring(at, store.indexOf('\n  Future<', at + 10));

    test('승격이 탈퇴와 같은 트랜잭션에 있다', () {
      /* 따로 두 번 쓰면 첫 쓰기와 둘째 쓰기 사이 방이 주인 없는 채로 보이고,
         그 사이 누가 나가면 없는 사람을 방장으로 세운다. */
      expect(body.contains('mutateCouple'), isTrue,
          reason: '탈퇴가 트랜잭션이 아니다 — 승계가 찢어질 수 있다');
      expect(body.contains('nextOwnerUid'), isTrue,
          reason: '탈퇴에서 다음 방장을 세우지 않는다 — 방이 주인 없는 채로 남는다');
    });

    test('탈퇴 안내가 «누구에게 넘어가는지» 미리 말한다', () {
      final settings = File('lib/ui/settings.dart').readAsStringSync();
      expect(settings.contains('자동으로 넘어가요'), isTrue,
          reason: '방장이 모르는 채 넘어간다 — 누르기 전에 알려야 한다');
      // 옛 「먼저 넘겨주세요」 막기는 없어야 한다
      expect(settings.contains('방장은 먼저 👑 방장을 넘겨주세요'), isFalse,
          reason: '탈퇴를 도로 막고 있다');
    });
  });
}
