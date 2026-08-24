// 화면을 «실제로 그려 보는» 시험.
// 지금까지 시험은 「안 터진다」만 봤는데, 안 터지면서도 **아무것도 안 보이는** 경우가 있다.
// (실제로 2026-08-22에 아바타·상징이 투명해진 것을 여기서 잡았다)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/ui/common.dart';

/// 화면에 실제로 보이는 «빈 글자가 아닌» 글자들
List<String> shownTexts(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data ?? '')
    .where((s) => s.isNotEmpty)
    .toList();

void main() {
  testWidgets('망가진 이모지여도 «기본 얼굴»이 보인다 (투명하지 않게)', (t) async {
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'u1': {'uid': 'u1', 'name': '홍길동', 'emoji': ['깨짐']},
        'u2': {'uid': 'u2', 'name': '김철수', 'emoji': '😎'},
      },
      'emblem': {'kind': 'emoji', 'emoji': ['깨짐'], 'size': 1.0, 'rot': 0.0},
    });
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: Column(children: [Emblem(), Avatar('u1'), Avatar('u2')])),
    ));
    final texts = shownTexts(t);
    expect(texts.length, 3, reason: '하나라도 «빈 글자»면 그 자리가 투명하게 보인다: $texts');
    expect(texts.where((s) => s == '🏸').length, 2, reason: '상징과 아바타가 기본 얼굴로 채워져야 한다');
    expect(texts.contains('😎'), isTrue, reason: '멀쩡한 것은 그대로');
  });

  testWidgets('망가진 이름이어도 부를 이름이 남는다', (t) async {
    AppState.i.couple = Store.tidyCouple({
      'members': {'u1': {'uid': 'u1', 'name': ['깨짐'], 'emoji': '🏸'}},
    });
    expect(AppState.i.nameOf('u1'), '회원', reason: '빈 글자면 채팅·순위에 이름이 안 보인다');
  });

  testWidgets('자리 이름으로 회원 번호를 메운다 (목록에서 사라지지 않게)', (t) async {
    AppState.i.couple = Store.tidyCouple({
      'members': {'u1': {'uid': ['깨짐'], 'name': '홍길동', 'emoji': '🏸'}},
    });
    expect(AppState.i.memberList.length, 1, reason: '번호가 망가졌다고 회원이 사라지면 안 된다');
    expect(AppState.i.memberList.first['uid'], 'u1');
  });

  testWidgets('상징 크기가 터무니없어도 화면이 안 깨진다', (t) async {
    AppState.i.couple = Store.tidyCouple({
      'members': <String, dynamic>{},
      'emblem': {'kind': 'emoji', 'emoji': '🏸', 'size': 9999, 'rot': 9999},
    });
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Emblem(basePx: 54, capScale: 2))));
    expect(t.takeException(), isNull, reason: '화면을 그리다 오류가 나면 안 된다');
    expect(find.text('🏸'), findsOneWidget);
  });
}

