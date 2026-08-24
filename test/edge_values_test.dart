// 「범위」를 따지는 자리들이 엉터리 값에 정말 견디는지 (116회차).
//
// 116회차에 훑은 것: 날짜 고르기(115회차에 고침) · 슬라이더 · 탭 번호 · 글자 자르기 12곳 · 목록 인덱스.
// 새 버그는 못 찾았고, 지킴이가 «형태»만 있는 게 아니라 정말 듣는지 값으로 확인해 둔다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/ui/common.dart';

const _junk = ['', ' ', '2026', '2026-8', '어제', '2026-13-45', '２０２６-０８-２３'];

void main() {
  test('날짜를 «보여 주는» 자리가 안 터진다', () {
    for (final s in [..._junk, null]) {
      expect(() => fmtDateFull(s), returnsNormally, reason: '$s');
    }
    expect(fmtDateFull(null), '날짜 없음');
    expect(fmtDateFull('2026'), '날짜 없음', reason: '열 글자가 안 되면 날짜로 안 본다');
    // 있지도 않은 날은 «그럴듯하게» 고쳐 보여주지 않는다
    expect(fmtDateFull('2026-13-45'), '2026-13-45');
  });

  test('날짜를 «읽는» 자리가 안 터진다', () {
    for (final s in [..._junk, null]) {
      expect(() => parseYmd(s), returnsNormally, reason: '$s');
    }
    expect(parseYmd('2026-08-23'), DateTime(2026, 8, 23));
  });

  test('돈·시각을 보여 주는 자리', () {
    for (final n in [null, 0, -1, 1 << 62]) {
      expect(() => fmtWon(n), returnsNormally, reason: '$n');
    }
    expect(fmtWon(null), '0원');
    expect(fmtWon(-50000), '-50,000원');
  });

  test('출석·투표 열쇠가 망가져도 세기가 안 터진다', () {
    AppState.i.couple = Store.tidyCouple({
      'members': {'u1': {'uid': 'u1', 'name': '갑', 'role': 'member'}}
    });
    final e = {
      'id': 'e1', 'type': 'event', 'date': '2026-08-29', 'repeat': 'none',
      'rsvp': {'': 'yes', '짧': 'yes', '2026-08-29_': 'yes', '2026-08-29_u1': 'yes',
               '2026-08-29': 'yes'},
      'attend': {'': true, '짧': true, '2026-08-29_u1': true},
      'createdAt': 1755800000000,
    };
    AppState.i.setItems(Store.tidy([e]));
    final ev = AppState.i.by('event').first;
    expect(() => Logic.rsvpCount(ev, '2026-08-29', 'yes'), returnsNormally);
    expect(Logic.rsvpCount(ev, '2026-08-29', 'yes'), 1, reason: '멀쩡한 한 표만');
    expect(() => Logic.attendStats(), returnsNormally);
  });

  test('글자 자르기가 짧은 값에도 안 터진다', () {
    for (final s in ['', '가', '가' * Store.oneLineMax, '가' * 5000]) {
      expect(() => Store.cutLine(s), returnsNormally, reason: '길이 ${s.length}');
    }
    expect(Store.cutLine(''), '');
  });

  test('날짜 고르기에 줄 값은 «어떤 값이 와도» 범위 안이다', () {
    final first = DateTime(1920), last = DateTime(2020, 12, 31);
    for (final d in [
      DateTime(1800), DateTime(2100), DateTime(1920), DateTime(2020, 12, 31),
      DateTime(1990, 3, 2),
    ]) {
      final c = clampDate(d, first, last);
      expect(c.isBefore(first), isFalse, reason: '$d');
      expect(c.isAfter(last), isFalse, reason: '$d');
    }
  });

  testWidgets('엉터리 시각이 저장돼 있어도 시각 고르기가 열린다', (t) async {
    // '25:70' 같은 값이 저장돼 있을 수 있다 — 열리기만 하면 회원이 고칠 수 있다
    for (final s in ['19:30', '25:70', '99:99']) {
      final p = s.split(':');
      final tod =
          TimeOfDay(hour: int.tryParse(p[0]) ?? 19, minute: int.tryParse(p[1]) ?? 0);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => ElevatedButton(
              onPressed: () => showTimePicker(context: c, initialTime: tod),
              child: const Text('열기'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('열기'));
      await t.pump();
      expect(t.takeException(), isNull, reason: s);
    }
  });
}
