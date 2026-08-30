// 날짜 고르기가 «저장된 값» 때문에 터지지 않는지 (115회차).
//
// `showDatePicker` 는 `initialDate` 가 범위 밖이면 그 자리에서 터진다(assert).
// 저장된 값이 그럴 수 있다: 잘못 적힌 생년월일(2023년·1900년), 2020년 전에 시작한 모임,
// 「끝나는 날」이 모임 날보다 앞선 기록. 그러면 **날짜 단추를 누르는 순간 화면이 빨개진다.**
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/ui/common.dart';

/// 그 값으로 날짜 고르기를 열었을 때 터지는지
Future<bool> opens(WidgetTester t, DateTime init, DateTime first, DateTime last) async {
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (c) => ElevatedButton(
          onPressed: () => showDatePicker(
              context: c, initialDate: init, firstDate: first, lastDate: last),
          child: const Text('열기'),
        ),
      ),
    ),
  ));
  await t.tap(find.text('열기'));
  await t.pump();
  await t.pump();
  final bad = t.takeException() != null;
  return !bad;
}

void main() {
  group('범위 안으로 당기기', () {
    final first = DateTime(1920), last = DateTime(2020, 12, 31);

    test('안쪽 값은 그대로', () {
      final d = DateTime(1990, 3, 2);
      expect(clampDate(d, first, last), d);
    });

    test('너무 뒤면 마지막 날로', () {
      expect(clampDate(DateTime(2023, 5, 1), first, last), last);
    });

    test('너무 앞이면 첫날로', () {
      expect(clampDate(DateTime(1900), first, last), first);
    });

    test('경계값은 그대로', () {
      expect(clampDate(first, first, last), first);
      expect(clampDate(last, first, last), last);
    });
  });

  group('실제로 열어 보면', () {
    final bFirst = DateTime(1920), bLast = DateTime(2020, 12, 31);

    /* ⚠️ 「당기지 않으면 터진다」는 시험으로 못 붙잡는다 —
       `showDatePicker` 의 assert 는 «비동기»라 시험틀이 먼저 그 시험을 실패시킨다(89회차와 같은 갈래).
       터지는 것은 프로브로 확인했고(생년월일 2023-05-01·1900-01-01 둘 다 _AssertionError),
       여기서는 «고쳐진 쪽»이 정말 열리는지를 지킨다. */
    testWidgets('당기면 잘 열린다', (t) async {
      for (final d in [DateTime(2023, 5, 1), DateTime(1900), DateTime(1990, 3, 2)]) {
        expect(await opens(t, clampDate(d, bFirst, bLast), bFirst, bLast), isTrue,
            reason: '$d');
      }
    });

    testWidgets('일정 날짜·끝나는 날도 당기면 열린다', (t) async {
      final eFirst = DateTime(2020), eLast = DateTime(2100);
      // 2020년 전에 시작한 모임
      expect(await opens(t, clampDate(DateTime(2015, 3, 1), eFirst, eLast), eFirst, eLast),
          isTrue);
      // 「끝나는 날」이 모임 날보다 앞선 기록
      final d = DateTime(2026, 8, 1);
      expect(await opens(t, clampDate(DateTime(2026, 1, 1), d, eLast), d, eLast), isTrue);
    });
  });

  test('앱의 모든 «날짜 고르기»가 범위 안으로 당긴다', () {
    final bad = <String>[];
    for (final f in Directory('lib/ui').listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      /* ⚠️ **주석은 걷어낸다.** 「showDatePicker 에 달만 고르는 모드가 없다」처럼
         설명에 이름이 나오면 코드도 아닌 자리를 잡아 헛짚는다(실제로 그랬다).
         줄 번호는 그대로 세야 하므로 주석을 «지우지 말고 빈칸으로» 바꾼다. */
      final raw = f.readAsStringSync();
      // 줄 번호는 그대로 세야 하므로, 주석은 «지우지 말고» 같은 길이의 빈칸으로 바꾼다
      final lf = String.fromCharCode(10);
      String blank(String t) =>
          t.split('').map((c) => c == lf ? c : ' ').join();
      final src = raw
          .replaceAllMapped(
              RegExp('/[*][\\s\\S]*?[*]/'), (m) => blank(m[0]!))
          .replaceAllMapped(RegExp('//[^' + lf + ']*'), (m) => blank(m[0]!));
      final name = f.uri.pathSegments.last;
      for (final m in RegExp('showDatePicker').allMatches(src)) {
        final body = src.substring(m.start, (m.start + 400).clamp(m.start, src.length));
        if (!body.contains('clampDate(')) {
          final line = String.fromCharCode(10).allMatches(src.substring(0, m.start)).length + 1;
          bad.add('$name:$line');
        }
      }
    }
    expect(bad, isEmpty,
        reason: '저장된 값이 범위 밖이면 «날짜 단추를 누르는 순간» 화면이 빨개진다: ${bad.join(', ')}');
  });
}
