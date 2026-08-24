// 서버에 닿아야만 되는 단추(참석 투표·출석 체크)는 도는 동안 «표시»를 내고 다시 안 눌려야 한다.
//
// 87회차: 트랜잭션은 답이 올 때까지 **최대 30초**를 기다리는데(runTransaction 기본값)
// 그동안 아무 표시가 없어 회원은 안 눌린 줄 알고 계속 눌렀다 — 누를 때마다 트랜잭션이 겹쳐 돌았다.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/ui/common.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('도는 동안 «도는 표시»가 나오고 다시 안 눌린다', (t) async {
    var calls = 0;
    final gate = Completer<void>();
    await t.pumpWidget(host(BusyButton(
      onTap: () async {
        calls++;
        await gate.future;
      },
      child: const Text('참석 3'),
    )));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    await t.tap(find.byType(BusyButton));
    await t.pump();

    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: '아무 표시가 없으면 회원은 안 눌린 줄 안다');
    expect(find.text('참석 3'), findsNothing);
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull,
        reason: '도는 동안 또 눌리면 트랜잭션이 겹친다');

    // 도는 중에 세 번 더 눌러도 늘지 않는다
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byType(BusyButton), warnIfMissed: false);
      await t.pump();
    }
    expect(calls, 1);

    gate.complete();
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('참석 3'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });

  testWidgets('일이 터져도 «도는 표시»는 내려가고 화면이 빨개지지 않는다', (t) async {
    await t.pumpWidget(host(BusyButton(
      onTap: () async => throw StateError('연결 끊김'),
      child: const Text('불참 0'),
    )));
    await t.tap(find.byType(BusyButton));
    await t.pump();

    expect(t.takeException(), isNull, reason: '새어 나가면 회원 화면이 통째로 빨개진다');
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: '표시가 남으면 그 단추는 영영 못 쓴다');
    expect(find.text('불참 0'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });

  testWidgets('도는 중에 화면이 사라져도 터지지 않는다', (t) async {
    final gate = Completer<void>();
    await t.pumpWidget(host(BusyButton(
      onTap: () async => gate.future,
      child: const Text('참석'),
    )));
    await t.tap(find.byType(BusyButton));
    await t.pump();
    await t.pumpWidget(host(const Text('딴 화면')));
    gate.complete();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  test('투표·출석 단추가 실제로 이걸 쓴다', () {
    for (final f in ['lib/ui/home.dart', 'lib/ui/calendar.dart']) {
      final src = File(f).readAsStringSync();
      expect(src.contains('BusyButton('), isTrue, reason: f);
      expect(src.contains("onPressed: () => _vote("), isFalse,
          reason: '$f — 옛 단추가 남아 있다 (30초 동안 아무 표시가 없다)');
    }
    final cal = File('lib/ui/calendar.dart').readAsStringSync();
    expect(cal.contains('class _AttendChipState'), isTrue,
        reason: '출석 칩도 겹쳐 눌리면 트랜잭션이 겹친다');
    expect(cal.contains('_busy || f == null'), isTrue);
  });
}
