import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

/* 🕸 「저장이 «그 자리에서» 터져도 그물이 받아 낸다」.

   예전에는 이미 만들어진 약속을 넘겨받았다 — `settle(ref.set(item), '저장')`.
   그런데 Firestore 는 값이 잘못돼 있으면 «거절»이 아니라 **그 줄에서 곧바로 터진다.**
   인자가 먼저 계산되므로 그 터짐이 그물 «밖»으로 새어,
     · 그물에 들어오지도 못하고
     · 방금 올린 사진 원본을 치우는 일도 안 하고(**매달 보관료**)
     · `if (!await …)` 같은 결과 확인도 그대로 지나갔다.
   (데이트장부 702회차에 실측된 것 — 이 앱도 같은 모양이었다)
   그래서 «부르는 함수»를 받아 **만드는 것부터** 감싼다. */
void main() {
  group('만들다 터져도', () {
    test('settle 은 «안 됐다»고 돌려준다 — 밖으로 안 샌다', () async {
      final ok = await Store.settle(() => throw StateError('값이 잘못됨'), '저장');
      expect(ok, isFalse,
          reason: '터짐이 그물 밖으로 새면 «저장했다»고 넘어가거나 화면이 통째로 멈춘다');
    });

    test('settleVoid 는 «그 오류를 그대로» 던진다', () async {
      expect(() => Store.settleVoid(() => throw StateError('값이 잘못됨'), '고치기'),
          throwsA(isA<StateError>()),
          reason: '이 자리는 진짜 오류를 던져 주기로 되어 있다 — 부르는 쪽이 사실대로 알려야 한다');
    });

    test('mustSettle 도 «그 오류를 그대로» 던진다', () async {
      expect(() => Store.mustSettle(() => throw StateError('값이 잘못됨'), '기록 지우기'),
          throwsA(isA<StateError>()));
    });
  });

  group('멀쩡할 때는 하던 대로', () {
    test('잘 되면 «됐다»', () async {
      expect(await Store.settle(() async {}, '저장'), isTrue);
    });

    test('거절하면 «안 됐다»', () async {
      expect(await Store.settle(() async => throw StateError('거절'), '저장'), isFalse);
    });

    test('답이 없으면 «맡긴 것»으로 본다 (화면은 진행시킨다)', () async {
      final ok = await Store.settle(
          () => Future<void>.delayed(const Duration(seconds: 30)), '저장');
      expect(ok, isTrue, reason: '오프라인에서 쌓아 두는 것은 «실패»가 아니다');
    }, timeout: const Timeout(Duration(seconds: 20)));
  });

  test('«미리 만들어 둔 약속»을 껍데기로 감싸지 않는다', () {
    /* 함수를 받도록 바꿨으니 «꼴»은 형 검사가 지켜 준다 — 그건 여기서 안 센다.
       형 검사가 «못» 잡는 구멍은 이것이다:

         final p = ref.set(x);          ← 여기서 이미 터진다
         await Store.settle(() => p, '저장');   ← 껍데기만 함수

       모양은 새 꼴인데 만드는 일은 밖에서 끝났다. 그물은 여전히 헛돈다.
       그래서 «알맹이가 이름 하나뿐인» 껍데기를 찾는다. */
    final s = File('lib/store.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//.*'), '');
    final bad = <String>[];
    for (final m in RegExp(
            r'(?<![A-Za-z0-9_])(?:settle|settleVoid|mustSettle)[(]\s*[(][)]\s*=>\s*([^,;]*)')
        .allMatches(s)) {
      final body = m.group(1)!.trim();
      if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(body)) bad.add(body);
    }
    expect(bad, isEmpty,
        reason: '만드는 일이 그물 «밖»에서 이미 끝났다 — 함수 꼴은 껍데기뿐: $bad');
  });
}
