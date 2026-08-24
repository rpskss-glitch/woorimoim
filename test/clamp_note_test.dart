import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

/* 📅 「없는 날짜」가 생기는 반복 모임을 «미리 알려 준다».

   매달 31일 모임은 2월에 31일이 없다. 앱은 그 회차를 «그 달의 마지막 날»로 당긴다
   (밀어내면 3월 3일이 되고 그 뒤로 영영 3일이 된다 — 그래서 당기는 것이 옳다).
   실측 2026-08-24: 1월 31일 매달 → 1/31, **2/28**, 3/31, **4/30**, …
   셈은 옳지만 **화면이 그 말을 안 하면 방장은 모른다** —
   「매달 31일」로 정해 놓고 회원 화면에는 2월 28일 모임이 뜬다. */
void main() {
  group('알려 줘야 하는 경우', () {
    test('매달 29·30·31일', () {
      for (final d in [29, 30, 31]) {
        final note = Logic.clampNote('month', DateTime(2026, 1, d));
        expect(note, isNotNull, reason: '$d일 매달 모임인데 아무 말이 없다');
        expect(note, contains('$d일'), reason: '몇 일인지 안 알려 준다');
        expect(note, contains('마지막 날'));
      }
    });

    test('매년 2월 29일', () {
      final note = Logic.clampNote('year', DateTime(2024, 2, 29));
      expect(note, isNotNull);
      expect(note, contains('2월 28일'));
    });
  });

  group('알릴 것이 없는 경우 — 쓸데없이 겁주지 않는다', () {
    test('매달이라도 28일까지는 어느 달에나 있다', () {
      for (final d in [1, 15, 28]) {
        expect(Logic.clampNote('month', DateTime(2026, 1, d)), isNull, reason: '$d일');
      }
    });

    test('매주·2주·반복 없음은 날짜가 밀릴 일이 없다', () {
      for (final r in ['none', 'week', '2week']) {
        expect(Logic.clampNote(r, DateTime(2026, 1, 31)), isNull, reason: r);
      }
    });

    test('매년이라도 2월 29일이 아니면 알릴 것이 없다', () {
      expect(Logic.clampNote('year', DateTime(2026, 3, 31)), isNull);
      expect(Logic.clampNote('year', DateTime(2026, 2, 28)), isNull);
    });
  });

  test('알려 준 대로 «실제로» 그 날에 잡힌다', () {
    // 말과 셈이 어긋나면 안내가 오히려 거짓말이 된다
    final e = {
      'id': 'e', 'type': 'event', 'title': '모임',
      'date': '2026-01-31', 'repeat': 'month', 'until': '2026-05-31'
    };
    final got = Logic.occurrences(e, to: DateTime(2026, 5, 31));
    expect(got, ['2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30', '2026-05-31'],
        reason: '안내는 「마지막 날로 당긴다」인데 셈이 다르게 잡는다');
  });

  test('일정 만들기 화면이 그 말을 «보여 준다»', () {
    final s = File('lib/ui/calendar.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//.*'), '');
    expect(s, contains('Logic.clampNote(_repeat, _date)'),
        reason: '셈만 옳고 화면이 안 알려 준다 — '
            '방장은 「매달 31일」로 정했다고 믿는데 회원은 2월 28일에 모인다');
    // 반복 칸 «옆»에 있어야 눈에 띈다 — 반복을 고르는 자리보다 뒤
    expect(s.indexOf('Logic.clampNote'), greaterThan(s.indexOf("_repeat = e.key")),
        reason: '안내가 반복을 고르는 자리보다 앞에 있다');
  });
}
