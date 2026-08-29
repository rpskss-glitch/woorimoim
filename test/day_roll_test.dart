// 날이 바뀌면 화면이 깨어나는가 (138회차).
//
// 「다가오는 모임」·「지난 회차」·「이번 달 순위」·「밀린 달」은 모두 «오늘»을 기준으로 센다.
// 그런데 자정에는 서버에서 아무것도 안 온다 → **다시 그릴 까닭이 없어 어제 것이 그대로 남는다.**
//   · 앱을 켜 둔 채 자정을 넘기면 그대로
//   · 11시 58분에 접었다 12시 1분에 다시 열어도 그대로
//     (「접속 표시」는 5분에 한 번이라 아무 쓰기도 안 나간다)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

void main() {
  test('다음 자정까지 남은 시간을 제대로 센다', () {
    expect(Logic.msUntilNextDay(DateTime(2026, 8, 23, 0, 0, 0)),
        const Duration(hours: 24).inMilliseconds);
    expect(Logic.msUntilNextDay(DateTime(2026, 8, 23, 23, 59, 59)), 1000);
    expect(Logic.msUntilNextDay(DateTime(2026, 8, 23, 12, 0, 0)),
        const Duration(hours: 12).inMilliseconds);
  });

  test('달·해가 넘어가도 맞다', () {
    // 2월 28일(윤년) → 29일, 12월 31일 → 다음 해 1월 1일
    expect(Logic.msUntilNextDay(DateTime(2024, 2, 28, 23, 0)),
        const Duration(hours: 1).inMilliseconds);
    expect(Logic.msUntilNextDay(DateTime(2026, 12, 31, 23, 0)),
        const Duration(hours: 1).inMilliseconds);
    expect(Logic.msUntilNextDay(DateTime(2026, 1, 31, 22, 0)),
        const Duration(hours: 2).inMilliseconds);
  });

  test('언제 재어도 «하루 안»이고 «0보다 크다»', () {
    for (var h = 0; h < 24; h++) {
      for (final m in [0, 17, 59]) {
        final v = Logic.msUntilNextDay(DateTime(2026, 3, 15, h, m, 30));
        expect(v, greaterThan(0), reason: '0 이하면 시계가 쉬지 않고 깨어난다');
        expect(v, lessThanOrEqualTo(const Duration(days: 1).inMilliseconds));
      }
    }
  });

  test('자정에 깨우는 시계가 걸려 있고, 끌 때 꺼진다', () {
    final code = stripComments(File('lib/main.dart').readAsStringSync());
    expect(code.contains('Logic.msUntilNextDay('), isTrue,
        reason: '깨우는 시계가 없으면 켜 둔 채 자정을 넘겼을 때 어제 것이 남는다');
    /* ⚠️ 「어딘가에 있나」만 보면 안 된다 — 제 정의 안에도 이름이 나오므로
       켜는 자리에서 «부르는지»를 봐야 한다(138회차에 미끼가 새어 나갔다). */
    /* ⚠️ 「첫 번째 initState」를 보면 안 된다 — main.dart 에는 화면이 여럿이라
       엉뚱한 화면의 것을 보게 된다(2026-08-29: 부팅 화면이 앞에 생기며 실제로 그랬다).
       시계를 거는 것은 **_WooriAppState** 다. 그 클래스 안에서 찾는다. */
    final cls = code.indexOf('class _WooriAppState');
    expect(cls, greaterThan(0), reason: '시계를 거는 화면이 사라졌다');
    final init = code.indexOf('void initState()', cls);
    expect(init, greaterThan(0));
    expect(code.substring(init, (init + 300).clamp(init, code.length))
        .contains('_armMidnight()'), isTrue,
        reason: '켤 때 안 걸면 시계가 아예 안 돈다');
    final dis = code.indexOf('void dispose()');
    expect(code.substring(dis, (dis + 300).clamp(dis, code.length))
        .contains('_midnight?.cancel()'), isTrue, reason: '끌 때 꺼야 한다');
    // 한 번 깨운 뒤 «다시» 걸어야 다음 날도 깨어난다
    final at = code.indexOf('_rollDay();');
    expect(code.substring(at, (at + 120).clamp(at, code.length)).contains('_armMidnight()'),
        isTrue, reason: '한 번만 깨우면 이튿날부터 다시 멈춘다');
  });

  test('다시 열 때도 날이 바뀌었는지 «먼저» 본다', () {
    /* 「접속 표시」는 5분 막이가 있어서, 11시 58분→12시 1분이면 아무 쓰기도 안 나간다.
       그 막이보다 «앞»에서 날을 봐야 화면이 깨어난다. */
    final code = stripComments(File('lib/main.dart').readAsStringSync());
    final touch = code.indexOf('void _touch()');
    expect(touch, greaterThan(0));
    final body = code.substring(touch, (touch + 400).clamp(touch, code.length));
    expect(body.contains('_rollDay()'), isTrue);
    expect(body.indexOf('_rollDay()') < body.indexOf('300000'), isTrue,
        reason: '5분 막이 뒤에 두면 다시 열어도 어제 것이 그대로다');
  });

  test('깨울 때는 «서버 값이 아니라» 화면만 다시 그린다', () {
    // 자정에 서버로 쓰기를 보내면 회원 수만큼 읽기 요금이 곱해진다
    final state = stripComments(File('lib/state.dart').readAsStringSync());
    expect(state.contains('void refresh() => notifyListeners();'), isTrue);
    final code = stripComments(File('lib/main.dart').readAsStringSync());
    final at = code.indexOf('void _rollDay()');
    final body = code.substring(at, (at + 300).clamp(at, code.length));
    expect(body.contains('st.refresh()'), isTrue);
    expect(body.contains('setCouple'), isFalse, reason: '자정마다 쓰기를 보내면 안 된다');
  });
}
