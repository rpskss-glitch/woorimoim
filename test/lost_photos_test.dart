import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

/* 🗑 「포기한 사진을 «버리지» 않는다」.

   예전에는 10번을 채우거나 대기줄이 넘치면 **번호를 그냥 버렸다.**
   번호가 사라지면 그 원본은 아무도 못 보는 채로 **매달 보관료만** 나가고,
   되짚을 실마리조차 없다. 그래서 버리지 않고 «포기함»으로 옮긴다.
   (데이트장부 670회차에 나온 것 — 이 앱도 같은 모양이었다) */
void main() {
  group('포기함', () {
    test('10번을 채워 포기한 번호는 «잃은 것»으로 넘어온다', () {
      var r = Store.planPend(const [], const {}, '씨앗', false);
      var n = 0;
      while (!r.gaveUp && n < 30) {
        r = Store.planPend(r.queue, r.tries, 'a', true, failed: true);
        n++;
      }
      expect(r.gaveUp, isTrue);
      expect(r.lost, ['a'],
          reason: '번호를 버리면 그 원본은 아무도 모르는 채로 매달 요금만 나간다');
      expect(r.queue, isEmpty, reason: '포기했으면 저절로 다시 시도되지 않는다');
    });

    test('대기줄이 넘쳐 밀려난 번호도 «잃은 것»으로 넘어온다', () {
      var r = Store.planPend(const [], const {}, '씨앗', false);
      for (var i = 0; i < Store.delQMax; i++) {
        r = Store.planPend(r.queue, r.tries, 'p$i', true);
      }
      expect(r.lost, isEmpty);
      r = Store.planPend(r.queue, r.tries, 'new', true);
      expect(r.dropped, 1);
      expect(r.lost, ['p0'], reason: '가장 오래된 것이 «조용히» 사라지면 안 된다');
    });

    test('보통 때는 아무것도 안 잃는다', () {
      final r = Store.planPend(const [], const {}, 'a', true);
      expect(r.lost, isEmpty);
      final done = Store.planPend(r.queue, r.tries, 'a', false);
      expect(done.lost, isEmpty, reason: '잘 지워진 것을 포기함에 넣으면 숫자가 거짓말을 한다');
    });
  });

  group('포기함 담기', () {
    test('같은 번호를 두 번 넣어도 하나로 센다', () {
      var l = Store.planLost(const [], ['a', 'b']).lost;
      l = Store.planLost(l, ['a', 'c']).lost;
      expect(l, ['a', 'b', 'c'], reason: '겹쳐 세면 「N개 남았다」가 부풀어 거짓말이 된다');
    });

    test('빈 번호는 안 담는다', () {
      expect(Store.planLost(const [], ['', 'a']).lost, ['a']);
    });

    test('포기함마저 넘치면 «몇 개를 잊었는지» 알린다', () {
      final many = List.generate(Store.lostMax + 3, (i) => 'x$i');
      final r = Store.planLost(const [], many);
      expect(r.lost.length, Store.lostMax);
      expect(r.forgotten, 3, reason: '조용히 잊으면 요금을 되짚을 길이 아예 없다');
      expect(r.lost.first, 'x3', reason: '가장 오래된 것부터');
    });

    test('한도는 대기줄보다 넉넉하다', () {
      expect(Store.lostMax, 500);
      expect(Store.lostMax, greaterThan(Store.delQMax),
          reason: '대기줄에서 밀려난 것을 받아야 하니 더 커야 한다');
    });
  });

  test('포기함은 «저절로» 다시 시도되지 않는다', () {
    /* 저절로 다시 넣으면 포기한 뜻이 없어지고, 앱을 켤 때마다
       같은 실패를 되풀이하며 요금만 쓴다. 사장님이 누를 때만 돌아가야 한다. */
    final s = File('lib/store.dart').readAsStringSync();
    final body = s.substring(s.indexOf('Future<void> flushDeletes()'));
    final end = body.indexOf('\n  }');
    expect(body.substring(0, end).contains('_qLostKey'), isFalse,
        reason: '대기줄을 훑는 자리가 포기함을 읽으면 저절로 되풀이된다');

    // 되돌리는 길은 «있어야» 한다 — 없으면 영영 못 지운다
    expect(s.contains('Future<int> retryLost()'), isTrue);
    expect(File('lib/ui/settings.dart').readAsStringSync().contains('다시 지워보기'), isTrue,
        reason: '누를 수 있는 자리가 없으면 그 길은 없는 것과 같다');
  });
}
