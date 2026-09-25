import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🎨 모임 꾸미기 저장 — 사진 올리기가 실패해도 나머지는 저장하고, 옛 사진은 안 지운다.

   2026-09-25 조사:
   ① 사진을 골랐다가 이모지로 바꿔도 그 사진을 올려 두었다 — 어디에도 안 쓰이는데 보관 요금만.
   ② 사진 올리기가 실패하면 그 자리에서 돌아가, 고른 이모지·크기·회전이 다 버려졌다.
   ⚠️ 고치면서 생길 뻔한 함정: 사진을 못 올려 «옛 사진»을 계속 쓰는데 «옛 것 치우기»가 돌면
      모임 상징이 깨진다(원본이 지워진다). 그래서 «새로 올렸을 때»만 치운다. */
void main() {
  final s = File('lib/ui/settings.dart').readAsStringSync();
  final at = s.indexOf('// 새로 고른 사진은 «보관함에 올리고 번호만» 문서에 적는다');
  final region = s.substring(at, s.indexOf('\n}', at));

  test('사진을 고른 채로 «사진»일 때만 올린다', () {
    expect(region, contains("if (picked != null && kind == 'photo') {"),
        reason: '이모지로 바꿨는데도 사진을 올린다');
  });

  test('사진만 실패하면 돌아가지 않고 계속 저장한다', () {
    final fail = region.substring(region.indexOf('if (id == null) {'), region.indexOf('} else {'));
    expect(fail, contains('photoFailed = true;'));
    expect(fail.contains('return;'), isFalse, reason: '사진 하나 때문에 크기·회전·이모지까지 버린다');
  });

  test('옛 사진은 «새로 올렸을 때»만 치운다 — 실패해서 옛 것을 쓰는 중이면 안 지운다', () {
    expect(region, contains("if (old != null && (uploaded || kind != 'photo')) {"));
    expect(region, contains('if (uploaded && photo != null) Store.i.dropPhotos([photo]);'),
        reason: '저장이 실패했을 때 «방금 올린 것»이 아니라 옛 사진을 지운다');
  });
}
