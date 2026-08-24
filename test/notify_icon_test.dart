// 알림 아이콘 — 안드로이드는 «색을 버리고 모양만» 쓴다(5.0부터).
// 앱 아이콘처럼 바탕이 꽉 찬 그림을 쓰면 알림창에 «흰 사각형»이 뜬다.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// PNG 를 줄마다 RGBA 로 풀어 준다 (그림 파일을 «실제로» 재기 위해)
List<Uint8List> _rgbaRows(File f) {
  final d = f.readAsBytesSync();
  var pos = 8;
  int w = 0, h = 0, ctype = 0, bitd = 0;
  final idat = BytesBuilder();
  while (pos < d.length) {
    final ln = ByteData.sublistView(d, pos, pos + 4).getUint32(0);
    final typ = String.fromCharCodes(d.sublist(pos + 4, pos + 8));
    final data = d.sublist(pos + 8, pos + 8 + ln);
    if (typ == 'IHDR') {
      final b = ByteData.sublistView(Uint8List.fromList(data));
      w = b.getUint32(0);
      h = b.getUint32(4);
      bitd = data[8];
      ctype = data[9];
    } else if (typ == 'IDAT') {
      idat.add(data);
    }
    pos += 12 + ln;
  }
  expect(ctype, 6, reason: 'RGBA 그림이라야 잰다');
  expect(bitd, 8);
  final raw = Uint8List.fromList(ZLibCodec().decode(idat.toBytes()));
  const bpp = 4;
  final stride = w * bpp;
  var prev = Uint8List(stride);
  final rows = <Uint8List>[];
  var i = 0;
  for (var y = 0; y < h; y++) {
    final f0 = raw[i++];
    final line = Uint8List.fromList(raw.sublist(i, i + stride));
    i += stride;
    for (var x = 0; x < stride; x++) {
      final a = x >= bpp ? line[x - bpp] : 0;
      final b = prev[x];
      final c = x >= bpp ? prev[x - bpp] : 0;
      if (f0 == 1) {
        line[x] = (line[x] + a) & 255;
      } else if (f0 == 2) {
        line[x] = (line[x] + b) & 255;
      } else if (f0 == 3) {
        line[x] = (line[x] + (a + b) ~/ 2) & 255;
      } else if (f0 == 4) {
        final p = a + b - c;
        final pa = (p - a).abs(), pb = (p - b).abs(), pc = (p - c).abs();
        final pr = (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
        line[x] = (line[x] + pr) & 255;
      }
    }
    rows.add(line);
    prev = line;
  }
  return rows;
}

/// «알파가 찬 픽셀»의 비율 (0~100)
double opaquePercent(File f) {
  final rows = _rgbaRows(f);
  var opaque = 0, total = 0;
  for (final line in rows) {
    for (var x = 3; x < line.length; x += 4) {
      total++;
      if (line[x] > 200) opaque++;
    }
  }
  return opaque * 100 / total;
}


/// PNG 에서 «꽉 찬 픽셀»의 가장 흔한 색 (#RRGGBB)
String dominantColor(File f) {
  final rows = _rgbaRows(f);
  final count = <int, int>{};
  for (final line in rows) {
    for (var x = 0; x < line.length; x += 4) {
      if (line[x + 3] > 250) {
        final key = (line[x] << 16) | (line[x + 1] << 8) | line[x + 2];
        count[key] = (count[key] ?? 0) + 1;
      }
    }
  }
  final best = count.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return '#${best.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

void main() {
  test('알림 아이콘이 «모양이 남는» 그림이다 (흰 사각형이 아니라)', () {
    for (final dens in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      final f = File('android/app/src/main/res/drawable-$dens/ic_stat_notify.png');
      expect(f.existsSync(), isTrue, reason: '$dens 용 알림 아이콘이 없다');
      final pct = opaquePercent(f);
      expect(pct, lessThan(60),
          reason: '$dens: 찬 부분이 ${pct.toStringAsFixed(0)}% — 알림창에 덩어리로 보인다');
      expect(pct, greaterThan(3), reason: '$dens: 너무 비어 있어 아무것도 안 보인다');
    }
  });

  test('앱 아이콘은 알림용으로 쓰면 «흰 사각형»이 된다 — 그래서 안 쓴다', () {
    final app = File('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png');
    expect(opaquePercent(app), greaterThan(85), reason: '이 사실이 이 시험의 전제다');

    /* ⚠️ 그냥 글자로 찾으면 «주석에 적어 둔 설명»까지 잡힌다 —
       실제로 그렇게 헛걸렸다. 알림 설정에 넘기는 «그 자리»만 본다. */
    final src = File('lib/push.dart').readAsStringSync();
    expect(src.contains("AndroidInitializationSettings('@mipmap"), isFalse,
        reason: '알림에 앱 아이콘을 쓰면 안 된다');
    expect(src.contains("const notifyIcon = '@drawable/ic_stat_notify'"), isTrue);
    expect('AndroidInitializationSettings(notifyIcon)'.allMatches(src).length, 2,
        reason: '앱이 켜졌을 때와 꺼져 있을 때 «둘 다» 같은 아이콘을 써야 한다');

    final man = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(man.contains('default_notification_icon'), isTrue,
        reason: '서버가 보낸 알림을 안드로이드가 스스로 띄울 때도 같은 아이콘을 써야 한다');
  });

  test('적응형 아이콘의 «바탕색»이 앞면 그림과 같다', () {
    /* 런처마다 동그라미·모난동그라미 등 제 모양으로 오려낸다.
       바탕색이 앞면 그림의 색과 다르면 **동그라미 안에 네모가 비쳐** 아이콘이 어설퍼진다.
       (고치기 전: 바탕 #F3F9FF · 앞면 파랑 #5AA9E6) */
    final colors = File('android/app/src/main/res/values/colors.xml').readAsStringSync();
    final m = RegExp(r'name="ic_launcher_background">(#[0-9A-Fa-f]{6})<').firstMatch(colors);
    expect(m, isNotNull, reason: '바탕색을 못 찾았다');
    final bg = m!.group(1)!.toUpperCase();

    // 앞면 그림에서 «가장 많은 색»을 실제로 재서 견준다
    final fg = dominantColor(File('android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png'));
    expect(bg, fg, reason: '바탕 $bg 와 앞면 $fg 이 다르면 동그란 아이콘에 네모가 비친다');
  });

  group('아이폰 쪽 자원 — 맥이 없어 빌드해 볼 수 없으니 값이라도 지킨다', () {
    String plistString(String key) {
      final t = File('ios/Runner/GoogleService-Info.plist').readAsStringSync();
      final i = t.indexOf('<key>$key</key>');
      expect(i, greaterThan(0), reason: '$key 를 못 찾았다');
      final m = RegExp(r'<string>(.*?)</string>').firstMatch(t.substring(i));
      return m!.group(1)!;
    }

    test('Firebase 값 세 곳이 «서로 같다» (플리스트 · Xcode · 앱 코드)', () {
      /* 하나만 어긋나도 아이폰에서 Firebase 가 안 붙는데, 맥이 없으면 빌드로는 못 잡는다.
         안드로이드에서 실제로 이 종류의 어긋남이 있었다(27회차 — 갈래마다 다른 열쇠). */
      final cfg = File('lib/config.dart').readAsStringSync();
      final iosBlock = cfg.substring(cfg.indexOf('_ios = FirebaseOptions'));

      for (final e in {
        'API_KEY': 'apiKey',
        'GOOGLE_APP_ID': 'appId',
        'BUNDLE_ID': 'iosBundleId',
        'PROJECT_ID': 'projectId',
      }.entries) {
        final want = plistString(e.key);
        expect(iosBlock.contains("'$want'"), isTrue,
            reason: '${e.value} 가 플리스트의 ${e.key}($want)와 다르다');
      }

      final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      final bundle = plistString('BUNDLE_ID');
      expect(pbx.contains('PRODUCT_BUNDLE_IDENTIFIER = $bundle;'), isTrue,
          reason: 'Xcode 의 번들ID 가 플리스트와 다르다');
    });

    test('아이폰 아이콘에 투명도가 없다 (있으면 심사에서 거절된다)', () {
      final dir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
      final pngs = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList();
      expect(pngs.length, greaterThanOrEqualTo(20), reason: '필요한 크기가 빠졌다');
      for (final f in pngs) {
        final d = f.readAsBytesSync();
        final ctype = d[25]; // IHDR 의 color type
        expect(ctype == 4 || ctype == 6, isFalse,
            reason: '${f.path.split(RegExp(r'[\/]')).last} 에 투명도가 있다');
      }
    });
  });
}
