import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 🔒 운영진 방의 «안 읽음» — 모두의 방과 따로 센다. (2026-09-26 조사)
   이 폰의 「어디까지 봤다」가 방 구분 없이 «하나»였다. 운영진이 모두의 방을 열면
   그 방의 최신 시각이 적혀, 그보다 먼저 온 운영진 방 말까지 «읽음»이 되어 배지에서 사라졌다.
   게다가 방 단추에 새 말 표시가 없어 운영진 방에 말이 온 줄을 몰랐다. */
void main() {
  final st = AppState.i;
  final t0 = DateTime(2026, 9, 1).millisecondsSinceEpoch; // 1970년 값은 다듬기가 버린다
  setUp(() {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': 'admin'},
        'o': {'uid': 'o', 'name': '남', 'role': 'owner'},
      },
    });
    st.setItems(Store.tidy([
      {'id': 's1', 'type': 'msg', 'by': 'o', 'text': '운영진 말', 'room': 'staff', 'createdAt': t0 + 100},
      {'id': 'p1', 'type': 'msg', 'by': 'o', 'text': '모두 말', 'createdAt': t0 + 200},
      {'id': 'p2', 'type': 'msg', 'by': 'me', 'text': '내 말', 'createdAt': t0 + 300},
    ]));
  });

  test('방마다 따로 센다 — 모두의 방을 다 봤어도 운영진 방 말은 안 읽음', () {
    expect(Logic.unreadChat(room: '', seen: t0 + 200, myUid: 'me'), 0);
    expect(Logic.unreadChat(room: 'staff', seen: 0, myUid: 'me'), 1);
    expect(Logic.unreadChat(room: 'staff', seen: t0 + 100, myUid: 'me'), 0);
  });

  test('이 폰의 읽음 시각이 방마다 따로 있고, 모임을 나가면 함께 지운다', () {
    final s = File('lib/state.dart').readAsStringSync();
    expect(s, contains("'club_seenchat_staff'"));
    final clear = s.substring(s.indexOf('Future<void> clearProfile('));
    expect(clear.substring(0, clear.indexOf('notifyListeners')), contains("'club_seenchat_staff'"));
  });

  test('채팅은 보고 있는 방의 시각만 올리고, 방 단추에 다른 방 안 읽음을 보인다', () {
    final c = File('lib/ui/chat.dart').readAsStringSync();
    expect(c, contains('st.lastSeenStaff'));
    expect(c, contains("Logic.unreadChat(room: 'staff'"));
    final sh = File('lib/ui/shell.dart').readAsStringSync();
    expect(sh, contains('Logic.unreadChat('));
  });
  /* ⚠️ 39회차 내 실수(2026-09-26 다시 잡음): 운영진 방 값이 비었을 때 모두의 방 값을 «매번» 빌려 와,
     운영진 방을 한 번도 안 연 운영진은 모두의 방을 읽는 족족 운영진 방 말까지 읽음이 됐다(고치기 전과 똑같이).
     → 한 번만 옮겨 적고, 그 뒤로는 따로 간다. */
  test('운영진 방 값은 «한 번만» 모두의 방 값에서 시작하고, 그 뒤로 따라가지 않는다', () async {
    SharedPreferences.setMockInitialValues({'club_seenchat': t0 + 50});
    await Store.i.loadPrefsForTest();
    expect(st.lastSeenStaff, t0 + 50, reason: '업데이트 직후엔 모두의 방 값에서 시작');
    st.lastSeenChat = t0 + 999; // 모두의 방을 더 읽었다
    expect(st.lastSeenStaff, t0 + 50, reason: '모두의 방을 읽었다고 운영진 방까지 따라가면 안 된다');
    expect(Logic.unreadChat(room: 'staff', seen: st.lastSeenStaff, myUid: 'me'), 1);
  });
}
