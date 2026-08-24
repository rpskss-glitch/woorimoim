// 게시판 차례 — 「📌 공지로 올리기」가 정말로 하는 일이 있는지.
//
// 83회차: 운영진만 켤 수 있는 스위치인데, 목록이 올린 때 하나로만 줄을 서서
// 공지가 **다음 글 하나에 바로 밀렸다.** 글쓴이 이름 옆에 📌 를 그리는 것 말고는 효과가 없었다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

Map<String, dynamic> post(String id, int at, {bool notice = false}) =>
    {'id': id, 'type': 'diary', 'createdAt': at, if (notice) 'notice': true};

List<String> order(List<Map<String, dynamic>> rows) =>
    ([...rows]..sort(Logic.byNotice)).map((e) => e['id'] as String).toList();

void main() {
  test('공지가 언제 올렸든 맨 위로 온다', () {
    expect(
      order([
        post('새글3', 300),
        post('새글2', 200),
        post('공지', 100, notice: true),
        post('새글1', 150),
      ]),
      ['공지', '새글3', '새글2', '새글1'],
    );
  });

  test('공지가 여럿이면 그 안에서도 새것이 먼저', () {
    expect(
      order([
        post('공지오래', 100, notice: true),
        post('보통', 500),
        post('공지최근', 400, notice: true),
      ]),
      ['공지최근', '공지오래', '보통'],
    );
  });

  test('공지가 없으면 그냥 새것이 먼저 (예전과 같다)', () {
    expect(order([post('a', 1), post('c', 3), post('b', 2)]), ['c', 'b', 'a']);
  });

  test('notice 가 참이 아닌 값이면 공지가 아니다', () {
    for (final v in [false, null, 'true', 1, {}]) {
      final rows = [
        {'id': '의심', 'createdAt': 1, 'notice': v},
        {'id': '보통', 'createdAt': 2},
      ];
      expect(order(rows), ['보통', '의심'], reason: 'notice=$v');
    }
  });

  test('올린 때가 글자거나 비어 있어도 죽지 않는다', () {
    final rows = [
      {'id': '글자', 'createdAt': '200'},
      {'id': '없음'},
      {'id': '숫자', 'createdAt': 300},
      {'id': '공지', 'createdAt': '없는값', 'notice': true},
    ];
    expect(order(rows).first, '공지');
    expect(order(rows), ['공지', '숫자', '글자', '없음']);
  });

  test('게시판이 이 차례를 실제로 쓴다', () {
    final src = File('lib/ui/board.dart').readAsStringSync();
    final at = src.indexOf("by('diary')");
    expect(at, greaterThan(0));
    expect(src.substring(at, at + 200).contains('Logic.byNotice'), isTrue,
        reason: '올린 때 하나로만 줄을 세우면 공지가 밀린다');
  });

  test('📌 표시가 «글»에 붙고 사람 이름에는 안 붙는다', () {
    final src = File('lib/ui/board.dart').readAsStringSync();
    expect(src.contains('📌 공지'), isTrue, reason: '무엇이 공지인지 글에 적혀야 한다');
    // ⚠️ 주석에도 📌 가 들어 있다 — 걷어내고 봐야 한다 (69회차: 내 설명에 시험이 걸린 적이 있다)
    final nl = String.fromCharCode(10);
    final code = src.split(nl).map((l) {
      final t = l.trimLeft();
      if (t.startsWith('//') || t.startsWith('/*') || t.startsWith('*')) return '';
      return l.split('//').first;
    }).join(nl);
    final at = code.indexOf('nameOf');
    expect(at, greaterThan(0));
    expect(code.substring((at - 300).clamp(0, at), at).contains('📌'), isFalse,
        reason: '사람이 공지인 것처럼 보인다');
  });
}
