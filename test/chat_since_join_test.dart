import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

/* 💬 대화는 «내가 들어온 때»부터만 받는다.

   2026-09-25 사장님: 「대화창은 가입한 시점부터 보여줘야지 — 그전 것까지 전부 보이면
   용량이 늘어나는 거 아니야?」
   예전에는 새 회원도 최근 대화 200개를 통째로 받았다(들어오기 전 이야기까지).

   ⚠️ 자르는 곳이 «두 군데»다 — 평소 받는 창(실시간 구독)과 「이전 대화 더 보기」.
      한쪽만 자르면 위로 올려서 들어오기 전 대화를 다 받게 된다. */

/// 주석을 걷어낸 코드만 본다 — 내 설명글에 시험이 걸리면 안 된다.
String codeOf(String path) {
  final nl = String.fromCharCode(10);
  return File(path).readAsStringSync().replaceAll(String.fromCharCode(13), '').split(nl).map((l) {
    final t = l.trimLeft();
    if (t.startsWith('//') || t.startsWith('/*') || t.startsWith('*')) return '';
    return l.split('//').first;
  }).join(nl);
}

String bodyOf(String src, String head) {
  final at = src.indexOf(head);
  expect(at, greaterThanOrEqualTo(0), reason: '$head 을 못 찾았다');
  var depth = 0;
  // 머리글 «뒤»부터 찾는다 — 머리글 안의 {int n = 200} 같은 괄호를 본문으로 잡지 않게
  for (var i = src.indexOf('{', at + head.length); i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}' && --depth == 0) return src.substring(at, i + 1);
  }
  return src.substring(at);
}

void main() {
  group('자르는 선', () {
    test('가입 시각이 없으면 자르지 않는다 (옛 회원은 예전처럼 다 본다)', () {
      expect(Store.chatFloor(null), isNull);
    });

    test('가입 시각에서 5분 앞 — 폰끼리 시계가 어긋나도 환영 인사가 안 잘린다', () {
      const joined = 1790000000000;
      expect(Store.chatFloor(joined), joined - 5 * 60 * 1000);
      expect(Store.chatFloor(joined)!, lessThan(joined));
    });
  });

  group('서버에 묻는 곳', () {
    final store = codeOf('lib/store.dart');

    test('대화 묻기에 «가입 시각 이후» 조건이 붙는다', () {
      final q = bodyOf(store, 'msgsQuery(String code)');
      expect(q, contains("'createdAt', isGreaterThanOrEqualTo:"),
          reason: '선을 안 긋으면 들어오기 전 대화까지 다 받는다');
      expect(q, contains('_chatSince'));
    });

    test('평소 받는 창이 그 묻기를 쓴다', () {
      final sub = bodyOf(store, 'void subItems(');
      expect(sub, contains('msgsQuery(code)'), reason: '실시간 창이 선 없이 묻는다');
      expect(sub.contains("col('msgs')"), isFalse,
          reason: '대화를 선 없이 직접 묻는 길이 남아 있다');
    });

    test('「이전 대화 더 보기」도 같은 선에서 멈춘다', () {
      // ⚠️ 매개변수에 {int n = 200} 이 있어 «본문의 여는 괄호»까지 머리에 넣는다
      final older = bodyOf(store, 'Future<int> loadOlder(String code, {int n = 200}) async');
      expect(older, contains('msgsQuery(code)'),
          reason: '위로 올리면 들어오기 전 대화를 다 받는다');
    });

    test('가입 시각을 안 «뒤»에 대화를 연다 — 두 번 받지 않게', () {
      final sub = bodyOf(store, 'void subItems(');
      final make = sub.indexOf('_startMsgs = () {');
      final listen = sub.indexOf('.listen(', make);
      expect(make, greaterThan(0), reason: '대화 구독을 바로 열면 선 없이 한 번, 선 긋고 또 한 번 받는다');
      expect(listen, greaterThan(make));
    });

    test('모임 정보가 끝내 안 오면 예전처럼 다 받는다 (영영 «불러오는 중»에 멈추지 않게)', () {
      final sub = bodyOf(store, 'void subItems(');
      expect(sub, contains('Future.delayed('));
      expect(sub, contains('setChatSince(null)'));
    });

    test('기다리는 동안은 «불러오는 중»이다 — 빈 대화방이 잠깐 뜨면 안 된다', () {
      final at = store.indexOf('bool get chatLoading');
      final line = store.substring(at, store.indexOf(';', at));
      expect(line, contains('!_chatSinceKnown'));
    });

    test('같은 선이면 다시 안 건다 (스냅샷마다 부르므로 — 읽기 요금)', () {
      final set = bodyOf(store, 'void setChatSince(');
      expect(set, contains('if (_chatSinceKnown && since == _chatSince) return;'));
    });
  });

  group('모임 정보가 올 때', () {
    test('내 가입 시각으로 선을 긋는다', () {
      final main = codeOf('lib/main.dart');
      expect(main, contains('Store.i.setChatSince(Store.chatFloor('));
      expect(main, contains("['joinedAt']"));
    });

    test('«가벼운 갱신»으로 빠지기 전에 긋는다', () {
      final main = codeOf('lib/main.dart');
      final set = main.indexOf('Store.i.setChatSince(');
      final lite = main.indexOf('if (_onlyLive(before, c))');
      expect(set, greaterThan(0));
      expect(lite, greaterThan(0));
      expect(set, lessThan(lite),
          reason: '입력중·읽음만 바뀐 스냅샷에서 건너뛰면 대화가 계속 «불러오는 중»에 머문다');
    });

    test('승인 전(대기 중)에는 긋지 않는다 — 아직 볼 자격이 없다', () {
      final main = codeOf('lib/main.dart');
      final set = main.indexOf('Store.i.setChatSince(');
      final notMember = main.indexOf('if (!isMember) {');
      expect(notMember, greaterThan(0));
      expect(set, greaterThan(notMember), reason: '회원 확인보다 먼저 대화를 연다');
    });
  });
}
