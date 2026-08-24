// 서버 확인이 «영영 안 올 때» 화면이 멈추지 않는지.
// Firestore 쓰기는 서버가 받았다고 알려줄 때까지 안 끝난다 — 신호가 약하면 그 기다림이 안 끝나고,
// 저장 창이 「저장 중…」인 채로 멈춘다. 회원은 안 된 줄 알고 다시 눌러 같은 기록이 두 번 들어간다.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

/// [from] 뒤 첫 '{' 부터 짝이 맞는 '}' 까지 — 글자 수로 창을 잡으면 주석 길이에 흔들린다.
String blockAt(String src, int from) {
  final open = src.indexOf('{', from);
  if (open < 0) return '';
  var d = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '{') d++;
    if (src[i] == '}') {
      d--;
      if (d == 0) return src.substring(from, i + 1);
    }
  }
  return src.substring(from);
}

void main() {
  test('서버가 영영 답이 없어도 «기다리다 멈추지» 않는다', () async {
    final never = Completer<void>().future; // 연결이 끊긴 상태를 흉내
    final sw = Stopwatch()..start();
    final ok = await Store.settle(() => never, '시험');
    sw.stop();
    expect(ok, isTrue,
        reason: '자료는 기기에 쌓였다가 연결되면 스스로 간다 — 「맡겼다」로 보고 화면을 진행시킨다');
    expect(sw.elapsed.inSeconds, lessThan(12), reason: '영영 기다리면 저장 창이 안 닫힌다');
  });

  test('서버가 곧바로 받아주면 그대로 성공', () async {
    expect(await Store.settle(() => Future<void>.value(), '시험'), isTrue);
  });

  test('서버가 «거절»하면 실패로 알린다', () async {
    expect(await Store.settle(() => Future<void>.error(StateError('permission-denied')), '시험'), isFalse,
        reason: '거절은 다시 보내도 소용없다 — 「저장했어요」라고 하면 안 된다');
  });

  test('사진은 «다시 안 묻게» 캐시 설정을 달고 올린다', () {
    // 없으면 볼 때마다 서버에 「바뀌었나요」를 다시 묻는다 — 사진 수 × 보는 사람 수만큼
    final src = File('lib/store.dart').readAsStringSync();
    expect(src.contains('cacheControl'), isTrue);
    expect(src.contains('immutable'), isTrue);
  });

  test('대기줄이 가득 차 버릴 때 조용히 넘어가지 않는다', () {
    // 조용히 버리면 안 지워진 사진이 매달 요금으로 쌓이는데 아무도 모른다
    final src = File('lib/store.dart').readAsStringSync();
    expect(src.contains('대기줄이 가득 차서'), isTrue);
  });

  group('거절은 그대로 던진다 (settleVoid)', () {
    // 화면들이 try/catch 로 실패를 잡고 있다 — 여기서 조용히 삼키면 «실패가 아무 말 없이» 지나간다
    test('서버가 거절하면 던진다', () {
      expect(Store.settleVoid(() => Future<void>.error(StateError('permission-denied')), '시험'),
          throwsA(isA<StateError>()));
    });

    test('서버가 영영 답이 없으면 «조용히 끝낸다» (기다리다 멈추지 않는다)', () async {
      final sw = Stopwatch()..start();
      await Store.settleVoid(() => Completer<void>().future, '시험');
      sw.stop();
      expect(sw.elapsed.inSeconds, lessThan(12),
          reason: '가입 신청·승인·테마 바꾸기가 여기서 멈추면 화면이 잠긴다');
    });

    test('곧바로 받아주면 그대로 끝난다', () async {
      await Store.settleVoid(() => Future<void>.value(), '시험');
    });
  });

  test('모임 문서를 고치는 길이 모두 매듭을 거친다', () {
    /* 오프라인에서 이 길들이 안 끝나면 가입 신청 화면이 「신청 중…」인 채로 잠기고,
       회원은 신청됐는지 알 수 없어 다시 눌러 같은 신청을 또 보낸다. */
    final src = File('lib/store.dart').readAsStringSync();
    for (final name in ['setCouple', 'updateItem']) {
      final at = src.indexOf('> $name(');
      expect(at, greaterThan(0), reason: '$name 을 못 찾았다');
      expect(src.substring(at, at + 320).contains('settleVoid'), isTrue,
          reason: '$name 이 매듭을 안 거친다');
    }
    final pc = src.indexOf('patchCouple(String code');
    expect(src.substring(pc, pc + 900).contains('settleVoid'), isTrue);
    // 사진 지우기도 답이 없으면 매듭 — 안 그러면 대기줄이 첫 장에서 영영 멈춘다
    final dp = src.indexOf('Future<bool> deletePhoto');
    expect(src.substring(dp, dp + 900).contains('Future.any'), isTrue);
  });

  test('알림 준비가 «거절돼도» 오류가 새어 나가지 않는다', () {
    /* 알림 토큰은 «그 방 회원»만 적을 수 있어 **승인 전이면 서버가 거절한다**(29회차에 확인).
       그런데 이 자리는 앱을 켤 때마다 저절로 불려서(setupIfAllowed),
       감싸지 않으면 대기 중인 회원에게서 «아무도 안 받는 오류»가 계속 샌다.
       화면 쪽 부르는 곳들도 그 오류에 걸려 안내 문구조차 못 띄운다. */
    /* ⚠️ 「몇 글자 뒤까지」로 창을 잡으면 안 된다 — 주석 몇 줄만 늘어나도 찾던 줄이
       창 밖으로 밀려나 **고친 것이 없는데 시험이 깨진다**(119회차에 실제로 겪었다).
       중괄호를 짝 맞춰 «그 덩어리»만 읽는다. */
    final src = File('lib/push.dart').readAsStringSync();
    final at = src.indexOf("if (cur?['token'] != token)");
    expect(at, greaterThan(0));
    final body = blockAt(src, at);
    expect(body.contains('try {'), isTrue, reason: '거절을 받아 내야 한다');
    expect(body.contains('return false;'), isTrue, reason: '못 적었으면 «안 됐다»고 돌려줘야 한다');

    // 토큰이 갱신될 때 도는 자리(뒤에서 도는 자리)도 마찬가지
    final at2 = src.indexOf('onTokenRefresh.listen');
    expect(at2, greaterThan(0));
    expect(blockAt(src, at2).contains('try {'), isTrue);
  });
}
