import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 💰 장부의 «수입/지출»을 어디서나 같은 규칙으로 센다 — 「in 만 수입, 나머지는 지출」.

   2026-09-25 조사: 잔액·통계는 위 규칙인데, 회비 탭의 «이번 달» 칸만 거꾸로
   「out 만 지출, 나머지는 수입」이었다. 종류가 빠진 기록 하나(웹의 백업 복원으로 들어올 수 있다)가
   잔액에서는 빠지고, 같은 화면 «이번 달 수입»에는 더해져 두 숫자가 서로 안 맞았다. */
void main() {
  final st = AppState.i;
  final month = DateTime.now().toIso8601String().substring(0, 7);

  tearDown(() => st.setItems([]));

  test('종류가 빠진 기록은 잔액에서 «지출»이다 (기준)', () {
    st.setItems(Store.tidy([
      {'id': 'a', 'type': 'ledger', 'kind': 'in', 'amount': 50000, 'date': '$month-01'},
      {'id': 'b', 'type': 'ledger', 'amount': 20000, 'date': '$month-02'}, // 종류 없음
    ]));
    expect(Logic.balance(), 30000);
  });

  test('이번 달 칸·홈 카드가 잔액과 같은 규칙을 쓴다', () {
    final wallet = File('lib/ui/wallet.dart').readAsStringSync();
    final at = wallet.indexOf('var mIn = 0, mOut = 0;');
    expect(at, greaterThan(0));
    final loop = wallet.substring(at, wallet.indexOf('Widget box(', at));
    expect(loop, contains("if (l['kind'] == 'in') {"),
        reason: '«out 만 지출»이면 종류 없는 기록이 이번 달 수입으로 잡힌다');

    final home = File('lib/ui/home.dart').readAsStringSync();
    final h = home.indexOf('var monthOut = 0;');
    final hl = home.substring(h, home.indexOf('Widget box(', h));
    expect(hl, contains("l['kind'] != 'in'"), reason: '홈의 이번 달 지출이 잔액과 다른 규칙을 쓴다');
  });

  test('«kind == out» 만 지출로 세는 자리가 lib 에 없다', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (code.contains("['kind'] == 'out'")) bad.add('${f.path}:${i + 1}  ${lines[i].trim()}');
      }
    }
    expect(bad, isEmpty,
        reason: '«out 만 지출»은 잔액 규칙(in 만 수입)과 어긋난다:\n${bad.join('\n')}');
  });
}
