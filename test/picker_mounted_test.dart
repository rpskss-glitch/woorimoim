import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 📅 날짜·시간 고르는 창을 «기다린 뒤» 화면을 고칠 때는, 그 화면이 아직 있는지 먼저 본다.

   고르는 창이 떠 있는 동안 밑의 창이 닫힐 수 있다 — 다른 운영진이 그 일정을 지워
   목록이 다시 그려지거나, 모임에서 내보내져 화면이 통째로 바뀌는 때.
   그때 setState 를 부르면 「setState() called after dispose」로 터진다.
   2026-09-25 조사: 일정의 «날짜»는 막아 뒀는데 바로 옆 «시간»과 «끝나는 날»은 안 막혀 있었다. */
void main() {
  test('고르는 창 뒤의 setState 는 mounted 를 먼저 본다', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (!(l.contains('await showDatePicker(') || l.contains('await showTimePicker('))) {
          continue;
        }
        // 창을 기다린 뒤 처음 나오는 setState 까지 — 그 사이에 mounted 확인이 있어야 한다
        var guarded = false;
        for (var j = i + 1; j < lines.length && j < i + 25; j++) {
          final code = lines[j].split('//').first;
          if (code.contains('mounted')) guarded = true;
          if (code.contains('setState(')) {
            if (!guarded) bad.add('${f.path}:${j + 1}  ${lines[j].trim()}');
            break;
          }
        }
      }
    }
    expect(bad, isEmpty, reason: '고르는 창이 떠 있는 동안 화면이 닫히면 터진다:\n${bad.join('\n')}');
  });
}
