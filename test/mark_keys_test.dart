import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 🗝 참석 투표·출석은 「날짜_번호」로 적힌다.

   **세는 쪽**(rsvpCount·_countAttend)은 폰 바꾸기 전 번호를 이어 «한 사람»으로 세는데,
   **켜고 끄는 쪽**은 새 번호만 건드리고 있었다. 그래서 폰을 바꾼 회원은
     · 참석 수에는 들어 있는데 **제 단추는 안 눌린 것처럼** 보이고
     · 껐는데 **옛 표가 남아 인원이 안 줄었다**(출석은 취소가 아예 안 됐다).
   174회차의 좋아요와 같은 갈래 — 번호를 열쇠로 쓰는 칸은 전부 이 잣대가 필요하다. */
void main() {
  const day = '2026-08-20';

  void seedMoved() {
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'u1': {'uid': 'u1', 'name': '갑'},
        'u2': {'uid': 'u2', 'name': '을'},
      },
      'former': {
        'u9': {'uid': 'u9', 'name': '갑', 'movedTo': 'u1'}
      },
    });
    AppState.i.setItems([]);
  }

  group('그 사람이 그 날 남긴 표 찾기', () {
    test('옛 번호로 찍은 것도 «내 것»이다', () {
      seedMoved();
      expect(Logic.markKeys({Logic.rkey(day, 'u9'): 'yes'}, day, 'u1'),
          [Logic.rkey(day, 'u9')],
          reason: '옛 표를 못 알아본다 — 껐는데 그대로 남는다');
    });

    test('«지금 번호»가 맨 앞이다 — 최신 표가 먼저 잡혀야 한다', () {
      seedMoved();
      final ks = Logic.markKeys(
          {Logic.rkey(day, 'u9'): 'no', Logic.rkey(day, 'u1'): 'yes'}, day, 'u1');
      expect(ks.first, Logic.rkey(day, 'u1'));
      expect(ks.length, 2, reason: '둘 다 찾아야 끌 때 함께 지운다');
    });

    test('남의 표는 안 잡는다', () {
      seedMoved();
      expect(Logic.markKeys({Logic.rkey(day, 'u2'): 'yes'}, day, 'u1'), isEmpty);
    });

    test('다른 날의 표도 안 잡는다', () {
      seedMoved();
      expect(Logic.markKeys({Logic.rkey('2026-08-27', 'u9'): 'yes'}, day, 'u1'),
          isEmpty);
    });
  });

  group('내 참석 표시', () {
    Map<String, dynamic> ev(Map<String, dynamic> rsvp) =>
        {'id': 'e', 'type': 'event', 'date': day, 'rsvp': rsvp};

    test('폰을 바꾸기 전에 찍은 표가 «내 표»로 보인다', () {
      seedMoved();
      expect(Logic.myRsvp(ev({Logic.rkey(day, 'u9'): 'yes'}), day, 'u1'), 'yes',
          reason: '참석 수에는 내가 들어 있는데 «내 단추는 안 눌린 것»으로 보인다');
    });

    test('새 번호로 다시 찍었으면 «그것»이 내 표다', () {
      seedMoved();
      expect(
          Logic.myRsvp(
              ev({Logic.rkey(day, 'u9'): 'yes', Logic.rkey(day, 'u1'): 'no'}), day, 'u1'),
          'no');
    });

    test('세는 쪽과 «같은 사람»으로 본다', () {
      seedMoved();
      final e = ev({Logic.rkey(day, 'u9'): 'yes', Logic.rkey(day, 'u1'): 'yes'});
      expect(Logic.rsvpCount(e, day, 'yes'), 1, reason: '한 사람이 둘로 세어진다');
      expect(Logic.myRsvp(e, day, 'u1'), 'yes');
    });
  });

  test('출석 표시도 옛 번호를 잇는다', () {
    seedMoved();
    final e = {'id': 'e', 'type': 'event', 'date': day, 'attend': {Logic.rkey(day, 'u9'): true}};
    expect(Logic.attended(e, day, 'u1'), isTrue);
  });

  test('켜고 끄는 «세 자리 모두» 그 잣대를 쓴다', () {
    /* 세는 쪽만 고치면 반쪽이다 — 끄는 쪽이 새 번호만 지우면 옛 표가 유령으로 남는다. */
    for (final f in const ['lib/ui/home.dart', 'lib/ui/calendar.dart']) {
      final s = File(f)
          .readAsStringSync()
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
          .replaceAll(RegExp(r'//.*'), '');
      expect(s, contains('Logic.markKeys('),
          reason: '$f 의 켜고 끄기가 옛 번호를 안 잇는다 — '
              '껐는데 옛 표가 남아 인원이 안 줄어든다');
      expect(s, contains('for (final k in'),
          reason: '$f 가 «전부» 지우지 않고 하나만 지운다');
    }
    final cal = File('lib/ui/calendar.dart').readAsStringSync();
    expect(cal.contains('Logic.markKeys(att, date, uid)'), isTrue,
        reason: '출석 켜고 끄기가 옛 번호를 안 잇는다 — 출석 취소가 아예 안 된다');
  });
}
