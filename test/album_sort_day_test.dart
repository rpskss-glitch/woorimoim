import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/ui/album.dart';

/* 📸 날짜 칸이 없는 사진이 사진첩 맨 끝으로 밀렸다 (2026-09-26 84회차).

   사진첩은 달별로 묶을 때 «날짜 칸이 없으면 올린 때»로 보는데(웹과 같은 규칙),
   세울 때는 날짜 칸만 봐서 빈 칸('')이 늘 맨 뒤였다 →
     · 이번 달에 올린 사진이 그 달 묶음의 맨 끝에 붙고
     · 크게 보기에서 옆으로 넘기면 격자와 차례가 달라 다른 달로 튀었다. */
void main() {
  final sep25 = DateTime(2026, 9, 25).millisecondsSinceEpoch;
  Map<String, dynamic> p(String id, String date, [int at = 0]) =>
      {'id': id, 'date': date, 'createdAt': at};

  test('날짜 칸이 없으면 올린 때로 세운다 — 새것이 먼저', () {
    final out = sortPhotosByDay([
      p('aug', '2026-08-10'),
      p('sep1', '2026-09-01'),
      p('nodate', '', sep25), // 9월 25일에 올림, 날짜 칸 없음
      p('sep20', '2026-09-20'),
    ]);
    expect(out.map((x) => x['id']), ['nodate', 'sep20', 'sep1', 'aug']);
  });

  test('오래된 것부터 보기도 같은 규칙', () {
    final out = sortPhotosByDay([p('nodate', '', sep25), p('aug', '2026-08-10')], asc: true);
    expect(out.map((x) => x['id']), ['aug', 'nodate']);
  });

  test('사진첩이 그 셈을 쓴다', () {
    final s = File('lib/ui/album.dart').readAsStringSync();
    expect(s, contains('sortPhotosByDay('));
  });
}
