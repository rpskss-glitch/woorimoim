// 「누가 지울 수 있나」가 세 화면에서 같은가, 그리고 서버 규칙과 맞는가 (136회차).
//
// 서버는 «내 것 또는 운영진»에게 지우기를 열어 둔다(규칙 주석: 「남이 쓴 글·대화는 못 지운다
// (운영진·총괄은 예외)」). 게시판·사진첩은 그대로 따랐는데 **채팅만 「내 것」뿐**이었다.
// → 욕설·스팸이 올라와도 방장이 손을 못 댔다.
//   (사진첩은 회원에게 「운영진은 모두 지울 수 있어요」라고 알리기까지 한다 — 말과 행동이 어긋났다)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🔴 여기 «옛 PC 경로»(C:\Users\asas3)가 박혀 있었다.
   이 기기에는 그런 폴더가 없어 아래 두 시험이 **조용히 건너뛰어졌다** —
   앱의 잣대가 서버 규칙과 어긋나도 아무도 몰랐다.
   (검사기 세 개도 같은 병이었다 — 옮겨 다니는 폴더라 «상대 경로»로 적는다) */
const _rules = '../데이트장부/firestore.rules';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

/// [from] 부터 다음 세미콜론까지 — 규칙 한 덩어리
String ruleAt(String src, String from) {
  final at = src.indexOf(from);
  if (at < 0) return '';
  final end = src.indexOf(';', at);
  return src.substring(at, end < 0 ? src.length : end);
}

void main() {
  test('세 화면이 «같은 잣대»로 지우기를 띄운다', () {
    final want = {
      'lib/ui/board.dart': 'mine || st.isAdmin',
      'lib/ui/chat.dart': 'mine || AppState.i.isAdmin',
    };
    want.forEach((f, expr) {
      final code = stripComments(File(f).readAsStringSync());
      expect(code.contains(expr), isTrue,
          reason: '$f 의 지우기 잣대가 「내 것 또는 운영진」이 아니다');
    });
    /* 사진첩은 «막는 쪽»으로 쓴다 — 뜻은 같다.
       ⚠️ 자리가 **album.dart 로 옮겨졌고 둘로 늘었다**(한 장 / 여러 장 한꺼번에).
          여러 장 쪽이 더 위험하다 — 한 번에 남의 사진까지 지워 버릴 수 있다. */
    final album = stripComments(File('lib/ui/album.dart').readAsStringSync());
    expect(album.contains('!mine && !AppState.i.isAdmin'), isTrue,
        reason: '사진 한 장 지우기 잣대가 바뀌었다');
    expect(album.contains("!= Store.i.myUid && !AppState.i.isAdmin"), isTrue,
        reason: '여러 장 한꺼번에 지울 때 잣대가 다르다 — 남의 사진까지 지워질 수 있다');
  });

  test('«권한»은 그대로 견주고, «보여 주기»는 폰 바꾸기를 잇는다', () {
    /* 채팅에는 이름이 같은 `mine` 이 둘 있다 — 헷갈리기 쉬워 여기에 못 박는다.
         · 지우기 잣대(_menu)  : `== Store.i.myUid`  — 서버가 글에 적힌 번호만 보므로
                                 넓히면 눌러도 안 되는 헛단추가 된다.
         · 말풍선 쪽(_bubble)  : `Logic.isMe(...)`   — 폰을 바꾸기 «전» 내 말도 내 말이라
                                 안 이으면 내 옛 말이 «남의 말»처럼 왼쪽에 붙는다. */
    final chat = stripComments(File('lib/ui/chat.dart').readAsStringSync());
    final menu = chat.indexOf('Future<void> _menu(');
    expect(menu, greaterThan(0));
    final menuMine = chat.indexOf('final mine =', menu);
    expect(chat.substring(menuMine, menuMine + 60).contains('Store.i.myUid'), isTrue);
    expect(chat.substring(menuMine, menuMine + 60).contains('Logic.isMe'), isFalse,
        reason: '지우기 잣대를 폰 바꾸기까지 넓히면 헛단추가 된다');
    // 말풍선 쪽은 반대로 «이어야» 맞다
    expect(chat.contains("final mine = Logic.isMe(msg['by']"), isTrue,
        reason: '보여 주기까지 좁히면 내 옛 말이 남의 말처럼 보인다');
    // 게시판은 「지우기」 하나뿐이라 그대로 견주는 것이 맞다
    final board = stripComments(File('lib/ui/board.dart').readAsStringSync());
    expect(RegExp(r'final mine = item\[.by.\] == Store\.i\.myUid').hasMatch(board),
        isTrue);
  });

  test('앱의 잣대가 서버 규칙과 같은 것을 본다', () {
    final f = File(_rules);
    if (!f.existsSync()) {
      markTestSkipped('규칙 파일이 없는 기기 — 앱 쪽만 확인했다');
      return;
    }
    final r = stripComments(f.readAsStringSync());
    final del = ruleAt(r, 'allow delete: if request.auth != null && allowedCol()');
    expect(del, isNotEmpty, reason: '기록 지우기 규칙을 못 찾았다');
    expect(del.contains('isMineDoc('), isTrue);
    expect(del.contains('isStaffOf('), isTrue,
        reason: '서버가 운영진에게 안 열어 준다면 화면의 단추는 헛단추다');
    // 「운영진」이 방장·운영진을 뜻하는지도 대조한다
    expect(r.contains("m.role == 'owner' || m.role == 'admin'"), isTrue);
  });

  test('대화도 지울 수 있는 갈래에 들어 있다', () {
    final f = File(_rules);
    if (!f.existsSync()) {
      markTestSkipped('규칙 파일이 없는 기기');
      return;
    }
    final r = stripComments(f.readAsStringSync());
    expect(r.contains("col == 'msgs'"), isTrue,
        reason: '대화가 규칙의 허용 갈래에서 빠지면 채팅 지우기가 통째로 막힌다');
  });
}
