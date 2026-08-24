// 「때」로 쓸 수 없는 수가 들어왔을 때 (102회차).
//
// Dart 의 DateTime 은 받아 줄 수 있는 범위가 있다. 그 밖의 수를 주면 RangeError 로 그 자리에서 터지는데,
// 그 자리가 화면 그리기 한복판이라 홈·회비·채팅이 통째로 안 뜬다.
// 게다가 `tidy` 안에서도 이 값을 날짜로 바꾸므로, 기록 하나만 망가져도 **자료가 아예 안 들어온다.**
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

const _now = 1755800000000; // 2026-08-21 무렵

Map<String, dynamic> withJoined(Object? v) => {
      'members': {
        'u1': {'uid': 'u1', 'name': '나', 'role': 'member', 'joinedAt': v}
      },
      'fee': {'amount': 10000},
    };

void main() {
  group('말이 되는 때인지', () {
    test('보통 값은 그대로 받는다', () {
      expect(Store.isSaneTime(_now), isTrue);
      expect(Store.isSaneTime(946684800000), isTrue, reason: '2000-01-01 은 받는다');
    });

    test('범위 밖이라 «터지는» 수는 안 받는다', () {
      for (final v in [9000000000000000000, -9000000000000000000, 8640000000000001]) {
        expect(Store.isSaneTime(v), isFalse, reason: '$v');
      }
    });

    test('범위 «안»이지만 말이 안 되는 수도 안 받는다', () {
      // 마이크로초를 밀리초 자리에 적은 경우 — 서기 5만년이 된다
      expect(Store.isSaneTime(1755800000000000), isFalse,
          reason: '안 막으면 그 회원 회비가 영영 「밀린 것 없음」이 된다');
      expect(Store.isSaneTime(0), isFalse, reason: '1970년은 이 앱의 때가 아니다');
      expect(Store.isSaneTime(-1), isFalse);
    });

    test('숫자가 아니면 안 받는다', () {
      for (final v in [null, '글자', <String, dynamic>{}, <int>[]]) {
        expect(Store.isSaneTime(v), isFalse, reason: '$v');
      }
    });

    test('폰 시계가 조금 빠른 것은 봐준다', () {
      final soon = DateTime.now().millisecondsSinceEpoch + 60000;
      expect(Store.isSaneTime(soon), isTrue, reason: '1분 빠른 폰까지 막으면 멀쩡한 기록이 사라진다');
      final far = DateTime.now().millisecondsSinceEpoch + 3 * 86400000;
      expect(Store.isSaneTime(far), isFalse, reason: '사흘 뒤는 시계 오차가 아니다');
    });
  });

  group('망가진 때가 들어와도', () {
    test('회비 계산이 안 터진다', () {
      for (final v in [9000000000000000000, -9000000000000000000, 8640000000000001, '글자']) {
        AppState.i.couple = Store.tidyCouple(withJoined(v));
        AppState.i.setItems([]);
        expect(() => Logic.unpaidMonths('u1'), returnsNormally, reason: '$v');
        // 들어온 때를 모르면 «이번 달 가입»으로 봐서 밀린 것이 없다
        expect(Logic.unpaidMonths('u1').length, 1, reason: '$v');
      }
    });

    test('«서기 5만년 가입»이 조용히 통과하지 않는다', () {
      AppState.i.couple = Store.tidyCouple(withJoined(1755800000000000));
      AppState.i.setItems([]);
      final m = (AppState.i.couple!['members'] as Map)['u1'] as Map;
      expect(m.containsKey('joinedAt'), isFalse, reason: '그대로 두면 회비가 영영 안 밀린다');
    });

    test('기록 하나가 망가져도 «자료 전체»가 들어온다', () {
      final out = Store.tidy([
        {'id': 'a', 'type': 'msg', 'text': '멀쩡', 'createdAt': _now},
        {'id': 'b', 'type': 'msg', 'text': '망가짐', 'createdAt': 9000000000000000000},
        {'id': 'c', 'type': 'diary', 'text': '날짜 채우기가 도는 기록', 'createdAt': -9000000000000000000},
      ]);
      expect(out.length, 3, reason: 'tidy 가 터지면 앱에 자료가 하나도 안 들어온다');
      expect(out[1].containsKey('createdAt'), isFalse);
      // 날짜를 못 채우면 «오늘»로 채운다 (없는 것보다 낫다)
      expect((out[2]['date'] as String).length, 10);
    });

    test('보통 기록은 손대지 않는다', () {
      final out = Store.tidy([
        {'id': 'a', 'type': 'msg', 'text': 'x', 'createdAt': _now, 'updatedAt': _now}
      ]);
      expect(out.first['createdAt'], _now);
      expect(out.first['updatedAt'], _now);
    });
  });
}
