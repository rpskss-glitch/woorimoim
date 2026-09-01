import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🏸 「지금은 앞산 배드민턴으로만 쓴다」 + 「로그인하기」. */
void main() {
  group('기본 갈래는 앞산', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    test('갈래를 안 적고 만들면 앞산이 나온다', () {
      /* 갈래를 빠뜨리면 예전에는 판매용 「우리 모임」이 나와,
         회원에게 **엉뚱한 이름의 앱**이 갈 뻔했다. */
      final apsan = gradle.indexOf('create("apsan")');
      final woori = gradle.indexOf('create("woori")');
      expect(apsan, greaterThan(0));
      expect(woori, greaterThan(0));
      final block = gradle.substring(apsan, gradle.indexOf('}', apsan));
      expect(block.contains('isDefault = true'), isTrue,
          reason: '갈래를 안 적으면 이것이 나와야 한다');
      final wblock = gradle.substring(woori, gradle.indexOf('}', woori));
      expect(wblock.contains('isDefault = true'), isFalse,
          reason: '판매용이 기본이면 회원에게 엉뚱한 이름이 간다');
    });

    test('꾸러미 이름 기본값도 앞산이다', () {
      final at = gradle.indexOf('defaultConfig {');
      expect(at, greaterThan(0));
      expect(gradle.substring(at, at + 200).contains('com.taejinsoft.apsanclub'), isTrue);
    });

    test('꾸러미 이름을 «못 읽었을 때»도 앞산으로 본다', () {
      /* 판매용으로 되돌리면 앞산 회원 폰에서 이름을 못 읽었을 때
         엉뚱한 Firebase 열쇠로 등록해 **알림이 아예 안 온다.** */
      final cfg = File('lib/config.dart').readAsStringSync();
      final at = cfg.indexOf('} catch (_) {');
      expect(at, greaterThan(0));
      expect(cfg.substring(at, at + 300).contains('_package = _apsanPackage;'), isTrue,
          reason: '못 읽으면 앞산으로 봐야 한다');
    });

    test('판매용 갈래는 «지우지 않았다»', () {
      expect(gradle.contains('우리 모임'), isTrue,
          reason: '나중에 팔 때 --flavor woori 로 그대로 쓴다');
    });
  });

  group('로그인하기', () {
    final onb = File('lib/ui/onboarding.dart').readAsStringSync();

    test('가입 신청 «밑»에 로그인 단추가 있다', () {
      final join = onb.indexOf('가입 신청하기');
      final login = onb.indexOf('로그인하기');
      expect(join, greaterThan(0));
      expect(login, greaterThan(0));
      expect(login, greaterThan(join), reason: '가입 신청 밑에 있어야 한다');
    });

    test('로그인으로는 «방장이 되지 않는다»', () {
      /* 로그인은 «들어가기»다. 빈 모임에 코드로 들어왔다고 방장을 만들어 버리면,
         남의 모임 이름을 눌러 본 사람이 방장이 된다. */
      final at = onb.indexOf('if (empty && viaCode');
      expect(at, greaterThan(0));
      expect(onb.substring(at, at + 60).contains('!loginOnly'), isTrue,
          reason: '로그인은 방장 자리를 만들면 안 된다');
    });

    test('로그인은 «가입 신청을 만들지 않는다»', () {
      /* 만들어 버리면 「로그인」을 눌렀는데 승인 대기 화면에 놓여,
         회원은 자기가 이미 가입된 줄 알고 오지 않을 승인을 계속 기다린다. */
      final guard = onb.indexOf('if (loginOnly) {');
      /* ⚠️ `'pending'` 으로 찾으면 «이어받기» 안의 `'pending': {uid: Store.del}` 이
         먼저 잡힌다 — 그건 신청을 보내는 자리가 아니다.
         신청에만 있는 표시(`requestedAt`)로 찾는다. */
      final send = onb.indexOf("'requestedAt'");
      expect(guard, greaterThan(0), reason: '로그인 갈래가 없다');
      expect(send, greaterThan(0));
      expect(guard, lessThan(send), reason: '신청을 보내기 «전»에 돌아가야 한다');
      final body = onb.substring(guard, send);
      expect(body.contains('return;'), isTrue);
    });

    test('왜 안 됐는지 «구분해서» 말해 준다', () {
      /* 한 마디로 뭉뚱그리면 이름을 잘못 적은 것인지, 생년월일이 틀린 것인지,
         아직 승인이 안 난 것인지 회원이 알 길이 없다.
         ⚠️ 관문은 **두 곳**이다 — 같은 이름이 있을 때(이어받기 실패)와 아예 없을 때.
            한 곳만 보면 다른 곳이 사라져도 모른다. */
      final gates = RegExp(r'if \(loginOnly\) \{').allMatches(onb).toList();
      expect(gates.length, 2, reason: '로그인 관문이 두 곳이라야 한다');
      final all = gates.map((m) => onb.substring(m.start, m.start + 900)).join();
      expect(all.contains('아직 승인 전'), isTrue, reason: '승인 대기 중인 경우');
      expect(all.contains('생년월일이 달라요'), isTrue, reason: '생년월일이 다른 경우');
      expect(all.contains('생년월일이 없어'), isTrue, reason: '생년월일이 아예 없는 옛 자리');
      expect(all.contains('등록된 회원이 없어요'), isTrue, reason: '아예 없는 경우');
      expect(all.contains('가입 신청하기'), isTrue, reason: '어디를 누를지 알려준다');
    });

    test('이어받기가 안 되면 «가입용 안내»로 새지 않는다', () {
      /* 실제로 그랬다 — 로그인을 눌렀는데
         「아바타가 똑같아요 — 다시 신청해주세요」가 떴다 (2026-08-24 브라우저로 확인).
         관문이 아바타 검사보다 «앞»에 있어야 한다. */
      final gate = onb.indexOf('if (loginOnly) {');
      final clash = onb.indexOf('Logic.avatarClash');
      expect(gate, greaterThan(0));
      expect(clash, greaterThan(0));
      expect(gate, lessThan(clash), reason: '아바타 검사보다 앞에서 끝나야 한다');
    });
  });
}
