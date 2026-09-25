import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 👀 체험 모드에서 읽은 흔적이 «진짜 모임»으로 따라가면 안 된다. (2026-09-26 조사)
   체험 대화방을 보면 이 폰에 「어디까지 봤다」(지금 시각쯤)가 적힌다. 나가기가 그걸 안 지워서,
   곧바로 진짜 모임에 가입하면 그 모임의 그전 대화가 전부 «읽음»으로 잡혀 안 읽음 배지가 0이었다.
   (가입 없이 둘러보기 → 가입은 새 회원이 가장 흔히 밟는 길이다) */
void main() {
  test('체험 나가기가 이 폰의 읽음 표시를 지운다', () async {
    SharedPreferences.setMockInitialValues({});
    await Store.i.loadPrefsForTest();
    Demo.start();
    AppState.i.lastSeenChat = DateTime.now().millisecondsSinceEpoch;
    AppState.i.lastSeenStaff = DateTime.now().millisecondsSinceEpoch;
    Demo.stop();
    expect(Store.i.getInt('club_seenchat'), 0, reason: '진짜 모임의 옛 대화가 전부 읽음이 된다');
    expect(Store.i.getInt('club_seenchat_staff'), 0);
    expect(Store.i.getInt('club_seendiary'), 0);
  });
}
