import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🖼 앨범 열기가 실패하면(사진 권한 거절 등) «왜 안 되는지» 말한다. (2026-09-25 조사)
   `ImagePicker` 는 권한을 거절했으면 **던진다**. 가입 화면만 받아 냈고,
   내 정보 사진·모임 꾸미기·영수증·사진첩 올리기·대화 사진 보내기는 받지 않아
   단추를 눌러도 **아무 일도 없었다**(말도 없이). 한 곳(pickOnePhoto/pickManyPhotos)에서 받는다. */
void main() {
  test('ImagePicker 를 직접 부르는 곳은 공용 길과 가입 화면(이미 받아 냄)뿐', () {
    for (final f in Directory('lib/ui').listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final name = f.uri.pathSegments.last;
      if (name == 'common.dart' || name == 'onboarding.dart') continue;
      expect(f.readAsStringSync().contains('ImagePicker()'), isFalse,
          reason: '$name 이 앨범을 직접 연다 — 권한 거절 때 말없이 끝난다');
    }
  });

  test('공용 길은 실패를 받아 까닭을 말한다', () {
    final s = File('lib/ui/common.dart').readAsStringSync();
    final at = s.indexOf('Future<XFile?> pickOnePhoto(');
    expect(at, greaterThanOrEqualTo(0));
    final body = s.substring(at, s.indexOf('\n}\n', at));
    expect(body, contains('catch'));
    expect(s, contains('Future<List<XFile>> pickManyPhotos('));
    expect(s, contains('사진 권한'));
  });
}
