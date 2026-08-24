// 어떤 화면을 보여줄지 — 「텅 빈 모임」과 「말없이 나가기」를 막는 두 자리.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('모임 문서가 아직 안 왔으면 본 화면 대신 «불러오는 중»', () {
    /* 그대로 본 화면을 그리면 회원 0명·통장 0원인 텅 빈 모임이 잠깐 보여
       「내 모임이 사라졌나」로 읽힌다. 처음 깐 폰·느린 연결에서는 몇 초 간다. */
    final src = File('lib/main.dart').readAsStringSync();
    final at = src.indexOf('if (st.code == null)');
    expect(at, greaterThan(0));
    final body = src.substring(at, at + 900);
    final loading = body.indexOf('_LoadingScreen');
    final shell = body.indexOf('ShellScreen(onTouch');
    expect(loading, greaterThan(0), reason: '기다리는 화면이 있어야 한다');
    expect(loading, lessThan(shell), reason: '본 화면보다 «먼저» 걸러야 한다');
    expect(body.contains('st.couple == null'), isTrue);
  });

  test('가입 신청 취소가 실패하면 말없이 나가지 않는다', () {
    /* 서버에는 신청이 그대로 남아 있는데 화면만 가입 화면으로 돌아가면,
       방장에게는 취소한 사람의 신청이 계속 보이고 회원은 취소된 줄 안다. */
    final src = File('lib/ui/wait.dart').readAsStringSync();
    final at = src.indexOf('pending.');
    expect(at, greaterThan(0));
    final body = src.substring(at, at + 500);
    expect(body.contains('취소하지 못했어요'), isTrue);
    // 실패했으면 프로필을 지우지 않고 이 화면에 머물러야 한다
    final fail = src.indexOf('취소하지 못했어요');
    final clear = src.indexOf('clearProfile');
    expect(fail, lessThan(clear), reason: '실패를 알린 뒤 «돌아가야» 한다');
    expect(src.substring(fail - 200, fail).contains('return'), isTrue);
  });

  test('«불러오는 중» 화면에 갇히지 않는다', () {
    /* 구독이 오류로 끝나면(권한·색인·연결) 알려주는 값이 영영 안 와서
       이 화면이 그대로 남는다 — 회원은 앱이 죽은 줄 안다. */
    final src = File('lib/main.dart').readAsStringSync();
    final at = src.indexOf('class _LoadingScreenState');
    expect(at, greaterThan(0), reason: '기다리다 안내를 바꾸려면 상태가 있어야 한다');
    final body = src.substring(at);
    expect(body.contains('오래 걸려요'), isTrue, reason: '오래 걸리면 그렇다고 말해야 한다');
    expect(body.contains('다시 시도'), isTrue, reason: '다시 걸어 볼 길이 있어야 한다');
    expect(body.contains('가입 화면으로'), isTrue, reason: '빠져나갈 길이 있어야 한다');
    expect(body.contains('clearProfile'), isTrue);
  });

  test('회원 폰에 «방장 코드»를 적어 두지 않는다', () {
    /* 모임 코드는 방장 코드다 — 빈 방에 그 코드로 처음 들어오는 사람이 방장이 된다.
       예전에는 그것을 기기에 적어 두고 가입 화면의 「모임 이름」 칸에 그대로 채웠다. */
    final st = File('lib/state.dart').readAsStringSync();
    final at = st.indexOf('Future<void> saveLastMe');
    expect(at, greaterThan(0));
    final body = st.substring(at, at + 500);
    expect(body.contains('String? club'), isTrue, reason: '이름을 적어야 한다');
    expect(body.contains("'code':"), isFalse, reason: '코드를 적으면 안 된다');

    final ob = File('lib/ui/onboarding.dart').readAsStringSync();
    expect(ob.contains("last['code']"), isFalse, reason: '가입 화면에 코드를 채우면 안 된다');
    expect(ob.contains("last['club']"), isTrue);
  });
}
