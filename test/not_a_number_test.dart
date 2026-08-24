// NaN·무한대가 들어왔을 때 (105회차).
//
// Firestore 의 숫자는 이 둘을 담을 수 있다. 「숫자이긴 하지만» 쓰는 곳마다 터진다:
//   · `round()`·`toInt()` 는 UnsupportedError 를 낸다
//   · 그리기에 쓰면 자리 셈이 NaN 이 되어 화면이 통째로 안 뜬다
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/ui/common.dart';

const _bad = [double.nan, double.infinity, -double.infinity];

void main() {
  group('돈', () {
    test('NaN·무한대는 «없는 것»으로 본다 (터지지 않는다)', () {
      for (final v in _bad) {
        expect(Store.money(v), 0, reason: '$v');
      }
    });

    test('모임 문서 정리가 통째로 터지지 않는다', () {
      for (final v in _bad) {
        late Map<String, dynamic>? c;
        expect(() => c = Store.tidyCouple({
              'title': '모임',
              'fee': {'amount': v}
            }), returnsNormally, reason: '$v — 여기서 터지면 모임 문서가 «아예» 안 들어온다');
        expect((c!['fee'] as Map)['amount'], 0);
      }
    });

    test('멀쩡한 돈은 그대로다', () {
      expect(Store.money(10000), 10000);
      expect(Store.money('10000'), 10000);
      expect(Store.money(1e300), 0, reason: '한도를 넘는 값은 예전처럼 0');
    });
  });

  group('때', () {
    test('NaN 을 「말이 되는 때」로 묻는 것만으로도 터지면 안 된다', () {
      for (final v in _bad) {
        expect(() => Store.isSaneTime(v), returnsNormally, reason: '$v');
        expect(Store.isSaneTime(v), isFalse);
      }
    });

    test('기록 정리가 통째로 터지지 않는다', () {
      late List<Map<String, dynamic>> out;
      expect(
          () => out = Store.tidy([
                {'id': 'a', 'type': 'msg', 'text': 'x', 'createdAt': double.nan},
                {'id': 'b', 'type': 'msg', 'text': 'y', 'createdAt': 1755800000000},
              ]),
          returnsNormally,
          reason: '여기서 터지면 앱에 자료가 «하나도» 안 들어온다');
      expect(out.length, 2);
      expect(out.first.containsKey('createdAt'), isFalse);
    });
  });

  group('상징', () {
    testWidgets('회전이 NaN·무한대여도 화면이 뜬다', (t) async {
      for (final v in _bad) {
        AppState.i.couple = Store.tidyCouple({
          'title': '모임',
          'emblem': {'kind': 'emoji', 'emoji': '🏸', 'size': 1, 'rot': v},
        });
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(const MaterialApp(home: Scaffold(body: Emblem())));
        expect(t.takeException(), isNull,
            reason: '$v — 상징은 홈과 위쪽 막대에 있어 여기가 죽으면 앱 전체가 안 보인다');
        expect(find.text('🏸'), findsOneWidget);
      }
    });

    testWidgets('크기가 NaN 이어도 화면이 뜬다', (t) async {
      AppState.i.couple = Store.tidyCouple({
        'title': '모임',
        'emblem': {'kind': 'emoji', 'emoji': '🏸', 'size': double.nan, 'rot': 0},
      });
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: Emblem())));
      expect(t.takeException(), isNull);
    });

    testWidgets('멀쩡한 회전은 그대로 돈다', (t) async {
      AppState.i.couple = Store.tidyCouple({
        'title': '모임',
        'emblem': {'kind': 'emoji', 'emoji': '🏸', 'size': 1, 'rot': 90},
      });
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: Emblem())));
      expect(t.takeException(), isNull);
      expect((AppState.i.couple!['emblem'] as Map)['rot'], 90);
    });
  });
}
