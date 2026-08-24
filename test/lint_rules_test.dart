// 검사 규칙이 «조용히 꺼지지» 않게 (97회차).
//
// 이 규칙들은 이 루프에서 실제로 났던 병에 맞춰 골랐다.
// 켜기 전에 하나씩 재보고 «지금 코드가 이미 지키고 있는 것»만 켰으므로,
// 지금 어긋나는 곳은 새로 생긴 것이다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 켠 규칙과 «왜 켰는지»
const _rules = {
  'unawaited_futures': '결과를 안 받는 Future 에서 오류가 «아무 말 없이» 새어 나간다 (76·81회차)',
  'cancel_subscriptions': '구독을 안 끊으면 방을 옮겨도 옛 방 소식이 계속 들어온다',
  'close_sinks': '싱크를 안 닫으면 화면이 사라진 뒤에도 값이 흘러든다',
  'avoid_dynamic_calls': '값이 망가지면 그 자리에서 터진다 (53·56회차)',
  'throw_in_finally': 'finally 에서 던지면 원래 오류가 통째로 사라진다',
  'avoid_empty_else': '',
  'no_adjacent_strings_in_list': '',
  'literal_only_boolean_expressions': '',
};

void main() {
  test('고른 검사 규칙이 그대로 켜져 있다', () {
    /* ⚠️ 그냥 «들어 있나»로 보면 주석 처리한 줄(`# - 규칙`)도 통과한다 —
       85·94회차와 같은 갈래다. 주석을 걷어내고 «살아 있는 줄»만 본다. */
    final live = File('analysis_options.yaml')
        .readAsLinesSync()
        .map((l) => l.trim())
        .where((l) => !l.startsWith('#'))
        .toSet();
    for (final e in _rules.entries) {
      expect(live.contains('- ${e.key}'), isTrue,
          reason: '«${e.key}» 가 꺼졌다${e.value.isEmpty ? '' : ' — ${e.value}'}');
    }
  });

  test('일부러 안 기다리는 자리는 «그렇다고 적어» 둔다', () {
    for (final f in ['lib/store.dart', 'lib/ui/chat.dart']) {
      final s = File(f).readAsStringSync();
      expect(s.contains('unawaited('), isTrue, reason: f);
      expect(s.contains("import 'dart:async';"), isTrue, reason: '$f — 안 불러오면 안 돈다');
    }
    // 「일부러」인 이유가 적혀 있어야 다음 사람이 지우지 않는다
    final store = File('lib/store.dart').readAsStringSync();
    expect(store.contains('일부러'), isTrue);
  });

  test('규칙을 켜 둔 자리에 «왜»가 적혀 있다', () {
    final s = File('analysis_options.yaml').readAsStringSync();
    expect(s.contains('76·81회차'), isTrue, // 주석이어도 된다 (일부러 «설명»이 있는지 보는 것)
        reason: '왜 켰는지 안 적으면 다음에 시끄럽다고 그냥 끈다');
  });
}
