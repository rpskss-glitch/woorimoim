// 사진 지우기 대기줄 — 못 지운 원본을 적어 뒀다가 다음에 마저 지우는 자리.
// 이미 두 번 버그가 났다(깨진 값에 통째로 멈춤 / 조용히 버림)라 셈하는 부분을 떼어 시험한다.
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

void main() {
  test('넣기 — 같은 것을 두 번 넣어도 하나', () {
    var r = Store.planPend([], {}, 'a', true);
    r = Store.planPend(r.queue, r.tries, 'a', true);
    expect(r.queue, ['a']);
  });

  test('빼기 — 지워졌으면 대기줄과 셈값에서 모두 빠진다', () {
    final r = Store.planPend(['a', 'b'], {'a': 3}, 'a', false);
    expect(r.queue, ['b']);
    expect(r.tries.containsKey('a'), isFalse,
        reason: '셈값이 남으면 다음에 같은 번호가 들어올 때 바로 포기해 버린다');
  });

  test('인터넷 문제는 실패로 세지 않는다', () {
    // 며칠 오프라인이었다는 이유로 한도를 채워 대기줄에서 빠지면,
    // 아무도 못 보는 사진이 매달 보관 요금만 낸다
    var r = Store.planPend([], {}, 'a', true, failed: false);
    for (var i = 0; i < 50; i++) {
      r = Store.planPend(r.queue, r.tries, 'a', true, failed: false);
    }
    expect(r.queue, ['a']);
    expect(r.gaveUp, isFalse);
  });

  test('영영 안 될 것 같으면 정해진 횟수 뒤에 포기하고 «알린다»', () {
    /* 실제 흐름: 앱을 켤 때마다 대기줄을 한 번 훑고, 그때 실패하면 한 번 센다.
       포기하면 대기줄에서 빠지므로 그 뒤로는 다시 시도되지 않는다 — 거기서 멈춘다. */
    var r = Store.planPend(const [], const {}, '씨앗', false); // 꼴은 «함수가 준 것»을 쓴다
    var tries = 0;
    while (!r.gaveUp && tries < 30) {
      r = Store.planPend(r.queue, r.tries, 'a', true, failed: true);
      tries++;
    }
    expect(r.gaveUp, isTrue, reason: '영영 못 지울 것을 앱 켤 때마다 다시 시도하면 안 된다');
    expect(tries, greaterThan(3), reason: '한두 번에 포기하면 잠깐 막힌 것도 버린다');
    expect(r.queue, isEmpty, reason: '포기했으면 대기줄에서 빠져 다시 시도되지 않는다');
    expect(r.tries.containsKey('a'), isFalse);
  });

  test('대기줄이 가득 차면 «가장 오래된 것»부터 버리고 몇 장인지 알린다', () {
    var r = Store.planPend(const [], const {}, '씨앗', false); // 꼴은 «함수가 준 것»을 쓴다
    for (var i = 0; i < Store.delQMax; i++) {
      r = Store.planPend(r.queue, r.tries, 'p$i', true);
    }
    expect(r.queue.length, Store.delQMax);
    expect(r.dropped, 0);

    r = Store.planPend(r.queue, r.tries, 'new', true);
    expect(r.queue.length, Store.delQMax);
    expect(r.dropped, 1, reason: '몇 장을 버렸는지 알려줘야 요금을 되짚을 수 있다');
    expect(r.queue.contains('p0'), isFalse, reason: '가장 오래된 것부터');
    expect(r.queue.contains('new'), isTrue);
    expect(r.tries.containsKey('p0'), isFalse, reason: '셈값도 같이 치운다');
  });

  test('버린 것과 포기한 것을 구분해서 알린다', () {
    // 둘 다 「원본이 서버에 남는다」는 뜻이라 각각 자국을 남겨야 한다
    final src = Store.planPend(['a'], {'a': 99}, 'a', true, failed: true);
    expect(src.gaveUp, isTrue);
    expect(src.dropped, 0);
  });

  /* 지우기 «결말»별로 대기줄을 어떻게 할지.
     78회차에 「답이 없음」 갈래가 대기줄을 아예 안 건드리는 것을 찾았다. */
  group('지우기 결말', () {
    test('잘 지워지면 대기줄에서 뺀다', () {
      final p = Store.planAfterDelete();
      expect(p.keep, isFalse);
      expect(p.ok, isTrue);
    });

    test('답이 없으면 «대기줄에 남기고» 실패로 세지 않는다', () {
      final p = Store.planAfterDelete(timedOut: true);
      expect(p.keep, isTrue, reason: '안 남기면 그 원본은 영영 못 찾는다');
      expect(p.failed, isFalse, reason: '인터넷이 느린 것을 실패로 세면 10번 만에 포기한다');
      expect(p.ok, isFalse);
    });

    test('이미 없어진 사진은 지워진 것으로 보고 뺀다', () {
      final p = Store.planAfterDelete(
          error: FirebaseException(plugin: 'storage', code: 'object-not-found'));
      expect(p.keep, isFalse);
      expect(p.ok, isTrue);
    });

    test('거절은 실패로 세고, 인터넷 문제는 안 센다', () {
      final no = Store.planAfterDelete(
          error: FirebaseException(plugin: 'storage', code: 'unauthorized'));
      expect(no.keep, isTrue);
      expect(no.failed, isTrue);
      final net = Store.planAfterDelete(
          error: FirebaseException(plugin: 'storage', code: 'retry-limit-exceeded'));
      expect(net.keep, isTrue);
      expect(net.failed, isFalse);
    });

    /* 진짜 구멍은 여기였다 — 방 지우기는 «미리 적어 두지 않고» 부른다.
       (미리 적는 곳은 dropPhotos 하나뿐이다) */
    test('빈 대기줄에서 답이 없어도 그 사진이 대기줄에 들어간다 (방 지우기 상황)', () {
      const id = 'st:AAA123/1755800000_0abcd';
      final plan = Store.planAfterDelete(timedOut: true);
      final r = Store.planPend(const [], const {}, id, plan.keep, failed: plan.failed);
      expect(r.queue, contains(id),
          reason: '방을 지우는 도중 답이 없으면 사진 번호를 담은 기록이 곧 지워져 영영 못 찾는다');
      expect(r.gaveUp, isFalse);
    });

    test('방 지우기는 «미리 적어 두지 않고» 부른다 — 그래서 결말 처리가 유일한 방어다', () {
      final src = File('lib/store.dart').readAsStringSync();
      final purge = src.substring(src.indexOf('Future<int> purgeClubData'));
      final body = purge.substring(0, purge.indexOf('\n  }\n'));
      expect(body.contains('deletePhoto('), isTrue);
      expect(body.contains('_pend('), isFalse,
          reason: '미리 적게 바뀌었다면 이 시험의 설명을 고쳐야 한다');
    });
  });
}
