import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';

/* 📅 체험 자료의 «지난 일» 글에 달이 박혀 있으면 날짜와 어긋난다 (2026-09-26 75회차 화면에서 봄).

   체험 자료의 날짜는 «오늘 기준»으로 움직이는데 글은 「3월 정기 대회 후기」로 굳어 있어서,
   9월에 둘러보면 9월 22일 글이 3월 대회 후기다 — 1년 중 11달은 어긋난다.
   체험 화면은 심사원이 보는 곳이라 「자료가 엉터리」로 읽힌다. */
void main() {
  tearDown(Demo.stop);

  test('지난 대회 글·사진에 적힌 달은 그 글의 날짜와 같다', () {
    Demo.start();
    final rows = [...AppState.i.by('diary'), ...AppState.i.by('photo')];
    final mentions = rows.where((x) =>
        '${x['title'] ?? ''} ${x['caption'] ?? ''}'.contains('대회'));
    expect(mentions, isNotEmpty, reason: '전제: 대회 글이 있다');
    for (final x in mentions) {
      final s = '${x['title'] ?? ''} ${x['caption'] ?? ''}';
      final date = x['date'] as String;
      final m = int.parse(date.substring(5, 7));
      for (final hit in RegExp(r'(\d+)월').allMatches(s)) {
        expect(int.parse(hit.group(1)!), m, reason: '$date 글인데 「$s」');
      }
    }
  });
}
