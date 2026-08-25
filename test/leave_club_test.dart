import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🗑 「모임 탈퇴」 — 화면에 적은 말과 실제로 지우는 것이 **같아야 한다**.

   회비 장부와 대화는 «모임이 함께 쓴 기록»이라 한 사람이 나갔다고 지우지 않는다.
   옛 글의 글쓴이 이름·아바타도 남긴다 — 지우면 「알 수 없는 사람」이 되어 지난 대화를 못 읽는다.
   그것이 이 앱이 고른 길이고, `Store.deleteMyData` 의 `former` 가 그 몫이다.

   ⚠️ 그런데 2026-08-25 화면에는 «내 이름·아바타를 지워요» 라고 적혀 있었다 — 거짓말이었다.
      이 어긋남은 회원을 속이는 데서 끝나지 않는다:
      구글 데이터 보안 신고와 삭제 안내 페이지도 그 말을 근거로 쓰기 때문에,
      **스토어에 낸 신고까지 함께 거짓**이 된다(정책 위반으로 앱이 내려갈 수 있다).
   그래서 «남긴다»는 코드와 «남는다»는 말을 여기서 묶어 둔다. */
void main() {
  final store = File('lib/store.dart').readAsStringSync();
  final settings = File('lib/ui/settings.dart').readAsStringSync();

  String bodyOf(String src, String decl) {
    final at = src.indexOf(decl);
    if (at < 0) return '';
    final open = src.indexOf('{', at);
    var d = 0;
    for (var j = open; j < src.length; j++) {
      if (src[j] == '{') d++;
      if (src[j] == '}') {
        d--;
        if (d == 0) return src.substring(open, j + 1);
      }
    }
    return '';
  }

  final del = bodyOf(store, 'Future<bool> deleteMyData(');

  test('탈퇴하면 «회원 자리»와 개인정보가 실제로 지워진다', () {
    expect(del, isNotEmpty, reason: 'deleteMyData 를 못 찾았다');
    for (final gone in ["'members.\$uid': null", "'push.\$uid': null"]) {
      expect(del.contains(gone), isTrue, reason: '$gone 를 안 지운다 — 탈퇴가 탈퇴가 아니다');
    }
  });

  test('옛 글의 글쓴이 이름·아바타는 «남긴다» (코드)', () {
    expect(del.contains("'former.\$uid'"), isTrue,
        reason: '이름을 안 남기면 지난 대화가 「알 수 없는 사람」이 된다');
    expect(del.contains("'name': name"), isTrue);
    expect(del.contains("'emoji': emoji"), isTrue);
  });

  test('화면에 적은 말이 그 «남긴다»와 어긋나지 않는다', () {
    final sheet = bodyOf(settings, 'Future<void> _deleteMyData(');
    expect(sheet, isNotEmpty);
    // 물어보는 창의 글월만 추린다
    final at = sheet.indexOf('confirmSheet');
    final ask = sheet.substring(at, (at + 700).clamp(0, sheet.length));

    expect(ask.contains('남는 것'), isTrue, reason: '무엇이 남는지 안 알려준다');
    expect(ask.contains('이름'), isTrue, reason: '이름이 남는다는 말이 없다');

    /* ⚠️ 미끼: 「지워지는 것」 목록에 이름·아바타가 들어가면 거짓말이다.
       (코드는 그 둘을 `former` 로 남기기 때문) */
    final gonePart = ask.substring(
        ask.indexOf('지워지는 것'),
        ask.indexOf('남는 것') > 0 ? ask.indexOf('남는 것') : ask.length);
    for (final lie in ['이름', '아바타']) {
      expect(gonePart.contains(lie), isFalse,
          reason: '「지워지는 것」에 «$lie»이 적혀 있다 — 코드는 남기므로 거짓말이다');
    }
  });

  test('완전 삭제를 원하는 사람에게 길을 알려준다', () {
    final sheet = bodyOf(settings, 'Future<void> _deleteMyData(');
    expect(sheet.contains('운영자에게 연락'), isTrue,
        reason: '글까지 지우고 싶은 사람이 갈 곳이 없다 — 스토어 정책상 길은 있어야 한다');
  });
}
