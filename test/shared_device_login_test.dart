import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/ui/onboarding.dart';

/* 👥 한 폰(태블릿)을 가족이 같이 쓸 때 — 로그아웃 뒤 «다른 사람»이 로그인하면 그 사람 자리로.

   2026-09-25 조사: 로그아웃은 이 폰의 로그인 번호를 안 바꾼다. 로그인은 «이 번호가 회원이면
   바로 들어간다»를 이름·생년월일보다 먼저 봐서, 남편이 로그아웃한 태블릿에서 아내가 자기 이름으로
   로그인하면 「다시 만나서 반가워요」와 함께 **남편 자리로 들어갔다** — 글이 남편 이름으로 올라갔고
   그 태블릿으로는 자기 자리에 영영 못 갔다. */
void main() {
  final husband = {'uid': 'u1', 'name': '김 태진', 'birth': '19800125', 'role': 'member'};

  group('같은 사람인가', () {
    test('이름·생년월일이 같으면 같은 사람 (띄어쓰기·꼴은 무시)', () {
      expect(samePerson(husband, '김태진', '1980-01-25'), isTrue);
      expect(samePerson(husband, '김 태진', '19800125'), isTrue);
    });
    test('이름이 다르면 다른 사람', () {
      expect(samePerson(husband, '이영희', '19820303'), isFalse);
    });
    test('이름이 같아도 생년월일이 다르면 다른 사람 (동명이인)', () {
      expect(samePerson(husband, '김태진', '19900101'), isFalse);
    });
    test('생년월일이 없는 옛 자리는 이름만 맞으면 같은 사람 (예전처럼 들어가게)', () {
      expect(samePerson({'name': '김태진'}, '김태진', '19800125'), isTrue);
    });
    test('자리 모양이 이상하면 같은 사람으로 치지 않는다', () {
      expect(samePerson(null, '김태진', '19800125'), isFalse);
      expect(samePerson('u1', '김태진', '19800125'), isFalse);
    });
  });

  test('«이 번호가 회원이면 바로 입장»보다 «그 자리 사람인가»를 먼저 본다', () {
    final s = File('lib/ui/onboarding.dart').readAsStringSync();
    final check = s.indexOf('!samePerson(members[uid], name, birth)');
    final enter = s.indexOf("toast(context, '다시 만나서 반가워요!");
    expect(check, greaterThan(0), reason: '적은 이름을 안 보고 이 폰 번호의 자리로 들인다');
    expect(check, lessThan(enter), reason: '바로 입장한 «뒤에» 보면 이미 늦다');
    final fresh = s.indexOf('Store.i.freshIdentity()', check);
    expect(fresh, greaterThan(check), reason: '다른 사람인데 번호를 안 바꾸면 자기 자리를 못 만든다');
  });
}
