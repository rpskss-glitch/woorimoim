import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🛑 「물었으면 «아니오»를 지킨다 · 취소하면 그대로 둔다 · 듣기는 한 번만 건다」.

   181회차에 흠을 «기계로» 뽑아 흔들었더니(`tool/shake.py`) 이 세 갈래가 안 물렸다.
   셋 다 회원 눈에는 «앱이 제멋대로 구는» 것으로 보인다:
     · 「취소」를 눌렀는데 그대로 진행된다 (방장이 넘어가고, 방이 지워진다)
     · 날짜 고르기를 «취소»했는데 적어 둔 생년월일이 지워진다
     · 알림 듣기를 여러 번 걸어 **같은 알림이 여러 번** 뜬다 */
void main() {
  String bare(String p) => File(p)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  List<String> libFiles() => [
        for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.dart')) f.path.replaceAll(r'\', '/')
      ];

  test('물었으면 «아니오»일 때 그만둔다', () {
    final bad = <String>[];
    var n = 0;
    for (final f in libFiles()) {
      final s = bare(f);
      for (final m in RegExp(r'(?:final|var)\s+(\w+)\s*=\s*await confirmSheet\(').allMatches(s)) {
        n++;
        final name = m[1]!;
        final rest = s.substring(m.end);
        // 다음 물음이 나오기 «전»까지만 본다 — 고정 글자 창을 안 쓴다
        final stop = rest.indexOf('confirmSheet(');
        final win = stop < 0 ? rest : rest.substring(0, stop);
        /* 두 가지 모양을 다 받아들인다:
             · `if (!ok) return;`  — 아니라고 하면 그만둔다
             · `if (give) { … }`   — 그렇다고 할 때만 «더» 한다(덧붙이는 물음)
           잡아야 하는 것은 «결과를 아예 안 보는» 자리다.
           ⚠️ 괄호는 «문자 종류»로 적는다 — 역슬래시는 손을 타면 사라져서
              `if (…)` 가 «묶음»으로 읽혀 무엇과도 안 맞는다(181회차에 그렇게 틀렸다). */
        if (!RegExp('if [(]!$name').hasMatch(win) &&
            !RegExp('if [(]$name[)]').hasMatch(win)) {
          bad.add('$f: $name');
        }
      }
    }
    expect(n, greaterThan(8), reason: '물어보는 자리를 못 읽었다 — 이 시험이 헛돌고 있다');
    expect(bad, isEmpty,
        reason: '「취소」를 눌렀는데도 그대로 진행한다 — '
            '되돌릴 수 없는 일(방장 넘기기·방 지우기·탈퇴)이 그냥 일어난다: $bad');
  });

  test('고르기를 «취소»하면 있던 값을 그대로 둔다', () {
    final bad = <String>[];
    var n = 0;
    for (final f in libFiles()) {
      final s = bare(f);
      for (final m
          in RegExp(r'(?:final|var)\s+(\w+)\s*=\s*await show(?:Date|Time)Picker\(').allMatches(s)) {
        n++;
        final name = m[1]!;
        final rest = s.substring(m.end);
        final stop = rest.indexOf('Picker(');
        final win = stop < 0 ? rest : rest.substring(0, stop);
        final guarded = RegExp('if [(]$name != null[)]').hasMatch(win) ||
            RegExp('if [(]$name == null[)] return').hasMatch(win);
        if (!guarded) bad.add('$f: $name');
      }
    }
    expect(n, greaterThan(3), reason: '고르는 자리를 못 읽었다 — 이 시험이 헛돌고 있다');
    expect(bad, isEmpty,
        reason: '고르기를 취소했는데 «없음»을 그대로 써 버린다 — '
            '적어 둔 생년월일·날짜가 지워진다: $bad');
  });

  test('듣기는 «한 번만» 건다', () {
    /* 겹겹이 걸면 같은 알림이 여러 번 뜨고, 토큰이 갱신될 때마다 같은 쓰기가 여러 번 나간다
       (그 쓰기는 구독 중인 회원 수만큼 읽기 요금으로 곱해진다). */
    final s = bare('lib/push.dart');
    for (final flag in const ['_msgBound', '_tapsBound', '_refreshBound']) {
      expect(s, contains('if ($flag) return'),
          reason: '$flag 막이가 없다 — 듣기가 겹겹이 쌓인다');
      final at = s.indexOf('if ($flag) return');
      expect(s.substring(at, s.indexOf(';', s.indexOf('$flag = true', at)) + 1),
          contains('$flag = true'),
          reason: '$flag 를 막기만 하고 «세우지» 않는다');
    }
    // 듣기를 거는 곳이 그 막이 «뒤»에 있어야 한다
    final listen = s.indexOf('onMessage.listen(');
    final guard = s.indexOf('if (_msgBound) return');
    expect(guard, greaterThan(0));
    expect(guard, lessThan(listen), reason: '막이가 듣기보다 뒤에 있다');
  });
}
