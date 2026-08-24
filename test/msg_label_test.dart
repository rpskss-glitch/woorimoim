// 이 앱이 «모르는 대화»도 무엇인지는 보이는가 (145회차).
//
// 웹앱(아이폰 회원이 쓴다)에는 **음성 메시지**가 있는데 앱은 `img` 만 알았다.
// 그래서 음성 메시지 말풍선이 **텅 비어 있었다** — 게다가 서버는 이미
// 「🎤 음성 메시지를 보냈어요」라고 알림을 보낸다 →
// **알림은 왔는데 열어 보면 아무것도 없는** 꼴이었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/ui/chat.dart';

const _fn = r'C:\Users\asas3\Desktop\앞산배드민턴\functions\index.js';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

void main() {
  test('보통 글은 그대로', () {
    expect(msgLabel({'text': '안녕하세요'}), '안녕하세요');
    expect(msgLabel({'kind': '', 'text': '안녕'}), '안녕');
  });

  test('사진은 사진이라고', () {
    expect(msgLabel({'kind': 'img', 'photoId': 'st:c/1', 'text': ''}), '📷 사진');
  });

  test('음성 메시지는 «빈 자리»가 아니라 무엇인지 보인다', () {
    final s = msgLabel({'kind': 'voice', 'text': ''});
    expect(s, isNotEmpty, reason: '알림은 왔는데 열어 보면 아무것도 없다');
    expect(s.contains('음성'), isTrue);
  });

  test('앞으로 생길 «모르는 갈래»도 빈 자리로 두지 않는다', () {
    expect(msgLabel({'kind': 'sticker', 'text': ''}), isNotEmpty);
    expect(msgLabel({'kind': 'file'}), isNotEmpty);
  });

  test('갈래가 «안 적힌» 옛 대화는 없는 말을 지어내지 않는다', () {
    expect(msgLabel({'text': ''}), '');
    expect(msgLabel({}), '');
  });

  test('말풍선·답장 미리보기·답장 바가 «같은 문»을 쓴다', () {
    final code = stripComments(File('lib/ui/chat.dart').readAsStringSync());
    expect(RegExp(r'msgLabel\(').allMatches(code).length, greaterThanOrEqualTo(4),
        reason: '한 곳만 고치면 또 어긋난다 (문 하나 + 쓰는 곳 셋)');
    expect(code.contains("m['kind'] == 'img' ? '📷 사진'"), isFalse,
        reason: '제 나름대로 보던 옛 방식이 돌아왔다');
  });

  test('서버가 아는 갈래를 앱도 안다', () {
    final f = File(_fn);
    if (!f.existsSync()) {
      markTestSkipped('클라우드 함수 파일이 없는 기기 — 앱 쪽만 확인했다');
      return;
    }
    /* 서버는 알림 문구를 갈래별로 갈라 쓴다. 서버가 아는 갈래는 앱도 «무엇인지»는
       보여 줄 수 있어야 한다 — 안 그러면 알림과 화면이 어긋난다. */
    final kinds = RegExp(r"m\.kind === '(\w+)'")
        .allMatches(f.readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();
    expect(kinds, contains('voice'));
    for (final k in kinds) {
      expect(msgLabel({'kind': k, 'text': ''}), isNotEmpty,
          reason: '서버는 「$k」를 알리는데 앱은 빈 말풍선을 보여 준다');
    }
  });
}
