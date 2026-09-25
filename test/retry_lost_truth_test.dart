import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:woorimoim/store.dart';

/* 🗑 「다시 지워보기」가 거짓 성공을 말했다 (2026-09-26 74회차).

   다시 시도해서 또 실패한 번호는 포기함이 아니라 «대기줄»에 남는다(1번 실패로는 포기 안 함).
   그런데 설정 화면은 포기함 수(lostCount)만 보고 「N개를 모두 지웠어요 ✨」라고 했다.
   → 하나도 안 지워졌는데 다 지워졌다고 말하고, 사장님은 보관료가 왜 안 줄지 모른다. */
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('다시 시도했는데 못 지운 것은 «남은 것»으로 센다', () async {
    SharedPreferences.setMockInitialValues({
      'club_delq_lost': ['st:C/a', 'st:C/b'],
    });
    await Store.i.loadPrefsForTest();
    // 시험 환경에는 서버가 없다 → 지우기는 반드시 실패한다
    final r = await Store.i.retryLost();
    expect(r.tried, 2);
    expect(r.left, 2, reason: '하나도 못 지웠는데 «모두 지웠어요»라고 말한다');
    expect(Store.i.lostCount(), 0, reason: '전제: 포기함 수만 보면 0 이라 거짓 성공이 난다');
  });

  test('설정 화면은 포기함 수가 아니라 «남은 수»로 말한다', () {
    final s = File('lib/ui/settings.dart').readAsStringSync();
    final at = s.indexOf('Future<void> _retryLost()');
    final body = s.substring(at, s.indexOf('\n  }', at));
    expect(body.contains('lostCount()'), isFalse, reason: '대기줄에 남은 것을 못 센다');
    expect(body, contains('r.left'));
  });
}
