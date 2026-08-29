import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🗣 「회원에게 보이는 말이 우리말인가」

   스토어·파이어베이스가 주는 오류는 영어에 기술 용어다:
     PERMISSION_DENIED · [cloud_firestore/unavailable] · SKU not found
   그걸 그대로 보여 주면
     · 회원은 무슨 일인지 모르고 앱을 지운다
     · 애플은 「완성되지 않은 앱」(2.1)으로 되돌려보낸다

   ⚠️ 여기서는 «회원 눈에 닿는 글»만 본다 — 자국(print)이나 주석은 영어여도 된다. */
void main() {
  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// 주석을 걷어낸 코드 (주석의 영어는 봐준다)
  String bare(String s) => s
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//.*'), '');

  test('오류 «덩어리»를 그대로 보여 주지 않는다', () {
    /* `toast(context, '$e')` 는 파이어베이스가 준 영어를 통째로 뱉는다:
         [cloud_firestore/permission-denied] Missing or insufficient permissions.
       회원은 이 글에서 아무것도 못 읽는다. */
    final bad = <String>[];
    for (final f in dartFiles()) {
      final code = bare(f.readAsStringSync());
      for (final m in RegExp(r"toast\([^,]+,\s*'?\$\{?e\}?").allMatches(code)) {
        final line = code.substring(0, m.start).split('\n').length;
        bad.add('${f.path.replaceAll(r'\', '/')}:$line');
      }
      // `.toString()` 을 그대로 보여 주는 꼴도 같다
      for (final m in RegExp(r"toast\([^,]+,\s*\w+\.toString\(\)").allMatches(code)) {
        final line = code.substring(0, m.start).split('\n').length;
        bad.add('${f.path.replaceAll(r'\', '/')}:$line');
      }
    }
    expect(bad, isEmpty,
        reason: '스토어·서버가 준 영어를 그대로 보여 준다 — '
            '회원은 못 읽고, 애플은 2.1 로 되돌려보낸다: $bad');
  });

  test('회원에게 보이는 글에 «기술 용어»가 없다', () {
    /* toast·안내문에 이런 낱말이 들어가면 그건 개발자 말이지 회원 말이 아니다. */
    const jargon = [
      'PERMISSION_DENIED', 'permission-denied', 'unavailable',
      'undefined', 'exception', 'Exception',
      'Firestore', 'Firebase', 'HttpsError', 'SKU',
    ];
    final bad = <String>[];
    for (final f in dartFiles()) {
      final code = bare(f.readAsStringSync());
      for (final m in RegExp(r"toast\([^,]+,\s*'([^']{2,120})'").allMatches(code)) {
        final msg = m.group(1)!;
        /* ⚠️ 「$…」가 든 글은 «코드가 이어 붙이는 것»이라 여기서 못 읽는다 —
           삼항 연산자 조각을 통째로 문자열로 잘못 읽어 헛짚는다(내가 그렇게 짜서 걸렸다). */
        if (msg.contains(r'$')) continue;
        for (final w in jargon) {
          if (msg.contains(w)) {
            final line = code.substring(0, m.start).split('\n').length;
            bad.add('${f.path.replaceAll(r'\', '/')}:$line «$msg»');
          }
        }
      }
    }
    expect(bad, isEmpty, reason: '회원에게 개발자 말을 보여 준다: $bad');
  });

  test('회원에게 보이는 글이 «우리말»이다', () {
    /* 영어 문장이 통째로 들어간 안내가 없어야 한다.
       (「OK」·「GIF」 같은 짧은 낱말은 봐준다) */
    final bad = <String>[];
    for (final f in dartFiles()) {
      final code = bare(f.readAsStringSync());
      for (final m in RegExp(r"toast\([^,]+,\s*'([^']{6,120})'").allMatches(code)) {
        final msg = m.group(1)!;
        final hasHangul = RegExp(r'[가-힣]').hasMatch(msg);
        final hasWords = RegExp(r'[A-Za-z]{4,}\s+[A-Za-z]{3,}').hasMatch(msg);
        if (!hasHangul && hasWords) {
          final line = code.substring(0, m.start).split('\n').length;
          bad.add('${f.path.replaceAll(r'\', '/')}:$line «$msg»');
        }
      }
    }
    expect(bad, isEmpty, reason: '영어 안내가 남아 있다: $bad');
  });

  test('결제 오류는 «우리 말»로 바꿔서 보여 준다', () {
    /* 스토어가 주는 영어 오류를 그대로 보여 주면 애플 지침에 걸린다. */
    final billing = File('lib/billing.dart').readAsStringSync();
    final at = billing.indexOf('PurchaseStatus.error');
    expect(at, greaterThan(0));
    final near = billing.substring(at, (at + 320).clamp(0, billing.length));
    expect(RegExp(r'[가-힣]').hasMatch(near), isTrue);
    expect(near.contains('결제하지 못했어요'), isTrue);
  });

  test('서버 함수도 «우리 말»로 돌려준다', () {
    /* 서버가 던지는 글은 앱이 그대로 회원에게 보여 준다 — 거기부터 우리말이라야 한다. */
    final fn = File('../앞산배드민턴/functions/index.js');
    if (!fn.existsSync()) {
      markTestSkipped('서버 함수 파일을 못 찾았다 — 폴더 밖에 있다');
      return;
    }
    final code = fn.readAsStringSync().replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    final bad = <String>[];
    for (final m in RegExp(r"new HttpsError\([^,]+,\s*'([^']+)'").allMatches(code)) {
      final msg = m.group(1)!;
      if (!RegExp(r'[가-힣]').hasMatch(msg)) bad.add(msg);
    }
    expect(bad, isEmpty, reason: '서버가 영어로 돌려준다 — 회원 화면에 그대로 뜬다: $bad');
  });

  test('「다시 해보라」는 말에 «어떻게»가 들어 있다', () {
    /* 「실패했어요」만 하면 회원은 같은 일을 반복한다.
       적어도 몇 자리는 «무엇을 해보라»가 들어 있어야 한다. */
    var helpful = 0;
    for (final f in dartFiles()) {
      final code = bare(f.readAsStringSync());
      for (final m in RegExp(r"toast\([^,]+,\s*'([^']{6,120})'").allMatches(code)) {
        final msg = m.group(1)!;
        if (RegExp(r'다시|확인|눌러|신호|연결').hasMatch(msg)) helpful++;
      }
    }
    expect(helpful, greaterThan(15),
        reason: '「안 됐어요」만 하고 무엇을 해보라는 말이 거의 없다');
  });
}
