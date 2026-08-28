// 「나」를 뜻하는 자리가 폰 바꾸기를 이어야 하는지 아닌지 (111회차).
//
// 폰을 바꾸면 번호가 새로 생긴다. 「내 번호와 같은가」를 그대로 물으면
// 어떤 자리는 «틀린 답»이 되고(내 지난 대화가 남의 것으로), 어떤 자리는 «그래야 맞다»(권한).
// 새로 그런 자리가 생기면 반드시 어느 쪽인지 정하도록 목록을 못 박아 둔다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 지금까지 «그대로 견줘도 되는» 자리와 그 이유
const _known = {
  'board.dart': 2, // 지우기 권한 ×2 — 서버가 글에 적힌 번호만 보므로 넓히면 헛단추
  /* 137회차에 하나가 빠졌다: 「입력 중」 셈을 `typingLive(...)` 로 떼어내면서
     「내 것은 빼고」가 **건네주는 값**(myUid 매개변수)이 되어 이 그물에 안 걸린다.
     그 자리는 `test/typing_expire_test.dart` 가 대신 지킨다
     (지금 회원 목록 안이라 옛 번호가 없다 → 그대로 견주는 것이 맞다). */
  'chat.dart': 3, // 지우기 권한 1 + 지금 회원 목록 안에서의 비교 2
  /* 댓글 메뉴에서 «내 댓글인지» — 신고·차단 메뉴를 내 글에는 안 보이려는 것.
     보여 주기가 아니라 «지금 이 화면의 나»라서 넓히면 안 된다:
     폰 바꾸기 전 번호까지 넓히면 옛 내 댓글에 「나를 차단」이 뜬다. */
  'post_screen.dart': 1,
  'members.dart': 2, // 나를 자르거나 나에게 방장을 넘길 수 없다 (목록 안이라 옛 번호가 없다)
  /* 131회차에 settings.dart 한 자리가 빠졌다: 아바타 겹침 검사를
     `Logic.avatarClash(…, skipUid: Store.i.myUid)` 한 곳으로 모으면서
     「나를 뺀다」가 «건네주는 값»이 되어 이 그물(== Store.i.myUid)에 안 걸린다.
     그 자리는 `test/avatar_clash_test.dart` 가 대신 지킨다
     (지금 회원 목록 안이라 옛 번호가 없다 → 그대로 견주는 것이 맞다). */
};

String stripComments(String s) {
  final noBlock = s.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return noBlock.split(String.fromCharCode(10)).map((l) => l.split('//').first).join(String.fromCharCode(10));
}

void main() {
  test('내 번호를 «그대로» 견주는 자리가 늘지 않았다', () {
    final re = RegExp(r'(==|!=)\s*Store\.i\.myUid|Store\.i\.myUid\s*(==|!=)');
    final found = <String, int>{};
    void scan(Directory d) {
      for (final f in d.listSync()) {
        if (f is Directory) {
          scan(f);
        } else if (f is File && f.path.endsWith('.dart')) {
          final name = f.uri.pathSegments.last;
          for (final l in stripComments(f.readAsStringSync()).split(String.fromCharCode(10))) {
            if (l.contains('Logic.isMe')) continue;
            if (re.hasMatch(l)) found[name] = (found[name] ?? 0) + 1;
          }
        }
      }
    }

    scan(Directory('lib'));
    expect(found, _known,
        reason: '자리가 늘거나 줄었다 — «보여 주기»면 Logic.isMe 로 이어야 하고, '
            '«권한»이면 그대로 두되 왜 그런지 적어야 한다');
  });

  test('«보여 주기» 쪽은 이미 이어져 있다', () {
    final chat = File('lib/ui/chat.dart').readAsStringSync();
    final shell = File('lib/ui/shell.dart').readAsStringSync();
    // 말풍선 좌우 · 읽음 표시가 붙는 자리 · 읽음 찍기 · 안읽음 배지
    expect(chat.contains("Logic.isMe(msg['by']"), isTrue, reason: '말풍선 좌우');
    expect(chat.contains("Logic.isMe(all[i]['by']"), isTrue, reason: '읽음 표시 자리');
    expect(chat.contains("!Logic.isMe(m['by'] as String?, Store.i.myUid)"), isTrue,
        reason: '읽음 찍을 때 «남의 말»을 고르는 자리');
    expect(shell.contains('Logic.isMe'), isTrue, reason: '안읽음 배지');
  });
}
