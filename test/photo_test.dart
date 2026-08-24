// 사진이 «못 그려질 때» 화면이 어떻게 보이는지 — 빈 칸으로 남으면 안 된다.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/ui/common.dart';

void main() {
  testWidgets('사진을 못 받아오면 빈 칸이 아니라 「깨진 사진」 표시가 나온다', (t) async {
    /* 대신 보여줄 것을 안 주면 Flutter는 그 자리를 그냥 비워 둔다 —
       사진첩에 흰 구멍이 뚫린 것처럼 보이고, 지워진 건지 안 열린 건지 알 수 없다. */
    await t.pumpWidget(MaterialApp(
      home: ClubPhoto.fromSrc('https://example.invalid/a.jpg', width: 40, height: 40),
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('사진 값이 깨져 있어도 앱이 죽지 않는다', (t) async {
    // 백업 복원·옛 기록에서 온 엉터리 값
    await t.pumpWidget(MaterialApp(
      home: ClubPhoto.fromSrc('data:image/jpeg;base64,!!!아무거나!!!', width: 40, height: 40),
    ));
    await t.pump();
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  /* 사진 한 장이 화면 여러 곳(격자·채팅·상징)에 동시에 뜨고, 화면은 남이 글씨만 쳐도 다시 그려진다.
     묶지 않으면 그때마다 저장소에 «새 요청»이 나간다 — 88회차. */
  group('같은 사진을 여러 번 물어보면', () {
    test('도는 동안에는 한 번만 물어본다', () async {
      final waiting = <String, Future<String?>>{};
      var calls = 0;
      final gate = Completer<String?>();
      Future<String?> work() {
        calls++;
        return gate.future;
      }

      final a = Store.once(waiting, 'st:AAA/1', work);
      final b = Store.once(waiting, 'st:AAA/1', work);
      final c = Store.once(waiting, 'st:AAA/1', work);
      expect(calls, 1, reason: '겹친 요청만큼 요금이 곱해진다');
      gate.complete('https://x/1.jpg');
      expect(await Future.wait([a, b, c]), ['https://x/1.jpg', 'https://x/1.jpg', 'https://x/1.jpg']);
    });

    test('다른 사진은 따로 물어본다', () async {
      final waiting = <String, Future<String?>>{};
      var calls = 0;
      Future<String?> work() async {
        calls++;
        return 'x';
      }

      await Store.once(waiting, 'a', work);
      await Store.once(waiting, 'b', work);
      expect(calls, 2);
    });

    test('끝나면 자리를 비워 다음에 다시 물어볼 수 있다', () async {
      final waiting = <String, Future<String?>>{};
      var calls = 0;
      Future<String?> work() async {
        calls++;
        return null;
      }

      await Store.once(waiting, 'a', work);
      expect(waiting, isEmpty, reason: '안 비우면 실패한 요청이 굳어 영영 다시 못 받는다');
      await Store.once(waiting, 'a', work);
      expect(calls, 2);
    });

    test('터져도 자리를 비운다', () async {
      final waiting = <String, Future<String?>>{};
      await expectLater(
          Store.once<String?>(waiting, 'a', () async => throw StateError('끊김')),
          throwsStateError);
      expect(waiting, isEmpty);
    });
  });

  test('사진 위젯이 «다시 그릴 때마다» 새로 물어보지 않는다', () {
    final src = File('lib/ui/common.dart').readAsStringSync();
    final at = src.indexOf('class _ClubPhotoState');
    expect(at, greaterThan(0), reason: 'build 안에서 물어보면 그릴 때마다 요청이 나간다');
    final body = src.substring(at);
    final build = body.indexOf('Widget build(');
    expect(body.substring(build).contains('Store.i.getPhoto('), isFalse,
        reason: 'build 안에서 물어보면 남이 글씨만 쳐도 요청이 새로 나간다');
    expect(body.substring(0, build).contains('_src = Store.i.getPhoto(widget.photoId)'), isTrue);
    // 목록이 다시 쓰이며 다른 사진이 그 자리에 오면 반드시 다시 물어봐야 한다
    expect(body.contains('old.photoId != widget.photoId'), isTrue,
        reason: '안 다시 물으면 «남의 사진»이 그대로 보인다');
  });

  /* 89회차 실측: 대화상자가 화면을 가득 채워, 바깥을 눌러 닫으려면 10px 테두리를 정확히 눌러야 했다.
     아이폰에는 뒤로 단추도 없어 **사진을 열면 빠져나올 길이 사실상 없었다.** */
  group('사진 크게 보기', () {
    Future<void> open(WidgetTester t) async {
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showPhotoViewer(c, 'https://example.invalid/big.jpg'),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('열기'));
      await t.pump();
    }

    testWidgets('«닫기» 단추가 눈에 보이고 실제로 닫힌다', (t) async {
      await open(t);
      expect(find.byIcon(Icons.close), findsOneWidget,
          reason: '아이폰에는 뒤로 단추가 없다 — 안 보이면 빠져나올 길이 없다');
      await t.tap(find.byIcon(Icons.close));
      await t.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
    });

    testWidgets('사진 바깥의 까만 데를 눌러도 닫힌다', (t) async {
      await open(t);
      await t.tapAt(const Offset(20, 560)); // 왼쪽 아래 구석
      await t.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
    });

    /* ⚠️ 「받는 중」은 그려서 못 잰다 — 시험 환경의 그물망은 사진 요청을 «즉시 실패»시켜
       곧바로 깨진 사진으로 넘어간다. 그래서 이 한 가지만 소스로 지킨다. */
    test('받는 동안 보여줄 «기다리는 표시»가 달려 있다', () {
      final src = File('lib/ui/common.dart').readAsStringSync();
      final at = src.indexOf('Image.network(src');
      expect(at, greaterThan(0));
      final body = src.substring(at, at + 700);
      expect(body.contains('loadingBuilder:'), isTrue,
          reason: '없으면 크게 보기가 까만 화면만 보여 앱이 멈춘 줄 안다');
      expect(body.contains('CircularProgressIndicator'), isTrue);
      expect(body.contains('errorBuilder:'), isTrue);
    });

    testWidgets('못 받으면 «깨진 사진» 표시로 바뀐다', (t) async {
      await open(t);
      await t.pump(const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget, reason: '그래도 닫을 수는 있어야 한다');
    });
  });
}
