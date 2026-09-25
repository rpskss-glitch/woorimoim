import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 📗 회원 설명서가 «앱과 다른 말»을 하고 있었다 (2026-09-25 에뮬에서 읽다가 잡음).
   · 사진첩: 「대화에 올라온 사진이 모두 모입니다」 — 아니다. 사진첩은 게시판 「사진」에 올린 것만.
   · 대화: 「📎 를 누르면 사진」「위쪽 📊」 — 실제는 입력칸 왼쪽 아래 🖼·📊 단추.
   · 「설정 맨 아래 「내 자료 지우기」」 — 실제 이름은 「모임 탈퇴 · 내 자료 지우기」이고 맨 아래가 아니다.
   · 「직책 정하기·회비 기록은 방장과 운영진」 — 직책은 방장만, 회비 기록은 회장·총무. */
void main() {
  final s = File('lib/ui/member_guide.dart').readAsStringSync();

  test('사진첩은 대화 사진이 모이는 곳이 아니다', () {
    expect(s.contains('대화에 올라온 사진이 모두 모입니다'), isFalse);
  });

  test('대화 단추 자리를 실제대로', () {
    expect(s.contains('📎 를 누르면'), isFalse);
    expect(s.contains('위쪽 📊'), isFalse);
  });

  test('탈퇴 메뉴 이름을 실제대로', () {
    expect(s.contains('설정 맨 아래 「내 자료 지우기」'), isFalse);
    expect(s, contains('「모임 탈퇴 · 내 자료 지우기」'));
  });

  test('권한 안내가 실제 권한과 같다', () {
    expect(s.contains('직책 정하기 · 회비 기록은 방장과 운영진만'), isFalse);
    // 실제: 직책은 방장만(members.dart onTitle: st.isOwner), 회비 기록은 회장·총무(isTreasurer)
    final m = File('lib/ui/members.dart').readAsStringSync();
    expect(m, contains('onTitle: st.isOwner'));
  });
  test('방장 안내 — 결제 전에 «만들어 볼 수 있다»고 하지 않는다(새 모임은 바로 잠긴다)', () {
    final o = File('lib/ui/owner_guide.dart').readAsStringSync();
    expect(o.contains("'· 결제 전에도 먼저 만들어 보실 수 있습니다."), isFalse);
    // 서버 규칙: 새로 쓰기는 clubPaid 일 때만
    final rules = File('../데이트장부/firestore.rules');
    if (rules.existsSync()) {
      expect(rules.readAsStringSync(), contains('function clubPaid(code)'));
    } else {
      markTestSkipped('규칙 파일이 없는 기기 — 앱 쪽만 확인했다');
    }
  });
}
