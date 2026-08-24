// 「내 자리가 없어졌다」의 «이유» — 셋은 회원에게 전혀 다른 일이다 (91회차).
//
// 예전에는 한 문장으로 뭉뚱그렸다:
//   · 폰을 바꿔 옮긴 뒤 «옛 폰»을 열면 → 방장이 자기를 잘랐다고 오해한다
//   · 가입 신청이 거절된 사람 → 쓴 적도 없는 「이용이 중지」라는 말을 듣는다
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/main.dart';
import 'package:woorimoim/state.dart';

/// 방장이 탈퇴 처리했을 때 서버에 남는 모양 (members.dart `_kick`)
Map<String, dynamic> kicked(String uid) => {
      'members': <String, dynamic>{},
      'former': {
        uid: {'uid': uid, 'name': '홍길동', 'emoji': '🏸', 'leftAt': 1755800000000}
      },
    };

/// 폰을 바꿔 자리를 옮겼을 때 옛 자리에 남는 모양 (onboarding 이어받기)
Map<String, dynamic> moved(String from, String to) => {
      'members': {to: <String, dynamic>{}},
      'former': {
        from: {'uid': from, 'name': '홍길동', 'movedTo': to, 'leftAt': 1755800000000}
      },
    };

void main() {
  test('탈퇴 처리 — former 에 자리만 남는다', () {
    expect(AppState.whyGone(kicked('u1'), 'u1'), SeatGone.kicked);
  });

  test('기기 이전 — former 에 «옮겨간 곳»이 적혀 있다', () {
    expect(AppState.whyGone(moved('u1', 'u2'), 'u1'), SeatGone.moved);
  });

  test('신청 거절 — former 에 아무것도 없다', () {
    expect(AppState.whyGone({'members': <String, dynamic>{}}, 'u1'), SeatGone.rejected);
    expect(AppState.whyGone(null, 'u1'), SeatGone.rejected);
    expect(AppState.whyGone({'former': <String, dynamic>{}}, 'u1'), SeatGone.rejected);
  });

  test('망가진 값이 들어 있어도 «탈퇴»로 잘못 보지 않는다', () {
    expect(AppState.whyGone({'former': '글자'}, 'u1'), SeatGone.rejected);
    expect(AppState.whyGone({'former': {'u1': '글자'}}, 'u1'), SeatGone.rejected);
    // movedTo 가 비었거나 자기 자신이면 «옮긴 것»이 아니다
    expect(AppState.whyGone({'former': {'u1': {'movedTo': ''}}}, 'u1'), SeatGone.kicked);
    expect(AppState.whyGone({'former': {'u1': {'movedTo': 'u1'}}}, 'u1'), SeatGone.kicked);
    expect(AppState.whyGone({'former': {'u1': {'movedTo': 7}}}, 'u1'), SeatGone.kicked);
  });

  test('이유마다 하는 말이 다르다', () {
    expect(goneMessage(SeatGone.moved, '홍길동'), contains('새 폰'));
    expect(goneMessage(SeatGone.moved, '홍길동'), isNot(contains('중지')));
    expect(goneMessage(SeatGone.rejected, null), contains('신청'));
    expect(goneMessage(SeatGone.rejected, null), isNot(contains('중지')));
    expect(goneMessage(SeatGone.kicked, '홍길동'), '홍길동님, 모임 이용이 중지됐어요 — 다시 신청할 수 있어요');
    // 이름을 모를 때도 말이 어색해지지 않는다
    expect(goneMessage(SeatGone.kicked, null), '모임 이용이 중지됐어요 — 다시 신청할 수 있어요');
    expect(goneMessage(SeatGone.kicked, ''), startsWith('모임'));
    expect(goneMessage(SeatGone.kicked, 42), startsWith('모임'));
  });

  test('시작 흐름이 이 갈래를 실제로 쓴다', () {
    final src = File('lib/main.dart').readAsStringSync();
    expect(src.contains('AppState.whyGone(c, Store.i.myUid)'), isTrue,
        reason: '한 문장으로 뭉뚱그리면 폰 바꾼 사람이 잘린 줄 안다');
    expect(src.contains('모임 이용이 중지됐어요'), isTrue);
    // 옛 방식(무조건 같은 말)이 남아 있으면 안 된다
    expect(src.contains("님, '}모임 이용이 중지됐어요"), isFalse);
  });
}
