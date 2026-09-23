// 📌 게시판 «맨 위에 고정» — 회칙·계좌번호처럼 늘 위에 있어야 하는 글.
//
// 2026-09-23 요청: 공지로만 올리면 새 공지가 생길 때마다 아래로 밀렸다.
// 고정은 공지와 «따로» 둬서, 고정한 글이 공지보다도 위에 선다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

Map<String, dynamic> post(String id, int at, {bool notice = false, bool pinned = false}) => {
      'id': id,
      'type': 'diary',
      'createdAt': at,
      if (notice) 'notice': true,
      if (pinned) 'pinned': true,
    };

List<String> order(List<Map<String, dynamic>> rows) =>
    ([...rows]..sort(Logic.byNotice)).map((e) => e['id'] as String).toList();

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
  test('고정한 글이 공지보다도 위에 온다', () {
    expect(
      order([
        post('새글', 900),
        post('공지', 500, notice: true),
        post('회칙', 100, pinned: true),
      ]),
      ['회칙', '공지', '새글'],
    );
  });

  test('고정이 여럿이면 그 안에서는 새것이 먼저', () {
    expect(
      order([
        post('고정오래', 100, pinned: true),
        post('보통', 800),
        post('고정최근', 400, pinned: true),
      ]),
      ['고정최근', '고정오래', '보통'],
    );
  });

  test('고정 + 공지를 함께 켠 글도 맨 위에 한 번만 선다', () {
    final rows = [
      post('보통', 900),
      post('회칙공지', 100, notice: true, pinned: true),
      post('공지', 800, notice: true),
    ];
    expect(order(rows), ['회칙공지', '공지', '보통']);
    expect(order(rows).where((e) => e == '회칙공지').length, 1);
  });

  test('pinned 가 참이 아닌 값이면 고정이 아니다', () {
    for (final v in [false, null, 'true', 1, <String, dynamic>{}]) {
      final rows = [
        <String, dynamic>{'id': '의심', 'createdAt': 1, 'pinned': v},
        <String, dynamic>{'id': '보통', 'createdAt': 2},
      ];
      expect(order(rows), ['보통', '의심'], reason: 'pinned=$v');
    }
  });

  test('고정한 글이 없으면 예전 차례 그대로 (공지 → 새 글)', () {
    expect(
      order([post('새글', 300), post('공지', 100, notice: true), post('옛글', 200)]),
      ['공지', '새글', '옛글'],
    );
  });

  test('게시판에서 고정을 켜고 끌 수 있다', () {
    final code = codeOf('lib/ui/board.dart');
    expect(code.contains("'pinned'"), isTrue, reason: '고정 값을 실제로 적어야 한다');
    expect(code.contains('updateItem'), isTrue, reason: '누르기만 하고 저장을 안 하면 헛단추다');
    expect(code.contains('고정'), isTrue, reason: '메뉴에 고정이 보여야 한다');
  });

  test('고정은 운영진만 — 글쓴이 아무나 맨 위를 차지하지 못한다', () {
    final code = codeOf('lib/ui/board.dart');
    final at = code.indexOf("value: 'pin'");
    expect(at, greaterThan(0), reason: '고정 메뉴가 있어야 한다');
    expect(code.substring((at - 200).clamp(0, at), at).contains('st.isAdmin'), isTrue,
        reason: '운영진 확인 없이 고정 메뉴가 뜨면 게시판 맨 위가 뒤죽박죽이 된다');
  });

  test('고정한 글임이 화면에 보인다 (목록·글 안 둘 다)', () {
    for (final f in ['lib/ui/board.dart', 'lib/ui/post_screen.dart']) {
      expect(codeOf(f).contains('📌 고정'), isTrue, reason: '$f 에 표시가 없다');
    }
  });

  test('홈의 최근 게시판도 같은 차례를 쓴다', () {
    final code = codeOf('lib/ui/home.dart');
    final at = code.indexOf("by('diary')");
    expect(at, greaterThan(0));
    expect(code.substring(at, at + 200).contains('Logic.byNotice'), isTrue,
        reason: '홈과 게시판의 맨 위 글이 다르면 회원은 글이 사라진 줄 안다');
  });
}
