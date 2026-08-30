// 지출 갈래가 두 앱에서 «하나로» 합쳐지는가 (146회차).
//
// 웹앱(아이폰 회원)은 영어 열쇠(`court`·`shuttle`…)로 적고 이 앱은 한글로 적는다.
// 그대로 두면 「어디에 썼나」에 영어가 뜨고, 더 나쁜 것은 같은 뜻인데 열쇠가 달라
// **합계가 두 줄로 갈린다**(셔틀콕 5만 · shuttle 3만).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

const _web = '../앞산배드민턴/index.html';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

void main() {
  test('웹앱이 적은 영어 열쇠를 한글로 읽는다', () {
    expect(Logic.catLabel('court'), '체육관');
    expect(Logic.catLabel('shuttle'), '셔틀콕');
    expect(Logic.catLabel('gear'), '용품');
    expect(Logic.catLabel('party'), '회식');
    expect(Logic.catLabel('game'), '대회');
    expect(Logic.catLabel('etc'), '기타');
  });

  test('이 앱이 적은 한글은 그대로 — 같은 갈래끼리 합쳐진다', () {
    for (final k in ['체육관', '셔틀콕', '회식', '대회', '용품', '기타']) {
      expect(Logic.catLabel(k), k);
    }
    // 핵심: 웹의 shuttle 과 앱의 셔틀콕이 «같은 이름»이 되어야 한 줄로 합쳐진다
    expect(Logic.catLabel('shuttle'), Logic.catLabel('셔틀콕'));
    expect(Logic.catLabel('court'), Logic.catLabel('체육관'));
  });

  test('갈래가 없으면 «아무 말도 안 한다» — 들어온 돈에는 갈래가 없다', () {
    expect(Logic.catLabel(null), isNull);
    expect(Logic.catLabel(''), isNull);
    expect(Logic.catLabel('   '), isNull);
    expect(Logic.catLabel(7), isNull);
  });

  test('모르는 갈래는 «적힌 그대로» 보여준다 (없는 말을 지어내지 않는다)', () {
    expect(Logic.catLabel('경조사'), '경조사');
    expect(Logic.catLabel('새갈래'), '새갈래');
  });

  test('회비 화면이 «세 곳 모두» 그 문을 쓴다', () {
    /* ⚠️ 「몇 번 나오나」로 세면 안 된다 — 쓰는 곳이 하나 늘 때마다 애먼 시험이 깨진다
       (148회차에 실제로 그랬다). «어디서» 쓰는지를 본다. */
    final w = stripComments(File('lib/ui/wallet.dart').readAsStringSync());
    for (final at in [
      "Logic.catLabel(x['cat']) ?? '기타'", // 갈래별 합계
      "Logic.catLabel(item['cat'])", // 장부 한 줄
      'Logic.catLabel(c) ?? c', // 고르는 칸
    ]) {
      expect(w.contains(at), isTrue, reason: '$at 이 없다 — 서로 다른 말을 하게 된다');
    }
    expect(w.contains("(x['cat'] as String?) ?? '기타'"), isFalse,
        reason: '영어를 그대로 세던 옛 방식이 돌아왔다');
  });

  test('웹앱의 갈래 목록을 «빠짐없이» 안다', () {
    final f = File(_web);
    if (!f.existsSync()) {
      markTestSkipped('웹앱 파일이 없는 기기 — 앱 쪽만 확인했다');
      return;
    }
    final m = RegExp(r'LEDGER_CATS\s*=\s*\[(.*?)\]\];', dotAll: true)
        .firstMatch(f.readAsStringSync());
    expect(m, isNotNull, reason: '웹앱의 갈래 목록 모양이 바뀌었다');
    final keys = RegExp(r"\['(\w+)'").allMatches(m!.group(1)!).map((x) => x.group(1)!);
    expect(keys, isNotEmpty);
    for (final k in keys) {
      expect(Logic.catLabel(k), isNot(k),
          reason: '웹이 「$k」로 적는데 앱은 그대로 영어로 보여 준다');
    }
  });
}
