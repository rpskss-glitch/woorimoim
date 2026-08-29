import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🏸 「모임 이름 칸은 언제나 보여준다」 + 「총괄 입구는 사라지지 않는다」.

   ⚠️ 193회차에 규칙이 **뒤집혔다.**
   예전(189회차)에는 서버에 방이 «딱 하나»면 이름 칸을 숨기고 그 방으로 자동 지정했다.
   앞산 배드민턴 한 곳만 쓰는 앱이었기 때문이다.

   이제는 **누구나 자기 모임을 만드는 앱**(스토어 판매)이다. 그대로 두면
     · 스토어에서 받은 사람이 **남의 모임**으로 자동 안내되고
     · 방이 하나뿐인 동안에는 **새 모임을 만들 이름을 적을 칸이 없다.**
   그래서 숨기지 않는다. 이 시험은 그 규칙이 되돌아오지 않게 지킨다. */
void main() {
  final onb = File('lib/ui/onboarding.dart').readAsStringSync();

  group('모임 이름 칸', () {
    test('언제나 보인다 — 「방이 하나뿐이면 숨기기」가 되살아나지 않았다', () {
      expect(onb.contains('_findSolo'), isFalse,
          reason: '방이 하나뿐일 때 칸을 숨기던 길이 되살아났다 — 남의 모임으로 안내된다');
      expect(onb.contains('_solo'), isFalse);
      expect(onb.contains("_Label('모임 이름'"), isTrue, reason: '이름 칸 자체가 없어졌다');
    });

    test('그 칸 하나로 «들어가기»와 «만들기»를 다 한다', () {
      expect(onb.contains('Future<void> _newClub()'), isTrue,
          reason: '새 모임을 만드는 길이 없으면 스토어에서 받은 사람은 쓸 수가 없다');
      final at = onb.indexOf('Future<void> _newClub()');
      final body = onb.substring(at, at + 900);
      expect(body.contains('_codeC.text.trim()'), isTrue,
          reason: '만들 이름을 «위 칸»에서 가져와야 한다 (안내 문구와 맞아야 한다)');
      expect(body.contains('findClubByTitle'), isTrue,
          reason: '이름이 겹치면 회원이 어느 방인지 못 고른다');
    });
  });

  group('총괄 입구', () {
    test('로고 5번 두드리기가 살아 있다', () {
      /* 예전에는 «모임 이름 칸에 비밀번호»가 유일한 입구였다.
         칸을 숨기는 순간 입구가 통째로 사라져서 로고 두드리기를 넣었다 —
         칸이 돌아왔어도 이 길은 남겨 둔다(총괄이 쓰던 길이다). */
      expect(onb.contains('_logoTaps'), isTrue, reason: '총괄 콘솔에 들어갈 길이 사라졌다');
      expect(onb.contains('tryAdminLogin'), isTrue);
    });

    test('모임 이름 칸의 «숨은 입구»가 그대로 있다', () {
      /* 예전에는 그 칸에 «비밀번호»를 넣었다. 이제는 «아이디»를 넣고,
         맞는지는 서버가 판단한다 — 앱에 적은 값은 설치 파일에서 그대로 읽히기 때문이다.
         입구가 있다는 사실은 그대로 지킨다(사장님이 그 길로 들어간다). */
      expect(onb.contains('tryAdminLogin(context, id:'), isTrue,
          reason: '모임 이름 칸으로 들어가는 총괄 입구가 사라졌다');
      expect(onb.contains('Cfg.adminPass'), isFalse,
          reason: '비밀번호가 앱에 남아 있다 — 설치 파일에서 그대로 읽힌다');
    });
  });
}
