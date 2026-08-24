// 회비 달 셈 (128회차).
//
// 회비 화면은 «회원 줄마다» 밀린 달·선납을 센다. 그 셈이 달마다 `DateTime` 을 세우고 있었는데
// 지역 시간대를 찾느라 한 번에 수십 ㎲가 든다 → 실측 `unpaidMonths` 한 번에 790㎲,
// **회원 50명이면 한 번 그리는 데 39ms.** 회비 탭은 IndexedStack 안에 살아 있어
// 채팅 한 줄만 와도 그 값을 치렀다. 정수 셈으로 바꿔 2.1ms.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// 함수 «몸통»만 떼어낸다.
/// ⚠️ 이름 뒤 첫 `{` 를 잡으면 안 된다 — 그건 「이름 있는 매개변수」다(120회차).
///    매개변수 괄호를 짝 맞춰 닫은 «뒤»의 `{` 부터 잡는다.
String bodyOf(String src, String decl) {
  final at = src.indexOf(decl);
  if (at < 0) return '';
  var i = src.indexOf('(', at), d = 0;
  for (; i < src.length; i++) {
    if (src[i] == '(') d++;
    if (src[i] == ')') {
      d--;
      if (d == 0) break;
    }
  }
  final open = src.indexOf('{', i);
  d = 0;
  for (var j = open; j < src.length; j++) {
    if (src[j] == '{') d++;
    if (src[j] == '}') {
      d--;
      if (d == 0) return src.substring(open, j + 1);
    }
  }
  return src.substring(open);
}

/// 옛 셈 — 달을 `DateTime` 으로 만들던 방식. 답이 같은지 견주는 잣대다.
String oldKey(int y, int mo) {
  final m = DateTime(y, mo);
  return '${m.year}-${m.month.toString().padLeft(2, '0')}';
}

void seed({Map<String, dynamic>? fee, int joinedAt = 1690000000000}) {
  AppState.i.couple = Store.tidyCouple({
    'members': {
      'u1': {'uid': 'u1', 'name': '갑', 'joinedAt': joinedAt}
    },
    'fee': fee ?? {'amount': 20000},
  });
}

void main() {
  test('정수 달 셈이 옛 셈과 «똑같다» (해 넘김·음수 달 포함)', () {
    var bad = <String>[];
    for (var y = 1900; y <= 2100; y++) {
      for (var mo = -24; mo <= 36; mo++) {
        final a = oldKey(y, mo);
        final b = Logic.ymKey(y * 12 + mo - 1);
        if (a != b) bad.add('y=$y mo=$mo 옛=$a 새=$b');
      }
    }
    expect(bad, isEmpty, reason: '달이 어긋난다: ${bad.take(3).join(', ')}');
  });

  test('오늘 달을 제대로 집는다', () {
    final now = DateTime.now();
    expect(Logic.ymKey(Logic.ymOf(now)),
        '${now.year}-${now.month.toString().padLeft(2, '0')}');
  });

  test('들어오기 «전» 달은 밀린 것으로 안 센다', () {
    final now = DateTime.now();
    // 두 달 전에 들어온 회원
    final joined = DateTime(now.year, now.month - 2, 15);
    seed(joinedAt: joined.millisecondsSinceEpoch);
    AppState.i.setItems([]);
    final unpaid = Logic.unpaidMonths('u1');
    expect(unpaid.length, 3, reason: '들어온 달·지난달·이번 달 셋이라야 한다');
    expect(unpaid.first, Logic.ymKey(Logic.ymOf(joined)));
  });

  test('회비를 안 걷는 모임은 밀린 달이 없다', () {
    seed(fee: {'amount': 0});
    AppState.i.setItems([]);
    expect(Logic.unpaidMonths('u1'), isEmpty);
  });

  test('낸 달은 빼고, 선납은 앞으로 세다 «빈 달»에서 멈춘다', () {
    final now = DateTime.now();
    final ym = Logic.ymOf(now);
    seed(joinedAt: DateTime(now.year, now.month, 1).millisecondsSinceEpoch);
    AppState.i.setItems([
      {
        'id': 'f1', 'type': 'ledger', 'kind': 'in', 'payer': 'u1', 'amount': 60000,
        'date': '${Logic.ymKey(ym)}-05', 'createdAt': 1700000000000,
        // 이번 달 + 다음 두 달치를 미리 냈다 (그 다음 달은 비어 있다)
        'feeMonths': [Logic.ymKey(ym), Logic.ymKey(ym + 1), Logic.ymKey(ym + 2)],
      }
    ]);
    expect(Logic.unpaidMonths('u1'), isEmpty);
    expect(Logic.prepaidLeft('u1'), 2, reason: '앞으로 두 달이 채워져 있다');
    // 두 달치를 더 받으면 «빈 달부터» 메운다
    expect(Logic.feeMonthsToFill('u1', 2), [Logic.ymKey(ym + 3), Logic.ymKey(ym + 4)]);
  });

  test('띄엄띄엄 밀렸어도 «이미 낸 달»에 다시 얹지 않는다', () {
    final now = DateTime.now();
    final ym = Logic.ymOf(now);
    seed(joinedAt: DateTime(now.year, now.month - 3, 1).millisecondsSinceEpoch);
    AppState.i.setItems([
      {
        'id': 'f1', 'type': 'ledger', 'kind': 'in', 'payer': 'u1', 'amount': 20000,
        'date': '${Logic.ymKey(ym - 2)}-05', 'createdAt': 1700000000000,
        'feeMonths': [Logic.ymKey(ym - 2)], // 가운데 한 달만 냈다
      }
    ]);
    expect(Logic.unpaidMonths('u1'),
        [Logic.ymKey(ym - 3), Logic.ymKey(ym - 1), Logic.ymKey(ym)]);
    expect(Logic.feeMonthsToFill('u1', 3),
        [Logic.ymKey(ym - 3), Logic.ymKey(ym - 1), Logic.ymKey(ym)],
        reason: '이미 낸 달을 건너뛰어야 낸 만큼 미납이 준다');
  });

  test('회비 달 셈은 «돌면서» DateTime 을 세우지 않는다', () {
    final src = stripComments(File('lib/logic.dart').readAsStringSync());
    for (final decl in [
      'static List<String> unpaidMonths(',
      'static int prepaidLeft(',
      'static List<String> feeMonthsToFill(',
    ]) {
      final body = bodyOf(src, decl);
      expect(body, isNotEmpty, reason: '$decl 를 못 찾았다');
      // DateTime.now() / fromMillisecondsSinceEpoch 는 «한 번»만 쓰므로 괜찮다
      final made = RegExp(r'DateTime\((?!\))').allMatches(body).length;
      expect(made, 0,
          reason: '$decl: 달마다 DateTime 을 세우면 회원 수만큼 곱해져 화면이 걸린다');
    }
  });
}
