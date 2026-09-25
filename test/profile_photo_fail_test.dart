import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 📷 내 정보 고치기 — 사진만 못 올렸으면 «나머지는» 저장한다.

   2026-09-25 조사: 사진 올리기가 실패하면 그 자리에서 돌아가, 함께 고친 이름·생년월일·이모지가
   통째로 버려졌다(창은 이미 닫혀 다시 다 적어야 했다).
   ⚠️ 고치면서 생길 뻔한 함정도 막는다: 사진을 못 올려 «예전 사진»을 그대로 쓰는데
      저장까지 실패하면, «방금 올린 사진 치우기»가 **예전 사진을 지워** 버린다. */
String bodyOf(String src, String head) {
  final at = src.indexOf(head);
  expect(at, greaterThanOrEqualTo(0), reason: '$head 을 못 찾았다');
  var depth = 0;
  for (var i = src.indexOf('{', at + head.length); i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}' && --depth == 0) return src.substring(at, i + 1);
  }
  return src.substring(at);
}

void main() {
  final s = File('lib/ui/settings.dart').readAsStringSync();
  final at = s.indexOf('final id = await Store.i.savePhoto(code, picked!);');
  final region = s.substring(at, s.indexOf('Future<void> _editTitle()', at));

  test('사진을 못 올리면 예전 사진으로 두고 계속 간다(돌아가지 않는다)', () {
    final fail = bodyOf(region, 'if (id == null)');
    expect(fail, contains('photoFailed = true;'));
    expect(fail, contains('photo = oldPhoto;'));
    expect(fail.contains("toast(context, '사진을 올리지 못했어요 — 다시 눌러주세요');\n        return;"), isFalse,
        reason: '사진 하나 때문에 이름·생년월일까지 버린다');
  });

  test('사진 없이 남으면 «같은 이름·같은 아바타»를 다시 본다', () {
    final fail = bodyOf(region, 'if (id == null)');
    expect(fail, contains('Logic.avatarClash('));
  });

  test('저장이 실패해도 «예전 사진»은 안 지운다', () {
    expect(region, contains('if (picked != null && !photoFailed && newPhoto != null) Store.i.dropPhotos([newPhoto]);'),
        reason: '사진을 못 올려 예전 사진을 쓰는 중인데 그걸 «방금 올린 것»으로 보고 지운다');
  });

  test('무엇이 저장됐고 무엇이 안 됐는지 말해 준다', () {
    expect(region, contains('이름·생년월일은 저장했어요 — 사진은 올리지 못했어요'));
  });
}
