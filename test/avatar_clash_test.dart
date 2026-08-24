// 같은 이름·같은 아바타 막기 (131회차).
//
// 같은 이름에 아바타까지 같으면 채팅·출석·순위 어디서도 누가 누군지 구분이 안 된다.
// 가입 화면은 «맨 앞 한 사람»만 보고 있었다 — 같은 이름이 여럿일 때
// 생년월일로 골라 낸 사람은 아바타가 다르고, 정작 «다른» 동명이인과 겹칠 수 있다.
// (설정의 「내 정보 고치기」는 처음부터 전부 훑었다 — 두 곳이 어긋나 있었다)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

Map<String, dynamic> p(String uid, String name,
        {String? emoji, String? birth, String? photo}) =>
    {'uid': uid, 'name': name, 'emoji': emoji, 'birth': birth, 'photo': photo};

void main() {
  test('같은 이름이 여럿이면 «전부» 훑는다 (재현)', () {
    /* 갑(1990-01-01, 🐶) 과 갑(생일 없음, 🏸) 이 있고,
       내가 갑·1985-05-05·🏸 로 들어온다.
       옛 코드는 생일이 맞는 사람이 없어 «맨 앞»(🐶)만 보고 그냥 통과시켰다. */
    final members = [
      p('u1', '갑', emoji: '🐶', birth: '1990-01-01'),
      p('u2', '갑', emoji: '🏸'),
    ];
    expect(members.first['emoji'], '🐶', reason: '맨 앞 사람은 안 겹친다 — 그래서 놓쳤다');
    final clash = Logic.avatarClash(members, '갑', '🏸');
    expect(clash?['uid'], 'u2');
  });

  test('이름이 다르면 아바타가 같아도 괜찮다', () {
    final members = [p('u1', '을', emoji: '🏸')];
    expect(Logic.avatarClash(members, '갑', '🏸'), isNull);
  });

  test('띄어쓰기·대소문자가 달라도 같은 이름으로 본다', () {
    final members = [p('u1', ' 김 갑 ', emoji: '🏸')];
    expect(Logic.avatarClash(members, '김갑', '🏸'), isNotNull);
  });

  test('사진 아바타는 그 자체로 구분되니 겹침이 아니다', () {
    final members = [p('u1', '갑', emoji: '🏸', photo: 'st:c/x')];
    expect(Logic.avatarClash(members, '갑', '🏸'), isNull);
  });

  test('아바타가 안 적힌 사람은 기본 🏸 로 본다', () {
    final members = [p('u1', '갑')];
    expect(Logic.avatarClash(members, '갑', '🏸'), isNotNull);
    expect(Logic.avatarClash(members, '갑', '🐶'), isNull);
  });

  test('나 자신과는 안 겹친다', () {
    final members = [p('u1', '갑', emoji: '🏸')];
    expect(Logic.avatarClash(members, '갑', '🏸', skipUid: 'u1'), isNull);
  });

  test('가입 화면과 설정 화면이 «같은 문»을 쓴다', () {
    for (final f in ['lib/ui/onboarding.dart', 'lib/ui/settings.dart']) {
      final code = stripComments(File(f).readAsStringSync());
      expect(code.contains('Logic.avatarClash('), isTrue, reason: '$f 이 제 나름대로 본다');
    }
    final on = stripComments(File('lib/ui/onboarding.dart').readAsStringSync());
    expect(on.contains('bool sameAva('), isFalse,
        reason: '한 사람만 보던 옛 검사가 돌아왔다');
  });
}
