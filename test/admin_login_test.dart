import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🔑 「총괄 관리자로 들어가는 길」이 앱·웹·서버 셋에서 어긋나지 않는가

   예전에는 이랬다:
     · 비밀번호(123123)가 **앱 안에 글자로** 적혀 있었다 — 설치 파일을 뜯으면 그대로 보였다.
       웹은 더했다. 브라우저에서 코드를 열면 누구나 읽었다.
     · 그래서 「기기 한 대만」이 진짜 방어선이었는데, **그 폰을 잃으면 어느 기기에서도 못 들어갔다.**

   이제는 아이디·이름·생년월일을 **서버 함수**가 확인하고, 맞으면 그 기기를 «허락받은 기기»에 넣는다.
   이 시험은 그 길이 세 곳에서 **같은 이름·같은 규칙**인지만 본다.
   ⚠️ 한 곳만 고치면 조용히 어긋난다 — 앱은 되는데 웹은 못 들어가는 식으로. */
void main() {
  final web = File('../앞산배드민턴/index.html');
  final fns = File('../앞산배드민턴/functions/index.js');
  final rules = File('../데이트장부/firestore.rules');

  String read(File f) => f.readAsStringSync();

  /// 주석은 걷어낸다 — 「예전에 이랬다」는 «설명»은 값이 아니다(내가 그렇게 짜서 헛짚었다)
  String bare(String s) => s
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//.*'), '');

  test('비밀번호가 «앱 안에» 적혀 있지 않다', () {
    /* 앱·웹에 적은 값은 비밀이 아니다. 서버 시크릿에만 있어야 한다. */
    expect(bare(File('lib/config.dart').readAsStringSync()).contains('adminPass'), isFalse,
        reason: '앱에 총괄 비밀번호가 글자로 남아 있다 — 설치 파일을 뜯으면 보인다');

    if (!web.existsSync()) {
      markTestSkipped('웹앱 파일을 못 찾았다 — 폴더 밖에 있다');
      return;
    }
    expect(read(web).contains('adminPass'), isFalse,
        reason: '웹앱에 총괄 비밀번호가 남아 있다 — 브라우저에서 코드를 열면 읽힌다');
  });

  test('앱과 웹이 «같은 이름»의 서버 함수를 부른다', () {
    if (!web.existsSync() || !fns.existsSync()) {
      markTestSkipped('웹앱·서버 함수 파일을 못 찾았다');
      return;
    }
    final app = File('lib/store.dart').readAsStringSync();
    final w = read(web);
    final f = read(fns);

    for (final name in ['adminLoginApsan', 'adminDropDeviceApsan']) {
      expect(app.contains(name), isTrue, reason: '앱이 «$name» 을 안 부른다');
      expect(w.contains(name), isTrue, reason: '웹이 «$name» 을 안 부른다');
      expect(f.contains('exports.$name'), isTrue, reason: '서버에 «$name» 이 없다 — 부르면 없는 함수다');
    }
  });

  test('웹이 함수 꾸러미를 «불러온다»', () {
    if (!web.existsSync()) {
      markTestSkipped('웹앱 파일을 못 찾았다');
      return;
    }
    final w = read(web);
    /* ⚠️ 이걸 빠뜨리면 `httpsCallable is not a function` 으로
       총괄 콘솔에 **아예 못 들어간다** — 로그인 단추가 죽는다. */
    expect(w.contains('firebase-functions.js'), isTrue,
        reason: '웹이 함수 꾸러미를 안 불러온다 — 총괄 로그인이 죽는다');
    expect(RegExp(r'FB\s*=\s*\{[^}]*\.\.\.fn').hasMatch(w), isTrue,
        reason: '불러오고도 FB 에 안 담았다 — FB.httpsCallable 이 없다');
  });

  test('웹이 «있는 것»만 부른다 (Store.app · Store.ready)', () {
    if (!web.existsSync()) {
      markTestSkipped('웹앱 파일을 못 찾았다');
      return;
    }
    final w = read(web);
    /* `ready` 는 «다 됐나»를 담은 값이지 함수가 아니다.
       `Store.ready()` 라고 부르면 그 자리에서 터져 총괄 콘솔이 안 열린다(실제로 그랬다). */
    expect(w.contains('Store.ready()'), isFalse,
        reason: 'Store.ready 는 값인데 함수처럼 부른다 — 총괄 로그인이 터진다');
    // 서버 함수를 부르려면 손잡이(app)를 Store 에 담아 두어야 한다
    expect(RegExp(r'this\.app\s*=\s*app').hasMatch(w), isTrue,
        reason: 'initializeApp 결과를 Store 에 안 담았다 — getFunctions(Store.app) 이 빈손이다');
  });

  test('앱·웹·서버가 «옛 기기(adminUid)»를 함께 인정한다', () {
    /* 예전 방식으로 묶여 있던 기기를 한 곳에서만 인정하면 어긋난다:
         · 콘솔은 열리는데 「빼기」는 서버가 거절 → **죽은 단추**
         · 목록에 안 보이면 잃어버린 폰을 **뺄 길이 없다** */
    if (!web.existsSync() || !fns.existsSync()) {
      markTestSkipped('웹앱·서버 함수 파일을 못 찾았다');
      return;
    }
    expect(File('lib/ui/admin.dart').readAsStringSync().contains("meta?['adminUid']"), isTrue,
        reason: '앱 기기 목록이 옛 기기를 안 보여 준다 — 뺄 길이 없다');
    /* ⚠️ 그냥 «meta.adminUid» 를 찾으면 **«meta.adminUids» 도 걸린다**(앞 토막이 같다).
       그래서 옛 기기를 다 지워도 시험이 통과했다 — 뒤에 s 가 안 붙은 것만 본다. */
    final legacyRef = RegExp(r'meta\.adminUid(?!s)');
    expect(legacyRef.hasMatch(read(web)), isTrue,
        reason: '웹이 옛 기기를 안 본다 — 아직 안 옮긴 기기를 갑자기 내쫓는다');
    /* ⚠️ 파일 아무 데나 «meta.adminUid» 가 있으면 통과 — 로 두면 헐렁하다.
       실제로 미끼(빼기 함수에서만 지우기)가 안 걸렸다. **그 함수 안만** 본다. */
    final all = read(fns);
    final from = all.indexOf('exports.adminDropDeviceApsan');
    expect(from, greaterThan(0), reason: '빼기 함수가 아예 없다');
    final next = all.indexOf('exports.', from + 10);
    final drop = all.substring(from, next > 0 ? next : all.length);
    expect(legacyRef.hasMatch(drop), isTrue,
        reason: '빼기 함수가 옛 기기를 안 본다 — 그 기기의 「빼기」가 죽은 단추가 된다');
  });

  test('웹에서도 «잃어버린 폰»을 뺄 수 있다', () {
    if (!web.existsSync()) {
      markTestSkipped('웹앱 파일을 못 찾았다');
      return;
    }
    /* ⚠️ 웹에 「이 기기 빼기」만 있으면, 폰을 잃었을 때 **브라우저만으로는 그 폰을 못 뺀다.**
       잃어버린 기기가 총괄 관리자로 영영 남는다. 앱처럼 «고른 기기»를 뺄 수 있어야 한다. */
    final w = read(web);
    expect(RegExp(r'async drop\(').hasMatch(w), isTrue,
        reason: '웹에 «고른 기기 빼기»가 없다 — 잃어버린 폰을 브라우저에서 못 뺀다');
    expect(w.contains("SA.drop('"), isTrue,
        reason: '기기마다 빼기 단추를 안 그린다 — 함수만 있고 누를 곳이 없다');
  });

  test('마지막 한 대는 «못 뺀다»', () {
    if (!fns.existsSync()) {
      markTestSkipped('서버 함수 파일을 못 찾았다');
      return;
    }
    // 다 빼 버리면 허락받은 기기가 하나도 없는 상태가 된다 — 서버가 막아야 한다
    final f = read(fns);
    expect(f.contains('마지막 기기는 뺄 수 없어요'), isTrue,
        reason: '기기를 전부 뺄 수 있다 — 되돌리기 어려운 상태를 만든다');
    /* ⚠️ 「마지막」을 셀 때 **옛 기기도 세야 한다.**
       안 세면 옛 기기가 남아 있는데도 새 기기를 못 빼서, 시험 삼아 들어온 기기가
       총괄 관리자로 영영 남는다(실제로 그랬다). */
    expect(RegExp(r'allowed\.length <= 1').hasMatch(f), isTrue,
        reason: '마지막 한 대를 셀 때 옛 기기를 안 센다 — 뺄 수 있는 기기를 못 뺀다');
  });

  test('허락받은 기기 목록은 «서버만» 고칠 수 있다', () {
    if (!rules.existsSync()) {
      markTestSkipped('서버 규칙 파일을 못 찾았다');
      return;
    }
    /* 앱이 직접 adminUids 에 자기를 넣을 수 있으면 **아무나 총괄 관리자가 된다.**
       규칙이 그 칸을 막고 있어야 한다. */
    final r = read(rules);
    expect(r.contains('adminUids'), isTrue, reason: '규칙이 adminUids 를 아예 모른다');
    expect(RegExp(r"adminTry").hasMatch(r), isTrue,
        reason: '틀린 횟수(adminTry)도 앱이 못 고치게 막아야 한다 — 안 그러면 잠금을 지워 버린다');
  });

  test('점이 든 칸은 «set» 이 아니라 «update» 로 고친다', () {
    if (!fns.existsSync()) {
      markTestSkipped('서버 함수 파일을 못 찾았다');
      return;
    }
    /* 🔴 실제로 겪은 일:
         `set({ [`adminTry.${uid}`]: FieldValue.delete() }, {merge:true})`
       는 «adminTry 안의 그 기기»를 지우지 않는다. **점이 든 이름을 글자 그대로**
       받아 「adminTry.<uid>」라는 엉뚱한 칸을 만들 뿐이다.
       그래서 네 번 틀리고 «맞게 들어간» 사람의 틀린 횟수가 안 지워졌고,
       다음에 한 번만 더 틀려도 10분 잠겼다.
       점을 «경로»로 읽는 것은 update() 뿐이다.

       이 시험은 set(...) 안에 점이 든 칸 이름이 있는지만 본다. */
    final code = read(fns).replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    final bad = <String>[];
    for (final m in RegExp(r'\.set\(\{[\s\S]{0,400}?\}, \{ ?merge').allMatches(code)) {
      final block = m.group(0)!;
      for (final k in RegExp(r'\[`([^`]+)`\]').allMatches(block)) {
        if (k.group(1)!.contains('.')) bad.add(k.group(1)!);
      }
    }
    expect(bad, isEmpty,
        reason: 'set() 안에 점이 든 칸 이름이 있다 — 지운다고 써 놓고 «아무것도 안 지운다»: $bad');
  });

  test('맞게 들어가면 «틀린 횟수»를 지운다', () {
    if (!fns.existsSync()) {
      markTestSkipped('서버 함수 파일을 못 찾았다');
      return;
    }
    final all = read(fns);
    final from = all.indexOf('exports.adminLoginApsan');
    final next = all.indexOf('exports.', from + 10);
    final login = all.substring(from, next > 0 ? next : all.length);
    expect(RegExp(r'update\(\{[\s\S]{0,200}?adminTry').hasMatch(login), isTrue,
        reason: '맞게 들어간 뒤에도 틀린 횟수가 남는다 — 다음 한 번에 잠긴다');
  });

  test('틀렸을 때 «어디가» 틀렸는지 알려 주지 않는다', () {
    if (!fns.existsSync()) {
      markTestSkipped('서버 함수 파일을 못 찾았다');
      return;
    }
    /* 「아이디가 틀렸어요」라고 알려 주면 하나씩 맞춰 볼 수 있다.
       셋 중 무엇이 틀렸는지 말하지 않아야 한다. */
    final f = read(fns);
    for (final leak in ['아이디가 틀렸', '이름이 틀렸', '생년월일이 틀렸']) {
      expect(f.contains(leak), isFalse, reason: '어디가 틀렸는지 알려 준다 — 하나씩 맞춰 볼 수 있다: $leak');
    }
    expect(f.contains('맞지 않아요'), isTrue, reason: '틀렸을 때 회원에게 해줄 말이 없다');
  });
}
