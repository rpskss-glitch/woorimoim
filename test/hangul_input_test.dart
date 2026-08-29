import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/common.dart';

/* ⌨️ 한글 입력을 방해하지 않는가.

   한글은 «조합»으로 들어온다 — ㄱ → 가 → 각 → 간. 그 도중에 앱이 끼어들면
   글자가 겹쳐 찍히거나(「가가각」) 마지막 글자가 사라진다.
   중장년 회원이 많은 앱에서 이런 일이 나면 「글이 안 써진다」로 앱을 지운다.

   끼어드는 대표적인 방법 셋 — 여기서 다 막는다:
     ① `inputFormatters` — 조합 중인 글자를 걸러 낸다
     ② `onChanged` 에서 controller.text 를 되돌려 쓴다
     ③ 입력칸을 감싸며 제 나름의 상태·되돌림을 둔다

   ⚠️ 이건 «지금 안 그런다»를 지키는 시험이다 — 새 화면을 만들 때 무심코 넣기 쉽다. */
void main() {
  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String bare(String s) => s
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//.*'), '');

  test('① 입력칸에 «글자 거르개»를 달지 않는다', () {
    /* `inputFormatters` 는 조합 중인 글자에도 걸린다 — ㄱ 을 지우거나 각 을 되돌린다.
       길이 제한은 `maxLength` 로, 숫자만 받는 것은 `keyboardType` 으로 한다. */
    final bad = <String>[];
    for (final f in dartFiles()) {
      if (bare(f.readAsStringSync()).contains('inputFormatters')) {
        bad.add(f.path.replaceAll(r'\', '/'));
      }
    }
    expect(bad, isEmpty,
        reason: '글자 거르개가 한글 조합을 끊는다 — 글자가 겹쳐 찍힌다: $bad');
  });

  test('② 글자를 치는 «도중»에 controller 를 되돌려 쓰지 않는다', () {
    /* 열 때 값을 채우는 것(`initState`)은 괜찮다.
       `onChanged` 안에서 되돌려 쓰면 조합이 깨진다. */
    final bad = <String>[];
    for (final f in dartFiles()) {
      final code = bare(f.readAsStringSync());
      for (final m in RegExp(r'onChanged:\s*\(([^)]*)\)\s*(?:async\s*)?\{?')
          .allMatches(code)) {
        final tail = code.substring(m.end, (m.end + 260).clamp(0, code.length));
        // 다음 onChanged 전까지만 본다
        final nxt = tail.indexOf('onChanged:');
        final body = nxt > 0 ? tail.substring(0, nxt) : tail;
        if (RegExp(r'\w+C?\.text\s*=').hasMatch(body)) {
          bad.add(f.path.replaceAll(r'\', '/'));
        }
      }
    }
    expect(bad, isEmpty,
        reason: '치는 도중에 글자를 되돌려 쓴다 — 한글이 겹쳐 찍힌다: $bad');
  });

  test('③ 길이는 maxLength 로 막는다 (거르개가 아니라)', () {
    // 적어도 한 곳은 maxLength 를 쓰고 있어야 «그 방법을 쓴다»는 뜻이다
    var uses = 0;
    for (final f in dartFiles()) {
      uses += RegExp(r'maxLength:').allMatches(f.readAsStringSync()).length;
    }
    expect(uses, greaterThan(3), reason: '길이를 막는 방법이 안 보인다');
  });

  testWidgets('실제로 한 글자씩 조합해도 그대로 남는다', (t) async {
    /* 조합을 흉내 낸다: ㄱ → 가 → 각. 앱이 안 끼어들면 마지막 값이 그대로 남는다. */
    final c = TextEditingController();
    addTearDown(c.dispose);
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: Scaffold(
        body: TextField(controller: c, maxLength: 30),
      ),
    ));
    for (final s in ['ㄱ', '가', '각', '각오']) {
      await t.enterText(find.byType(TextField), s);
      await t.pump();
      expect(c.text, s, reason: '「$s」를 넣었는데 「${c.text}」가 됐다');
    }
  });

  testWidgets('여러 줄 입력칸도 한글을 그대로 받는다', (t) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: Scaffold(
        body: TextField(controller: c, maxLines: 4, minLines: 1, maxLength: 500),
      ),
    ));
    const long = '오늘 모임 참석합니다 잘 부탁드려요 라켓은 빌려주실 수 있나요';
    await t.enterText(find.byType(TextField), long);
    await t.pump();
    expect(c.text, long);
  });

  test('공용 입력 창(askText)도 거르개를 안 쓴다', () {
    final common = File('lib/ui/common.dart').readAsStringSync();
    final at = common.indexOf('class _AskTextDialogState');
    expect(at, greaterThan(0));
    final body = common.substring(at, (at + 1200).clamp(0, common.length));
    expect(body.contains('inputFormatters'), isFalse);
    expect(body.contains('maxLength'), isTrue, reason: '길이를 안 막으면 화면이 무너진다');
  });

  test('공용 입력 창이 있다 — 창마다 제 나름의 그릇을 두지 않게', () {
    // 창마다 따로 만들면 그중 하나가 조합을 깨뜨려도 못 찾는다
    expect(File('lib/ui/common.dart').readAsStringSync().contains('Future<String?> askText('),
        isTrue);
    expect(askTextExists(), isTrue);
  });
}

/// 공용 입력 창이 실제로 불러지는지 (이름만 있고 안 쓰면 뜻이 없다)
bool askTextExists() {
  for (final f in Directory('lib/ui').listSync().whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    if (f.path.endsWith('common.dart')) continue;
    if (f.readAsStringSync().contains('askText(')) return true;
  }
  return false;
}
