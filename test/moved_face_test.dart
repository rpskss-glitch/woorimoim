import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';

/* 📱➡📱 폰을 바꾼 회원의 옛 대화·글이 «옛 얼굴»로 보였다 (2026-09-26 80회차).

   폰을 바꾸면 옛 번호는 「나간 기록(former)」으로 옮겨지고 `movedTo` 에 새 번호가 적힌다.
   회비·출석·차단·투표는 `Logic.liveUid` 로 옛 번호를 지금 번호로 이어 보는데,
   **이름·얼굴(nameOf·emojiOf·photoOf)만** 옛 번호를 그대로 찾았다 →
     · 넣어 둔 얼굴 사진이 옛 대화에서 안 나온다(나간 기록에는 사진이 없다)
     · 그 뒤 이름·아바타를 바꿨어도 옛 글에는 옛 것이 보인다
     · 같은 이름 가리기(listName)가 «자기 자신»을 동명이인으로 세어 아바타를 붙인다 */
void main() {
  final st = AppState.i;
  setUp(() {
    st.setCouple({
      'members': {
        'new': {'uid': 'new', 'name': '김철수', 'emoji': '🐯', 'photo': 'st:C/p1', 'role': 'member'},
        'u2': {'uid': 'u2', 'name': '이영희', 'emoji': '🐰', 'role': 'member'},
      },
      'former': {
        'old': {'uid': 'old', 'name': '김철수(옛)', 'emoji': '😀', 'movedTo': 'new'},
        'gone': {'uid': 'gone', 'name': '박탈퇴', 'emoji': '🐻'},
      },
    });
  });
  tearDown(() => st.setCouple({}));

  test('옛 번호로 쓴 글도 «지금» 이름·얼굴·사진으로 보인다', () {
    expect(st.nameOf('old'), '김철수');
    expect(st.emojiOf('old'), '🐯');
    expect(st.photoOf('old'), 'st:C/p1');
  });

  test('자기 자신을 동명이인으로 세지 않는다', () {
    expect(st.listName('old'), '김철수');
  });

  test('그냥 나간 사람은 그대로 — 나간 기록의 이름·아바타', () {
    expect(st.nameOf('gone'), '박탈퇴');
    expect(st.emojiOf('gone'), '🐻');
    expect(st.photoOf('gone'), isNull);
  });
}
