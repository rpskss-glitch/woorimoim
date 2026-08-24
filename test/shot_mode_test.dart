import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 📸 스토어 스크린샷 모드의 «스위치가 실제로 켜지는지».

   2026-08-25 한 판 통째로(45분) 날렸다: 워크플로가 `--dart-define=SHOTS=1` 로 주었는데
   `bool.fromEnvironment` 는 **«true» 라는 글자만** 참으로 읽는다. 그래서 체험 모드가 안 켜졌고,
   다섯 장이 전부 «가입 화면»으로 똑같이 찍혔다(파일 크기까지 같았다).
   화면을 열어 보기 전에는 «찍혔다»는 것만 보여 성공처럼 보인다 — 그래서 여기서 못 박는다. */
void main() {
  test('워크플로가 넘기는 값과 앱이 읽는 이름이 맞다', () {
    final yml = File('.github/workflows/ios.yml').readAsStringSync();
    final src = File('lib/main.dart').readAsStringSync();

    final name = RegExp(r"bool\.fromEnvironment\('([^']+)'\)").firstMatch(src)?.group(1);
    expect(name, isNotNull, reason: '앱에서 스크린샷 스위치를 못 찾았다');

    final given = RegExp(r'--dart-define=(\w+)=(\S+)').firstMatch(yml);
    expect(given, isNotNull, reason: '워크플로가 스위치를 안 넘긴다');
    expect(given!.group(1), name, reason: '이름이 서로 다르다 — 스위치가 안 켜진다');
    expect(given.group(2), 'true',
        reason: "«${given.group(2)}» 로는 안 켜진다 — bool.fromEnvironment 는 «true» 만 참으로 읽는다");
  });
}
