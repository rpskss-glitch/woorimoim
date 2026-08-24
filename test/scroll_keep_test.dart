// 「이전 대화 더 보기」를 눌렀을 때 «읽던 자리»가 남는지 (114회차).
//
// 옛 대화는 목록 «위»에 붙는다. 스크롤 값은 그대로인데 위로 내용이 늘어나므로
// 가만두면 화면이 «가장 오래된 대화»로 튄다 — 읽던 자리를 잃고 한참 내려와야 한다.
// 실측: 50건을 붙이자 맨 위가 «50개 더 옛것»으로 바뀌었다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 지금 화면 맨 위에 보이는 것
String topOf(WidgetTester t) {
  for (final w in t.widgetList<Text>(find.byType(Text))) {
    final r = t.getRect(find.byKey(Key(w.data!)));
    if (r.top >= -1 && r.top < 40) return w.data!;
  }
  return '?';
}

void main() {
  testWidgets('위에 붙인 만큼 내려 주면 읽던 말이 그대로 있다', (t) async {
    var items = List.generate(50, (i) => 'old$i');
    late StateSetter setter;
    final c = ScrollController();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (ctx, s) {
          setter = s;
          return ListView.builder(
            controller: c,
            itemCount: items.length,
            itemBuilder: (_, i) =>
                SizedBox(height: 40, child: Text(items[i], key: Key(items[i]))),
          );
        }),
      ),
    ));
    await t.pump();
    c.jumpTo(0);
    await t.pump();
    expect(topOf(t), 'old0');
    final before = c.position.maxScrollExtent;

    // 옛 대화 50건이 «위»에 붙는다
    setter(() => items = [...List.generate(50, (i) => 'older$i'), ...items]);
    await t.pump();
    expect(topOf(t), 'older0', reason: '가만두면 가장 오래된 대화로 튄다 — 이것이 고치기 전 모습');

    // 늘어난 만큼 내린다 (앱이 하는 일)
    final grew = c.position.maxScrollExtent - before;
    expect(grew, greaterThan(0));
    c.jumpTo((c.position.pixels + grew).clamp(0.0, c.position.maxScrollExtent));
    await t.pump();
    expect(topOf(t), 'old0', reason: '읽던 말이 그 자리에 그대로 있어야 한다');
  });

  testWidgets('붙은 것이 없으면 자리도 안 움직인다', (t) async {
    final c = ScrollController();
    final items = List.generate(50, (i) => 'old$i');
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          controller: c,
          itemCount: items.length,
          itemBuilder: (_, i) =>
              SizedBox(height: 40, child: Text(items[i], key: Key(items[i]))),
        ),
      ),
    ));
    await t.pump();
    c.jumpTo(200);
    await t.pump();
    final before = c.position.maxScrollExtent;
    await t.pump();
    final grew = c.position.maxScrollExtent - before;
    expect(grew, 0);
    expect(c.position.pixels, 200, reason: '안 늘었으면 건드리지 않는다');
  });

  test('채팅이 그 셈을 실제로 한다', () {
    final src = File('lib/ui/chat.dart').readAsStringSync();
    final at = src.indexOf('Future<void> _loadOlder()');
    expect(at, greaterThan(0));
    final body = src.substring(at, src.indexOf('\n  }\n', at));
    expect(body.contains('maxScrollExtent'), isTrue,
        reason: '붙기 전 길이를 안 재면 얼마나 내릴지 알 수 없다');
    expect(body.contains('addPostFrameCallback'), isTrue,
        reason: '새로 붙은 것이 «자리를 잡은 뒤»에 재야 한다');
    expect(body.contains('jumpTo'), isTrue);
    expect(body.contains('clamp(0.0'), isTrue, reason: '끝을 넘어가면 안 된다');
    // 길이를 «부르기 전»에 재야 한다
    expect(body.indexOf('final before ='), lessThan(body.indexOf('loadOlder(code)')));
  });
}
