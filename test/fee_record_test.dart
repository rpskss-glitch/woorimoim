// 회비 기록이 «어느 달치»인지 남는가 (135회차).
//
// 장부 줄은 «두 달 이상일 때만» 기간을 보여 줬다. 그래서 3월에 밀린 1월치를 받으면
// 줄에는 기록한 날(3월)만 남아, 나중에 총무가 **어느 달치였는지 알 길이 없었다.**
// (알림 문구는 그때도 보여 줬다 — 남는 기록만 빠져 있었다)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

void main() {
  test('한 달치도 «어느 달»인지 남는다', () {
    expect(Logic.feeSpan(['2025-01']), '2025-01치');
  });

  test('여러 달치는 처음~끝으로 남는다', () {
    expect(Logic.feeSpan(['2025-01', '2025-02', '2025-03']), '2025-01~2025-03치');
  });

  test('회비가 아닌 기록(지출)은 아무것도 안 붙인다', () {
    expect(Logic.feeSpan(null), isNull);
    expect(Logic.feeSpan(const []), isNull);
  });

  test('망가진 값이 와도 안 터진다', () {
    // 서버·백업에서 오는 값은 배열이 아닐 수도, 안에 숫자가 섞일 수도 있다
    expect(Logic.feeSpan('2025-01'), isNull);
    expect(Logic.feeSpan(const [1, 2]), isNull);
    expect(Logic.feeSpan(const ['2025-01', 7]), '2025-01치');
  });

  test('장부 줄과 알림 문구가 «같은 말»을 한다', () {
    final code = stripComments(File('lib/ui/wallet.dart').readAsStringSync());
    expect(RegExp(r'Logic\.feeSpan\(').allMatches(code).length, 2,
        reason: '한쪽만 고치면 또 어긋난다 — 줄과 문구가 같은 문을 써야 한다');
    expect(code.contains('months.length > 1'), isFalse,
        reason: '«두 달 이상일 때만» 보여 주던 옛 규칙이 돌아왔다');
  });

  test('메울 달이 없으면 «아무 말 없이» 끝내지 않는다', () {
    final code = stripComments(File('lib/ui/wallet.dart').readAsStringSync());
    final at = code.indexOf('feeMonths.isEmpty');
    expect(at, greaterThan(0));
    final after = code.substring(at, (at + 220).clamp(at, code.length));
    expect(after.contains('toast('), isTrue,
        reason: '눌렀는데 아무 일도 안 일어나는 단추가 된다');
  });

  test('같은 달을 두 번 기록하지 못하게 «고정 문서 이름»을 쓴다', () {
    /* 총무 둘이 거의 동시에 눌렀을 때의 진짜 막이는 이것 하나뿐이다. */
    final code = stripComments(File('lib/ui/wallet.dart').readAsStringSync());
    expect(code.contains('docId: Store.feeDocId('), isTrue);
    expect(RegExp(r'feeDocId\(\s*code,\s*uid,\s*feeMonths\.first\s*\)').hasMatch(code),
        isTrue, reason: '「누가·어느 달부터」가 이름에 들어가야 겹치지 않는다');
  });
}
