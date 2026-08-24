// 답장 인용·통장 색·보내기 실패 되돌리기 (92회차).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';

void main() {
  group('번호로 한 건 찾기', () {
    setUp(() {
      AppState.i.setItems([
        {'id': 'm1', 'type': 'msg', 'text': '첫 말', 'createdAt': 1},
        {'id': 'm2', 'type': 'msg', 'text': '답장', 'replyTo': 'm1', 'createdAt': 2},
        {'id': 'd1', 'type': 'diary', 'text': '글', 'createdAt': 3},
      ]);
    });

    test('있는 번호는 그 기록을 준다', () {
      expect(AppState.i.byId('m1')?['text'], '첫 말');
      expect(AppState.i.byId('d1')?['type'], 'diary');
    });

    test('없는 번호·null 은 조용히 null', () {
      expect(AppState.i.byId('없는것'), isNull);
      expect(AppState.i.byId(null), isNull);
    });

    test('기록이 갈리면 표도 같이 갈린다', () {
      AppState.i.setItems([
        {'id': 'z9', 'type': 'msg', 'text': '새것', 'createdAt': 9}
      ]);
      expect(AppState.i.byId('m1'), isNull, reason: '옛 표가 남으면 지운 대화가 인용에 계속 보인다');
      expect(AppState.i.byId('z9')?['text'], '새것');
    });

    test('번호가 글자가 아니어도 죽지 않는다', () {
      AppState.i.setItems([
        {'id': 7, 'type': 'msg', 'text': '망가짐'},
        {'type': 'msg', 'text': '번호 없음'},
        {'id': 'ok', 'type': 'msg', 'text': '멀쩡'},
      ]);
      expect(AppState.i.byId('ok')?['text'], '멀쩡');
      expect(AppState.i.byId('7'), isNull);
    });

    test('채팅이 이 표를 실제로 쓴다', () {
      final src = File('lib/ui/chat.dart').readAsStringSync();
      expect(src.contains('st.byId(replyId)'), isTrue);
      expect(src.contains("by('msg').where((x) => x['id'] == replyId)"), isFalse,
          reason: '말풍선마다 전체를 훑는 옛 방식이 남아 있다');
    });
  });

  test('통장이 마이너스면 «나간 돈» 색으로 보여준다', () {
    final src = File('lib/ui/wallet.dart').readAsStringSync();
    // 통장 카드
    final at = src.indexOf('final bal = Logic.balance();');
    expect(at, greaterThan(0));
    expect(src.substring(at, at + 400).contains('bal < 0 ? moneyOut(context)'), isTrue,
        reason: '마이너스인데 강조색이면 총무가 괜찮은 줄 안다');
    // 통계 탭의 「남은 돈」
    final st = src.indexOf("_StatRow('남은 돈'");
    expect(st, greaterThan(0));
    expect(src.substring(st, st + 220).contains('moneyOut(context)'), isTrue);
  });

  test('보내기에 실패해도 «지금 쓰는 글»을 덮어쓰지 않는다', () {
    final src = File('lib/ui/chat.dart').readAsStringSync();
    final at = src.indexOf('Future<void> _send()');
    final body = src.substring(at, src.indexOf('\n  }\n', at));
    expect(body.contains('final busy = _textC.text.trim().isNotEmpty;'), isTrue,
        reason: '보내기는 6초까지 걸린다 — 그동안 다음 말을 치고 있을 수 있다');
    expect(body.contains('if (!busy) _textC.text = text;'), isTrue);
    expect(body.contains('먼저 쓴 글을 보내지 못했어요'), isTrue,
        reason: '못 되돌렸으면 그렇다고 말해야 한다');
  });
}
