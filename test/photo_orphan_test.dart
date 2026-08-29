import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 사진 원본은 «보관함(Cloud Storage)»에 올리고 문서에는 번호만 적는다.
   올리기는 됐는데 «문서 적기»가 거절당하면, 그 파일은 아무도 못 보는 채로 남아
   **매달 보관 요금만** 나간다 (아무도 눈치채지 못한다 — 화면 어디에도 안 보이니까).
   그래서 사진을 올리는 자리는 «적기가 실패하면 원본도 치우는» 길이 반드시 있어야 한다.
   게시판·채팅은 그렇게 돼 있었는데 **설정(모임 상징)만 빠져 있었다**(124회차). */

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

/// [at] 을 감싸고 있는 «메서드 한 덩어리» — 2칸 들여쓴 선언과 선언 사이.
String methodAround(String src, int at) {
  final decl = RegExp(r'^  (Future|void|static|[A-Z]\w*|bool|int|String)[ <]',
      multiLine: true);
  var start = 0, end = src.length;
  for (final m in decl.allMatches(src)) {
    if (m.start <= at) {
      start = m.start;
    } else {
      end = m.start;
      break;
    }
  }
  return src.substring(start, end);
}

void main() {
  test('사진을 올리는 곳은 «적기가 실패하면» 원본을 치운다', () {
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      if (rel.endsWith('lib/store.dart')) continue; // 올리는 함수 «자신»이 있는 곳
      final code = stripComments(f.readAsStringSync());
      for (final m in RegExp(r'savePhoto\(').allMatches(code)) {
        final body = methodAround(code, m.start);
        /* ⚠️ 「dropPhotos 가 있나」만 보면 안 된다 — 이 메서드에는 «성공했을 때
           옛 사진을 치우는» dropPhotos 도 있어서, 정작 실패 갈래를 통째로 지워도
           시험이 그냥 통과한다(124회차에 미끼로 확인). 실패 갈래인지까지 본다. */
        final onFail = RegExp(r'dropPhotos\(').allMatches(body).any((d) {
          final from = (d.start - 220).clamp(0, body.length);
          final before = body.substring(from, d.start);
          return before.contains('catch (') || before.contains('== null');
        });
        /* 올리기와 «적기»가 **다른 메서드로 나뉜** 자리도 있다 —
           영수증은 창을 열 때 올려 두고, 저장은 「저장」을 눌러야 한다.
           그때는 이 메서드 안에 실패 갈래가 없는 게 맞다. 대신 그 파일이
           ① 적기가 실패했을 때와 ② **창이 그냥 닫힐 때**(dispose) 둘 다 치워야 한다 —
           올려 두고 뒤로가기로 나가면 그 원본은 아무도 못 보는 파일로 남는다. */
        final splitFlow = code.contains('void dispose()') &&
            RegExp(r'void dispose\(\)[\s\S]{0,400}?dropPhotos\(').hasMatch(code) &&
            RegExp(r'== null[\s\S]{0,400}?dropPhotos\(').hasMatch(code);
        if (!onFail && !splitFlow) missing.add(rel);
      }
    }
    expect(missing, isEmpty,
        reason: '올린 뒤 적기가 거절당하면 그 원본은 «아무도 못 보는 파일»로 남아 '
            '보관 요금만 나간다 — dropPhotos 로 치워야 한다');
  });

  test('치우는 자리는 «거절»에만 있다 — 답이 없을 때는 지우면 안 된다', () {
    /* settleVoid 는 6초가 지나면 조용히 넘긴다(= 기기에 쌓였다가 연결되면 간다).
       그 갈래에서 원본을 지우면 **나중에 저장이 되고 나서 사진만 없는** 상징이 된다.
       그래서 치우기는 catch 안, 곧 «거절받았을 때»에만 있어야 한다. */
    /* ⚠️ 「맨 처음 savePhoto」 하나만 보면 안 된다 — 사진을 올리는 자리는
       모임 상징과 내 아바타 두 곳이고, 앞으로 더 늘 수 있다.
       한 곳만 보면 **나중에 생긴 자리는 아무도 안 지킨다.** «전부» 훑는다. */
    final code = stripComments(File('lib/ui/settings.dart').readAsStringSync());
    final ats = RegExp('savePhoto[(]').allMatches(code).toList();
    expect(ats.length, greaterThan(1), reason: '사진 올리는 자리가 줄었다 — 왜인지 확인해라');
    for (final m in ats) {
      final body = methodAround(code, m.start);
      final catchAt = body.indexOf('} catch (_) {');
      expect(catchAt, greaterThan(0), reason: '거절을 받아 내는 자리가 없다');
      /* 치우는 것이 «방금 올린 번호»여야 한다 — 옛 번호를 지우면 지금 쓰는 사진이 사라진다.
         이름은 자리마다 다르므로(photo·newPhoto) 「catch 뒤에 dropPhotos 가 있는가」로 본다. */
      final drop = body.indexOf('dropPhotos(', catchAt);
      expect(drop, greaterThan(catchAt),
          reason: '거절당했을 때 방금 올린 원본을 치우는 자리가 없다 — '
              'catch 밖에서 지우면 «답이 없을 때»도 지운다');
    }
  });

  test('올리기 자체가 실패했을 때는 적지도 않는다', () {
    // 번호가 null 인데 그대로 적으면 «사진이 없는» 상징이 저장된다
    final code = stripComments(File('lib/ui/settings.dart').readAsStringSync());
    final body = methodAround(code, code.indexOf('savePhoto('));
    expect(body.contains('if (id == null)'), isTrue);
  });
}
