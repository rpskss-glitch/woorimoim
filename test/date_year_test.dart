// 날짜에 «연도»가 보이는가 (140회차).
//
// 지난 회차 목록과 옛 대화는 몇 년치를 한 줄로 늘어놓는데, 연도가 없으면
// 2년 전 모임과 올해 모임이 똑같이 「8월 3일」로 보인다 — 회원은 구분할 길이 없다.
// (회비 장부는 처음부터 `2025-03-15` 로 연도를 보여 준다 — 두 곳이 어긋나 있었다)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/ui/common.dart';

Future<int> over(WidgetTester t, Widget w,
    {double width = 320, double scale = 1.3}) async {
  final errs = <String>[];
  final prev = FlutterError.onError;
  FlutterError.onError = (d) => errs.add(d.exception.toString());
  t.view.physicalSize = Size(width, 640);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: MaterialApp(home: Scaffold(body: w)),
  ));
  FlutterError.onError = prev;
  return errs.where((e) => e.contains('overflow')).length;
}

void main() {
  final thisYear = DateTime.now().year;

  test('올해 날짜에는 연도를 안 붙인다 (거의 모든 줄이 올해다)', () {
    final s = fmtDateFull('$thisYear-08-03');
    expect(s.contains('년'), isFalse, reason: '올해 것까지 붙이면 되레 읽기 나쁘다');
    expect(s.startsWith('8월 3일'), isTrue);
  });

  test('올해가 아니면 연도를 붙인다', () {
    expect(fmtDateFull('2024-08-03'), startsWith('2024년 8월 3일'));
    expect(fmtDateFull('${thisYear + 1}-01-01'), startsWith('${thisYear + 1}년 1월 1일'));
  });

  test('요일이 맞다 — 한 해를 통째로 견줘 본다', () {
    /* 요일 표는 월요일부터 시작하고 DateTime.weekday 도 월요일이 1이다.
       한 칸만 밀려도 앱의 모든 날짜가 틀리므로 통째로 확인한다. */
    const names = ['월', '화', '수', '목', '금', '토', '일'];
    var d = DateTime(2026, 1, 1);
    while (d.year == 2026) {
      final s = fmtDateFull(
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
      expect(s, endsWith('(${names[d.weekday - 1]})'), reason: '$d 의 요일이 틀리다');
      d = d.add(const Duration(days: 1));
    }
  });

  test('있지도 않은 날짜는 «적힌 그대로» 보여준다', () {
    // 날짜 읽기는 2026-13-45 를 2027년 2월 14일로 조용히 넘겨 준다 — 믿게 두면 안 된다
    expect(fmtDateFull('2026-13-45'), '2026-13-45');
    expect(fmtDateFull('2026-02-30'), '2026-02-30');
  });

  test('없거나 짧은 값은 「날짜 없음」', () {
    expect(fmtDateFull(null), '날짜 없음');
    expect(fmtDateFull('2026-08'), '날짜 없음');
  });

  testWidgets('연도가 붙어도 일정 줄이 안 넘친다 (320px · 글자 1.3배)', (t) async {
    final line = '${fmtDateFull('2024-12-31')} 19:00 · ${'체육관' * 6}';
    expect(
        await over(
            t,
            Row(children: [
              const Icon(Icons.event),
              const SizedBox(width: 8),
              Expanded(child: Text(line)),
            ])),
        0);
  });
}
