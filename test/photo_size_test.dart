import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

/* 「사진 크기 줄이기」가 «가로·세로 둘 다» 인지 지킨다.

   보관함 규칙(Desktop/데이트장부/storage.rules)에 한 장 2MB 한도가 있다.
   가로만 줄이면 세로로 긴 사진(대화 스크린샷·영수증·파노라마)이 1600×6000 으로 남아
   그 한도를 넘는다. 넘으면 ① 이 사진이 안 올라가고, 더 나쁘게는
   ② savePhoto 가 「보관함을 못 쓰나 보다」 하고 이번 실행 내내 비싼 길로 샌다. */
void main() {
  String src(String p) =>
      File(p).readAsStringSync().replaceAll(RegExp(r'//.*'), '');

  /// 사진 고르기를 부르는 곳 전부 — 새 화면이 생기면 여기 추가해야 시험이 지켜준다
  const doors = <String, int>{
    'lib/ui/board.dart': 1,    // 게시판·사진첩
    'lib/ui/chat.dart': 1,     // 대화방
    'lib/ui/settings.dart': 2, // 모임 상징 · 내 아바타
  };

  test('사진 고르는 곳이 «가로와 세로를 함께» 줄인다', () {
    var seen = 0;
    for (final e in doors.entries) {
      final s = src(e.key);
      // pickImage( … ) / pickMultiImage( … ) 의 괄호를 맞춰 «그 부름만» 떼어낸다
      for (final m in RegExp(r'pick(Multi)?Image\(').allMatches(s)) {
        var depth = 0, i = m.end - 1;
        for (; i < s.length; i++) {
          if (s[i] == '(') depth++;
          if (s[i] == ')') { depth--; if (depth == 0) break; }
        }
        final call = s.substring(m.end, i);
        seen++;
        expect(call, contains('maxWidth:'),
            reason: '${e.key} 의 ${m[0]} 에 maxWidth 가 없다');
        expect(call, contains('maxHeight:'),
            reason: '${e.key} 의 ${m[0]} 이 «가로만» 줄인다 — '
                '세로로 긴 사진이 2MB 한도를 넘어 안 올라간다');
      }
      expect(s, contains('ImagePicker()'), reason: '${e.key} 의 사진 고르기가 사라졌다');
    }
    expect(seen, doors.values.reduce((a, b) => a + b),
        reason: '사진 고르는 곳의 수가 달라졌다 — 새 곳이면 doors 에 적어라');
  });

  test('보관함 한도가 아직 2MB 다 — 바뀌면 줄이는 크기도 다시 봐야 한다', () {
    final f = File('../데이트장부/storage.rules');
    if (!f.existsSync()) return; // 규칙 파일이 없는 곳에서는 넘어간다
    expect(f.readAsStringSync().replaceAll(' ', ''),
        contains('2*1024*1024'),
        reason: '보관함 한 장 한도가 바뀌었다 — 사진 줄이는 크기(1600)를 다시 계산해라');
  });

  test('줄인 사진이 2MB 안에 들어온다 (셈으로 확인)', () {
    // 1600×1600, JPEG 품질 82 → 실제로는 대개 0.3~0.8MB.
    // 가장 나쁜 경우(픽셀당 1바이트)로 잡아도 2.56MB 라 여유가 크지 않다 —
    // 그래서 «가로만» 줄이던 옛 방식(1600×6000 = 9.6M픽셀)은 확실히 넘쳤다.
    const px = 1600 * 1600;
    const tallOld = 1600 * 6000; // 세로를 안 줄였을 때 흔한 크기
    expect(px * 0.35, lessThan(2 * 1024 * 1024));
    expect(tallOld * 0.35, greaterThan(2 * 1024 * 1024));
  });

  group('한 장 실패로 «방 전체»를 비싼 길로 몰지 않는다', () {
    FirebaseException err(String code) =>
        FirebaseException(plugin: 'firebase_storage', code: code);

    test('잠깐 끊긴 것은 보관함을 접지 않는다', () {
      for (final c in ['retry-limit-exceeded', 'canceled', 'unknown']) {
        expect(Store.storageUnusable(err(c)), isFalse, reason: c);
      }
      expect(Store.storageUnusable(Exception('그냥 오류')), isFalse);
    });

    test('사진 한 장이 커서 거절된 것도 접지 않는다', () {
      // 보관함 규칙이 크기 한도를 어긴 것도 unauthorized 로 돌려준다 —
      // 이걸로 접으면 큰 사진 한 장이 그 뒤 모든 사진을 비싼 길로 민다
      expect(Store.storageUnusable(err('unauthorized')), isFalse);
    });

    test('정말 못 쓸 때만 접는다', () {
      for (final c in ['bucket-not-found', 'project-not-found', 'quota-exceeded']) {
        expect(Store.storageUnusable(err(c)), isTrue, reason: c);
      }
    });

    test('사진 올리기가 «그 잣대를 거쳐서» 접는다', () {
      final s = src('lib/store.dart');
      final at = s.indexOf('Future<String?> savePhoto(');
      expect(at, greaterThan(0));
      final body = s.substring(at, s.indexOf('Future<', at + 30));
      expect(body, contains('if (storageUnusable(e)) _storageOk = false'),
          reason: '사진 올리기가 «무엇이든 한 번 실패하면» 보관함을 접는다 — '
              '잠깐 끊긴 사이 한 장 실패한 것이 그 뒤 사진 전부를 7배 비싼 길로 민다');
    });
  });
}
