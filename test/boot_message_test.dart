import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 📶 앱이 못 섰을 때 회원에게 하는 말.

   2026-08-29 에뮬에서 확인: 인터넷은 멀쩡했다(ping 이 오갔다). 그런데
   파이어스토어 응답이 시작 한계(15초)를 넘겨 「인터넷 연결이 필요해요」가 떴다.

   모임 앱이 쓰이는 곳은 지하 체육관·시골 운동장이라 «되긴 되는데 느린» 망이 흔하다.
   그때 없는 까닭을 단정하면, 회원은 멀쩡한 와이파이를 껐다 켜며 헤매다
   「앱이 고장났다」고 결론짓는다. 안 된 건 안 됐다고 하되 까닭은 넘겨짚지 않는다. */
void main() {
  final main = File('lib/main.dart').readAsStringSync();

  test('못 선 까닭을 «인터넷 없음»으로 단정하지 않는다', () {
    expect(main.contains('인터넷 연결이 필요해요'), isFalse,
        reason: '인터넷이 되는데도 없다고 말한다 — 회원이 엉뚱한 곳을 고치려 든다');
    expect(main.contains('모임 정보를 받지 못했어요'), isTrue,
        reason: '무엇이 안 됐는지는 말해야 한다');
  });

  test('무엇을 해보라고 «알려준다»', () {
    // 안내만 하고 길을 안 주면 그 화면에 갇힌다
    expect(main.contains('연결을 확인한 뒤 아래를 눌러주세요'), isTrue);
    expect(main.contains('다시 시도'), isTrue, reason: '되돌아갈 단추가 없으면 앱을 지우게 된다');
  });

  test('시작 한계가 남아 있다 — 흰 화면으로 굳지 않게', () {
    /* 이 한계가 없으면 «응답이 오지 않는» 망에서 Firebase 가 던지지도 끝나지도 않아
       runApp 이 영영 안 불린다 = 흰 화면. 애플 심사장이 그런 망 뒤에 있는 일이 잦아
       2.1(미완성) 반려로 이어진다. */
    expect(RegExp(r'_bootLimit = Duration\(seconds: \d+\)').hasMatch(main), isTrue,
        reason: '시작 시각 지킴이가 사라졌다 — 느린 망에서 흰 화면으로 굳는다');
  });

  test('「다시 시도」는 처음보다 **더 오래** 기다린다', () {
    /* 2026-08-29 확인: 15초를 못 지킨 망에서 「다시 시도」를 눌러도
       또 15초 만에 접었다. 느린 망(지하 체육관·시골 운동장)에서는
       아무리 눌러도 영영 못 들어가 — 할 수 있는 게 «앱 지우기»밖에 안 남는다.
       첫 번을 짧게 두는 건 흰 화면을 막기 위해서지 «빨리 포기하려고»가 아니다. */
    final m = RegExp(r'_bootLimit = Duration\(seconds: (\d+)\)').firstMatch(main);
    final r = RegExp(r'_retryLimit = Duration\(seconds: (\d+)\)').firstMatch(main);
    expect(m, isNotNull);
    expect(r, isNotNull, reason: '다시 시도에 따로 된 한계가 없다');
    final first = int.parse(m!.group(1)!), retry = int.parse(r!.group(1)!);
    expect(retry, greaterThan(first),
        reason: '다시 시도가 첫 번과 같은 시간이면 느린 망에서는 영영 못 들어간다');
    expect(main.contains('bootstrap(limit: _retryLimit)'), isTrue,
        reason: '한계를 만들어 두고 단추가 안 쓰고 있다');
  });
}
