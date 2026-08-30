import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:woorimoim/store.dart';

/* 🖼 «작은 그림»(썸네일).

   같은 자료를 보는 웹은 사진을 그릴 때 `<img src="${p.thumb}">` 로 **이 칸만** 쓴다 —
   원본(photoId)으로 되돌아가는 길이 없다. 앱이 이 칸을 안 적으면
   앱에서 올린 사진이 웹에서 **깨진 그림**으로 보인다(사진첩·홈·대화방 전부). */
void main() {
  /// 시험용 사진 — 가로로 긴 것과 세로로 긴 것
  List<int> jpeg(int w, int h) {
    final im = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        im.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
      }
    }
    return img.encodeJpg(im, quality: 85);
  }

  test('작은 그림이 «웹이 읽는 모양»으로 나온다', () async {
    final t = await Store.makeThumb(Uint8List.fromList(jpeg(1600, 1200)));
    expect(t, isNotNull, reason: '작은 그림을 못 만들었다');
    expect(t!, startsWith('data:image/jpeg;base64,'),
        reason: '웹은 이 값을 <img src> 에 그대로 넣는다 — data URL 이라야 한다');
    final bytes = base64Decode(t.split(',')[1]);
    final out = img.decodeImage(bytes)!;
    expect(out.width, Store.thumbMax, reason: '가로가 긴 사진은 «가로»를 맞춘다');
    expect(out.height, lessThan(Store.thumbMax));
  });

  test('세로로 긴 사진은 «세로»를 맞춘다 — 한쪽만 줄이면 여전히 크다', () async {
    final t = await Store.makeThumb(Uint8List.fromList(jpeg(600, 1600)));
    final out = img.decodeImage(base64Decode(t!.split(',')[1]))!;
    expect(out.height, Store.thumbMax);
    expect(out.width, lessThan(Store.thumbMax));
  });

  test('기록에 넣어도 될 만큼 작다', () async {
    final t = await Store.makeThumb(Uint8List.fromList(jpeg(1600, 1600)));
    // 문서 한 건은 1MB 한도. 미리보기 하나가 그 절반을 먹으면 안 된다.
    expect(t!.length, lessThan(80 * 1024),
        reason: '작은 그림이 너무 크다 — 기록마다 읽기 요금이 붙는다 (${t.length}바이트)');
  });

  test('크기·품질이 «웹과 같은 값»이다', () {
    /* 크기를 바이트로만 재면 헐겁다 — 품질을 올려도 한도 안에 들어와 그냥 지나간다
       (실측: q62 22KB · q96 62KB, 둘 다 80KB 아래). 그래서 «웹이 쓰는 값»과 직접 견준다.
       웹: `thumb(img, max=220)` 와 jpeg 되돌림 `draw(img, max, 0.62)`. */
    final mine = File('lib/store.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//.*'), '');
    expect(Store.thumbMax, 220, reason: '웹의 기본 크기(220)와 달라졌다');
    expect(mine, contains('quality: 62'),
        reason: '작은 그림의 품질이 웹(0.62)과 달라졌다 — '
            '올리면 기록마다 읽기 요금이 붙고, 내리면 웹에서 더 흐리게 보인다');

    final web = File('../앞산배드민턴/index.html');
    if (!web.existsSync()) return;
    final t = web.readAsStringSync();
    expect(t, contains('thumb(img, max=${Store.thumbMax})'),
        reason: '웹의 기본 크기가 바뀌었다 — Store.thumbMax 도 맞춰야 한다');
    expect(t, contains('draw(img, max, 0.62)'),
        reason: '웹의 jpeg 품질이 바뀌었다 — 앱의 quality 도 맞춰야 한다');
  });

  test('못 읽는 자료를 줘도 «올리기를 막지 않는다»', () async {
    final t = await Store.makeThumb(Uint8List.fromList([1, 2, 3, 4, 5]));
    expect(t, isNull, reason: '그림이 아니면 조용히 null 이라야 한다 (터지면 사진이 안 올라간다)');
  });

  test('사진을 올리는 «두 곳 모두» 그 칸을 적는다', () {
    for (final f in ['lib/ui/board.dart', 'lib/ui/chat.dart']) {
      final s = File(f)
          .readAsStringSync()
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
          .replaceAll(RegExp(r'//.*'), '');
      expect(s, contains('Store.makeThumb('), reason: '$f 가 작은 그림을 안 만든다');
      expect(s, contains("'thumb': thumb"),
          reason: '$f 가 작은 그림을 기록에 안 넣는다 — 웹에서 깨진 그림으로 보인다');
    }
  });

  test('웹이 아직 «되돌림 없이» 그 칸만 그린다 — 바뀌면 이 시험도 다시 봐야 한다', () {
    final web = File('../앞산배드민턴/index.html');
    if (!web.existsSync()) return;
    final t = web.readAsStringSync();
    expect(t, contains(r'src="${p.thumb}"'),
        reason: '웹의 사진첩이 이 칸을 안 쓴다 — 앱이 넣는 값도 다시 맞춰야 한다');
    expect(t, contains(r'src="${m.thumb}"'),
        reason: '웹의 대화방이 이 칸을 안 쓴다');
  });
}
