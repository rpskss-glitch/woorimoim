// 📚 사진을 크게 본 채로 «옆으로 밀어» 다음·이전 사진으로 넘어가기.
//
// 2026-09-23 요청: 대화방에서 사진을 누르면 그 한 장만 떴다. 사진이 여러 장 올라온 날에는
// 한 장 보고 닫고, 위로 올라가 다시 누르기를 되풀이해야 했다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 주석을 걷어낸 코드만 본다 — 내 설명글에 시험이 걸리면 안 된다.
String codeOf(String path) {
  final nl = String.fromCharCode(10);
  return File(path).readAsStringSync().split(nl).map((l) {
    final t = l.trimLeft();
    if (t.startsWith('//') || t.startsWith('/*') || t.startsWith('*')) return '';
    return l.split('//').first;
  }).join(nl);
}

void main() {
  test('사진 여러 장을 넘겨 보는 길이 있다', () {
    final code = codeOf('lib/ui/common.dart');
    expect(code.contains('showPhotoPages'), isTrue);
    expect(code.contains('PageView'), isTrue, reason: '넘기려면 장을 이어 붙여야 한다');
  });

  test('확대한 동안에는 넘기기가 멈춘다', () {
    final code = codeOf('lib/ui/common.dart');
    final at = code.indexOf('PageView.builder');
    expect(at, greaterThan(0));
    final near = code.substring(at, (at + 400).clamp(0, code.length));
    expect(near.contains('NeverScrollableScrollPhysics'), isTrue,
        reason: '확대한 사진을 밀어 보려다 다음 사진으로 넘어가면 확대가 쓸모없다');
  });

  test('한 장만 넘겨도 그대로 뜬다 (옛 부르는 법이 살아 있다)', () {
    final code = codeOf('lib/ui/common.dart');
    final at = code.indexOf('void showPhotoViewer');
    expect(at, greaterThan(0), reason: '쓰던 곳이 여럿이라 이름을 없애면 안 된다');
    expect(code.substring(at, at + 200).contains('showPhotoPages'), isTrue,
        reason: '한 장도 같은 화면으로 보여 손질할 자리가 하나여야 한다');
  });

  test('대화방 사진을 누르면 그 방 사진 전부가 딸려 온다', () {
    final code = codeOf('lib/ui/chat.dart');
    expect(code.contains('_openPhotos'), isTrue);
    expect(code.contains('onPhotoTap'), isTrue, reason: '사진에 눌림을 안 붙이면 예전 그대로다');
    final at = code.indexOf('void _openPhotos');
    expect(at, greaterThan(0));
    final body = code.substring(at, (at + 800).clamp(0, code.length));
    expect(body.contains("'img'"), isTrue, reason: '사진인 말만 모아야 한다');
    expect(body.contains('showPhotoPages'), isTrue);
  });

  test('누른 사진부터 열린다 — 늘 첫 장으로 가면 안 된다', () {
    final code = codeOf('lib/ui/chat.dart');
    final at = code.indexOf('void _openPhotos');
    final body = code.substring(at, (at + 800).clamp(0, code.length));
    expect(body.contains('showPhotoPages(context, shots, at)'), isTrue,
        reason: '누른 자리를 넘겨야 그 사진이 먼저 보인다');
    expect(body.contains('at = shots.length'), isTrue, reason: '누른 자리를 세는 곳이 없다');
  });

  test('사진첩도 같은 확대 위젯을 쓴다 (두 벌로 갈라지지 않게)', () {
    final album = codeOf('lib/ui/album.dart');
    expect(album.contains('ZoomPhoto('), isTrue);
    expect(album.contains('class _ZoomPhoto'), isFalse,
        reason: '사진첩에 따로 두면 한쪽만 고쳐져 동작이 갈라진다');
    expect(codeOf('lib/ui/common.dart').contains('class ZoomPhoto'), isTrue);
  });

  test('확대했을 때만 사진을 민다', () {
    final code = codeOf('lib/ui/common.dart');
    final at = code.indexOf('class _ZoomPhotoState');
    expect(at, greaterThan(0));
    final body = code.substring(at, (at + 1200).clamp(0, code.length));
    expect(body.contains('panEnabled: _on'), isTrue,
        reason: '늘 밀 수 있으면 InteractiveViewer 가 좌우 손짓을 통째로 먹는다');
  });
}
