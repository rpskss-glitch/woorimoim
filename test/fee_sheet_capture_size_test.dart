import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:woorimoim/fee_sheet.dart';

/* 🖼 회비표를 대화방에 올릴 때 — 그림이 «너무 크면» 못 올라간다. (2026-09-25 조사)
   · 기간은 직접 고르면 120개월까지 되는데 그림은 늘 3배로 그렸다.
     24개월 지출표만 해도 가로 4,900px, 120개월이면 17,000px — 폰 그래픽이 그릴 수 있는 크기를 넘는다.
   · 보관함 규칙이 한 장 2MB까지라 큰 PNG 는 거절되고, 문서 길(1MB)로도 못 가
     「그림을 올리지 못했어요 — 연결을 확인해주세요」라는 엉뚱한 말만 나왔다. */
void main() {
  test('작은 표는 예전처럼 3배로 또렷하게', () {
    expect(FeeSheet.captureRatio(400, 300), 3);
  });

  test('큰 표는 배율을 낮춰 한 변 4096px·1,200만 화소 안에 든다', () {
    for (final s in [
      [1320.0, 1486.0], // 24개월 · 40명
      [1640.0, 400.0], // 24개월 지출표
      [2856.0, 2100.0], // 60개월 · 60명
    ]) {
      final r = FeeSheet.captureRatio(s[0], s[1])!;
      expect(s[0] * r, lessThanOrEqualTo(4096));
      expect(s[1] * r, lessThanOrEqualTo(4096));
      expect(s[0] * r * s[1] * r, lessThanOrEqualTo(12e6));
      expect(r, greaterThanOrEqualTo(1), reason: '글자가 뭉개질 만큼 줄이면 안 된다');
    }
  });

  test('글자를 못 읽을 만큼 줄여야 하면 «못 그린다»(기간을 나눠 달라고 말한다)', () {
    expect(FeeSheet.captureRatio(5712, 400), isNull, reason: '120개월');
  });

  test('2MB 를 넘는 그림은 JPG 로 줄여 한도 안에 넣는다', () {
    // 잡음 그림은 PNG 로 줄지 않는다 — 가장 나쁜 경우
    final src = img.Image(width: 1200, height: 1200);
    var seed = 7;
    for (final p in src) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      p.setRgb(seed & 255, (seed >> 8) & 255, (seed >> 16) & 255);
    }
    final png = Uint8List.fromList(img.encodePng(src));
    expect(png.length, greaterThan(FeeSheet.uploadLimit));
    final out = FeeSheet.fitUpload(png)!;
    expect(out.length, lessThanOrEqualTo(FeeSheet.uploadLimit));
    expect(img.decodeImage(out), isNotNull);
  });

  test('한도 안이면 그대로(다시 누르지 않는다)', () {
    final png = Uint8List.fromList(img.encodePng(img.Image(width: 50, height: 50)));
    expect(identical(FeeSheet.fitUpload(png), png), isTrue);
  });

  test('화면은 배율·크기 맞추기를 쓰고, «너무 길다»를 따로 말한다', () {
    final s = File('lib/ui/fee_sheet_screen.dart').readAsStringSync();
    expect(s, contains('FeeSheet.captureRatio('));
    expect(s, contains('FeeSheet.fitUpload'));
    expect(s.contains('toImage(pixelRatio: 3)'), isFalse, reason: '늘 3배면 큰 표가 터진다');
    expect(s, contains('기간이 너무 길어요'));
  });
  /* 2026-09-25 에뮬에서 잡음: 2016-09 ~ 2026-09 를 고르면(121개월) 120개월로 자르면서
     «끝»을 잘라 이번 달(9월)이 표에서 빠졌다 — 칩은 「~2026-09」인데 표 끝은 8월. */
  test('120개월을 넘기면 «옛 달»을 버리고 이번 달까지는 남긴다', () {
    final r = FeeSheet.monthRange('2016-09', '2026-09');
    expect(r.length, 120);
    expect(r.last, '2026-09', reason: '가장 최근 달이 빠진다');
    expect(r.first, '2016-10');
  });

  test('기간을 잘랐으면 화면에 «줄였다»고 말하고 칩도 실제 기간을 쓴다', () {
    final s = File('lib/ui/fee_sheet_screen.dart').readAsStringSync();
    expect(s, contains('최근 120개월만'));
  });
}
