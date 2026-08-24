import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

/* 🗑 삭제 대기줄에 «영영 안 빠지는 줄»이 생기지 않게.

   대기줄은 **기기에 남는다.** 그래서 지금 코드가 안 만드는 값이라도,
   예전 판이 남긴 값이 회원 폰에 그대로 있을 수 있다(144회차 이전의 `data:` 값).
   `flushDeletes` 는 그 목록을 그대로 읽어 지우려 드는데,
   base64 글자에는 `//` 가 거의 반드시 들어 있어 Firestore 가 ArgumentError 를 던진다.
   그 오류는 FirebaseException 이 «아니라서» 예전 셈으로는 실패로 세지도 않았다
   → `keep:true, failed:false` → **앱을 켤 때마다 영원히 다시 시도.** */
void main() {
  group('지울 수 있는 번호인지 먼저 가른다', () {
    test('지울 수 있는 것', () {
      expect(Store.deletable('1770000000_0abcd'), isTrue); // 옛 방식(문서)
      expect(Store.deletable('st:ABC123/1770000000_0abcd'), isTrue); // 보관함
    });

    test('지울 수 «없는» 것 — 그림이 문서 안에 들어 있던 옛 방식', () {
      expect(Store.deletable('data:image/jpeg;base64,/9j/4AAQSkZJRg=='), isFalse);
    });

    test('지울 수 «없는» 것 — 빗금이 든 값은 문서 이름이 될 수 없다', () {
      expect(Store.deletable('photos/abc'), isFalse);
      expect(Store.deletable('a//b'), isFalse);
    });

    test('빈 값·반쪽 값', () {
      expect(Store.deletable(null), isFalse);
      expect(Store.deletable(''), isFalse);
      expect(Store.deletable('st:'), isFalse);
    });
  });

  group('서버가 준 오류가 아닌 것은 «반드시» 센다', () {
    test('값이 잘못돼 터진 것은 다시 해도 똑같다', () {
      expect(Store.countsAsFailure(ArgumentError('A document path must not contain "//"')),
          isTrue,
          reason: '이걸 안 세면 그 줄은 10번 세기가 «아예 안 돌아» 영영 안 빠진다');
      expect(Store.countsAsFailure(TypeError()), isTrue);
    });

    test('인터넷 문제는 그대로 안 센다', () {
      for (final c in ['unknown', 'retry-limit-exceeded', 'canceled']) {
        expect(Store.countsAsFailure(FirebaseException(plugin: 'p', code: c)), isFalse,
            reason: c);
      }
    });

    test('거절은 센다', () {
      for (final c in ['unauthorized', 'permission-denied', 'invalid-argument']) {
        expect(Store.countsAsFailure(FirebaseException(plugin: 'p', code: c)), isTrue,
            reason: c);
      }
    });
  });

  test('못 지울 값은 «시도도 하기 전에» 대기줄에서 빠진다', () {
    final s = File('lib/store.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//.*'), '');
    final at = s.indexOf('Future<bool> deletePhoto(');
    expect(at, greaterThan(0));
    var depth = 0, i = s.indexOf('{', s.indexOf(')', at));
    final open = i;
    for (; i < s.length; i++) {
      if (s[i] == '{') depth++;
      if (s[i] == '}') { depth--; if (depth == 0) break; }
    }
    final body = s.substring(open, i);
    expect(body, contains('if (!deletable(id))'),
        reason: '지울 수 없는 값을 그대로 서버에 보낸다 — 터지고, 안 세어지고, 영영 안 빠진다');
    final guard = body.substring(body.indexOf('if (!deletable(id))'));
    expect(guard.substring(0, guard.indexOf('}')), contains('_pend(id, false)'),
        reason: '못 지울 값을 대기줄에서 «빼지» 않는다 — 그대로 남아 매번 다시 돈다');
  });

  test('영영 안 빠지는 줄이 없다 — 세면 언젠가 포기한다', () {
    var q = <String>[];
    var n = <String, int>{};
    var gaveUp = false;
    for (var i = 0; i < 20 && !gaveUp; i++) {
      final r = Store.planPend(q, n, 'bad', true, failed: true);
      q = r.queue;
      n = r.tries;
      gaveUp = r.gaveUp;
    }
    expect(gaveUp, isTrue, reason: '실패로 세는데도 포기하지 않는다');
    expect(q, isNot(contains('bad')));
  });
}
