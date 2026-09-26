import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 🙋 체험 모임의 참석 투표가 «모임 날이 아닌 날»에 적혀 있었다 (2026-09-26 81회차 에뮬레이터에서 봄).

   매주 「정기 모임」은 사흘 전에 시작해 다음 회차가 나흘 뒤인데, 참석 투표 다섯 표는 **오늘** 날짜로 적혀
   어느 회차에도 안 잡혔다 → 일정 화면에 «참석 0 · 미정 0 · 불참 0». 심사원이 보는 화면에서
   참석 투표가 텅 빈 기능으로 보였다. 대화도 「오늘 정기모임 7시!」라고 했는데 오늘은 모임 날이 아니다. */
void main() {
  tearDown(Demo.stop);

  test('참석 투표·출석은 모두 그 모임의 «회차 날»에 적혀 있다', () {
    Demo.start();
    for (final e in AppState.i.by('event')) {
      for (final k in [...Logic.asMap(e['rsvp']).keys, ...Logic.asMap(e['attend']).keys]) {
        final d = k.substring(0, 10);
        expect(Logic.occursOn(e, d), isTrue, reason: '「${e['title']}」 $d 는 회차가 아니다 ($k)');
      }
    }
  });

  test('다가오는 정기 모임에 참석 투표가 보인다', () {
    Demo.start();
    final e = AppState.i.by('event').firstWhere((x) => x['repeat'] == 'week');
    final next = Logic.occurrences(e, from: DateTime.now(), to: DateTime.now().add(const Duration(days: 8)));
    expect(next, isNotEmpty);
    expect(Logic.rsvpCount(e, next.first, 'yes'), greaterThan(0));
  });

  test('대화가 «오늘 정기모임»이라면 오늘이 정말 회차다', () {
    Demo.start();
    final e = AppState.i.by('event').firstWhere((x) => x['repeat'] == 'week');
    final today = ymd(DateTime.now());
    for (final m in AppState.i.by('msg')) {
      final t = '${m['text'] ?? ''}';
      if (t.contains('오늘') && t.contains('정기')) {
        expect(Logic.occursOn(e, today), isTrue, reason: '「$t」 — 오늘은 정기 모임 날이 아니다');
      }
    }
  });
}
