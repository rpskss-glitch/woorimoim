import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 📊 기한이 지난 투표를 「다시 열기」하면 «정말로» 열리는가.

   2026-09-25 조사: 「3시간 뒤 마감」 투표가 시간이 지나 닫힌 뒤, 만든 사람이 「다시 열기」를 누르면
   「투표를 다시 열었어요」가 뜨는데 **그대로 닫혀 있었다.**
   닫힘은 «closed 표시» 또는 «마감 시각이 지남» 둘 중 하나로 세는데,
   다시 열기는 closed 만 풀고 지난 마감 시각을 그대로 두었다. */
void main() {
  const now = 1790000000000;
  const hour = 3600000;

  Map<String, dynamic> pollMsg({int? until, bool closed = false}) => {
        'id': 'p1',
        'type': 'msg',
        'kind': 'poll',
        'coupleId': 'DEMO',
        'createdAt': now - 5 * hour,
        'poll': {
          'q': '토요일 몇 시?',
          'opts': ['9시', '2시'],
          if (until != null) 'until': until,
          if (closed) 'closed': true,
        },
      };

  group('적는 값', () {
    test('기한이 지난 투표를 다시 열면 지난 마감 시각도 지운다', () {
      final m = pollMsg(until: now - hour);
      expect(Logic.poll(m, now: now).closed, isTrue, reason: '전제: 기한이 지나 닫혀 있다');
      final patch = Logic.pollClosePatch(m, false, now: now);
      final p = patch['poll'] as Map;
      expect(p['closed'], isFalse);
      expect(p['until'], Store.del, reason: '지난 마감 시각을 두면 다시 열어도 닫힌 채로 센다');
    });

    test('아직 안 지난 마감 시각은 둔다 — 그때 다시 닫혀야 한다', () {
      final m = pollMsg(until: now + hour, closed: true);
      final p = Logic.pollClosePatch(m, false, now: now)['poll'] as Map;
      expect(p.containsKey('until'), isFalse);
    });

    test('마감하기는 시각을 건드리지 않는다', () {
      final m = pollMsg(until: now + hour);
      final p = Logic.pollClosePatch(m, true, now: now)['poll'] as Map;
      expect(p, {'closed': true});
    });

    test('기한 없는 투표는 예전과 같다', () {
      final m = pollMsg();
      expect(Logic.pollClosePatch(m, false, now: now), {
        'poll': {'closed': false}
      });
    });
  });

  group('실제로 적어 보면', () {
    tearDown(() {
      AppState.i.setCouple({});
      AppState.i.setItems([]);
    });

    test('다시 연 투표가 «열린 것»으로 센다 (나머지 칸은 그대로)', () {
      Demo.start();
      final m = pollMsg(until: now - hour, closed: true);
      Demo.addItem(m, docId: 'p1');
      final ok = Demo.applyItem('p1', (cur) => Logic.pollClosePatch(cur, false, now: now));
      expect(ok, isTrue);
      final after = AppState.i.by('msg').firstWhere((x) => x['id'] == 'p1');
      expect(Logic.poll(after, now: now).closed, isFalse,
          reason: '「다시 열었어요」라 해 놓고 그대로 닫혀 있다');
      final p = Logic.poll(after, now: now);
      expect(p.q, '토요일 몇 시?', reason: '다시 열면서 질문이 지워졌다');
      expect(p.opts, ['9시', '2시'], reason: '다시 열면서 항목이 지워졌다');
    });
  });

  test('대화방의 「다시 열기」가 이 값을 쓴다', () {
    final src = File('lib/ui/chat.dart').readAsStringSync();
    final at = src.indexOf('Future<void> _setClosed(');
    expect(at, greaterThan(0));
    final body = src.substring(at, src.indexOf('void _who()', at));
    expect(body, contains('Logic.pollClosePatch(cur, closed)'),
        reason: 'closed 만 적으면 기한 지난 투표는 다시 열리지 않는다');
  });
}
