// 앱이 적은 지출을 «아이폰(웹)»이 제대로 세는가 (148회차).
//
// 웹앱의 「어디에 썼나」는 **아는 열쇠 7개만** 센다:
//   LEDGER_CATS.map(([k]) => moList.filter(x => x.kind==='out' && (x.cat||'etc')===k) …)
// 그런데 이 앱은 한글('셔틀콕')을 그대로 적고 있었다 →
// **앱으로 적은 지출이 아이폰 화면의 갈래별 합계에서 통째로 빠졌다.**
// (목록에는 나오는데 합계에는 없다 — 총무가 아이폰이면 실제보다 적게 본다)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

const _web = r'C:\Users\asas3\Desktop\앞산배드민턴\index.html';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

/// 앱이 «적는» 갈래 열쇠들
List<String> appKeys() {
  final w = stripComments(File('lib/ui/wallet.dart').readAsStringSync());
  final m = RegExp(r'_outCats\s*=\s*\[(.*?)\]', dotAll: true).firstMatch(w);
  expect(m, isNotNull, reason: '갈래 목록 모양이 바뀌었다');
  return RegExp(r"'([^']+)'")
      .allMatches(m!.group(1)!)
      .map((x) => x.group(1)!)
      .toList();
}

void main() {
  test('앱이 적는 열쇠가 «웹이 아는 열쇠» 안에 있다', () {
    final f = File(_web);
    if (!f.existsSync()) {
      markTestSkipped('웹앱 파일이 없는 기기');
      return;
    }
    final m = RegExp(r'LEDGER_CATS\s*=\s*\[(.*?)\]\];', dotAll: true)
        .firstMatch(f.readAsStringSync());
    expect(m, isNotNull);
    final webKeys = RegExp(r"\['(\w+)'")
        .allMatches(m!.group(1)!)
        .map((x) => x.group(1)!)
        .toSet();
    for (final k in appKeys()) {
      expect(webKeys, contains(k),
          reason: '앱이 「$k」로 적으면 아이폰의 갈래별 합계에서 빠진다');
    }
  });

  test('적는 것은 열쇠, 보여 주는 것은 한글', () {
    for (final k in appKeys()) {
      expect(RegExp(r'^[a-z]+$').hasMatch(k), isTrue,
          reason: '한글을 적으면 웹이 못 알아본다: $k');
      final label = Logic.catLabel(k);
      expect(label, isNotNull);
      expect(label, isNot(k), reason: '$k 를 한글로 보여 줄 말이 없다');
    }
  });

  test('갈래 고르는 칸이 «한글»을 보여 준다', () {
    final w = stripComments(File('lib/ui/wallet.dart').readAsStringSync());
    expect(w.contains('Logic.catLabel(c) ?? c'), isTrue,
        reason: '회원에게 court·shuttle 이 그대로 보인다');
  });

  test('앱이 적던 «옛 한글»도 그대로 읽힌다', () {
    // 이미 쌓인 기록은 한글이다 — 새 열쇠와 같은 이름으로 묶여야 합계가 안 갈린다
    expect(Logic.catLabel('셔틀콕'), Logic.catLabel('shuttle'));
    expect(Logic.catLabel('체육관'), Logic.catLabel('court'));
    expect(Logic.catLabel('용품'), Logic.catLabel('gear'));
    expect(Logic.catLabel('기타'), Logic.catLabel('etc'));
  });

  test('여섯 갈래가 서로 다른 이름으로 보인다', () {
    final labels = appKeys().map((k) => Logic.catLabel(k)).toList();
    expect(labels.toSet(), hasLength(labels.length),
        reason: '두 갈래가 같은 이름으로 보이면 합계가 뭉뚱그려진다');
  });
}
