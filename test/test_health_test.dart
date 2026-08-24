// 「시험을 지키는 시험」.
//
// 이 앱의 시험 중 상당수는 «소스 글월에서 글자를 찾는» 방식이다
// (Firebase 가 없으면 진짜로 못 돌려 보는 자리가 많기 때문).
// 그 방식에는 조용한 함정이 둘 있다:
//   ① 찾는 글자가 **주석에만** 있으면, 동작이 깨져도 시험은 통과한다 (69회차에 실제로 겪었다)
//   ② 값을 **시험 안에 그대로 적어** 두면, 그 값이 바뀌는 어긋남은 못 잡는다 (73회차)
// 여기서는 ①을 기계로 막는다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  test('시험이 찾는 글자가 «주석에만» 있지 않다', () {
    final libs = <String, ({String full, String code})>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final t = f.readAsStringSync();
      libs[f.path] = (full: t, code: stripComments(t));
    }
    expect(libs, isNotEmpty);

    // 시험들이 contains('…') 로 찾는 글자 모으기
    final literals = <String>{};
    for (final f in Directory('test').listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('test_health_test.dart')) continue; // 자기 자신은 뺀다
      final text = f.readAsStringSync();
      /* «있어야 한다»고 하는 것만 모은다.
         «없어야 한다»(isFalse)거나 목록을 훑는 검사는 주석에 걸려도 «시끄럽게» 실패하므로
         스스로 드러난다. 조용히 통과해 버리는 쪽은 «있어야 한다» 뿐이다. */
      for (final m in RegExp(r"contains\('([^']{4,})'\),\s*isTrue").allMatches(text)) {
        literals.add(m.group(1)!);
      }
      for (final m in RegExp(r'contains\("([^"]{4,})"\),\s*isTrue').allMatches(text)) {
        literals.add(m.group(1)!);
      }
    }
    expect(literals.length, greaterThan(15), reason: '모으는 방식이 망가졌다');

    final blind = <String>[];
    for (final lit in literals) {
      final inFull = libs.entries.where((e) => e.value.full.contains(lit)).toList();
      if (inFull.isEmpty) continue; // 소스가 아닌 설정 파일을 찾는 것 — 여기 대상이 아니다
      final inCode = inFull.where((e) => e.value.code.contains(lit)).toList();
      if (inCode.isEmpty) {
        blind.add('"$lit" → ${inFull.map((e) => e.key.split(RegExp(r'[\/]')).last).join(', ')}');
      }
    }
    expect(blind, isEmpty,
        reason: '이 글자들은 «주석에만» 있다 — 동작이 깨져도 시험이 통과한다:\n  ${blind.join('\n  ')}');
  });
}
