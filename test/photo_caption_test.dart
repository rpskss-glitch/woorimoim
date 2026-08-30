import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/board.dart';

/* 📝 「웹에서 적은 사진 설명」이 앱에서도 보이는가

   같은 모임을 웹과 앱이 함께 본다. 웹 사진첩은 사진마다 «설명»을 붙이는데
   (`caption` — 40자, 태그도 여기 적는다), 앱은 그 칸을 아예 안 그렸다.
   그러면 웹으로 정리한 회원과 앱만 쓰는 회원이 **서로 다른 사진첩**을 보게 된다:
     · 웹: 「3월 정기 대회 8강! 🏆」
     · 앱: 그냥 사진 한 장

   ⚠️ 다듬기(`Store.tidy`)도 이 칸을 알아야 한다. 모르면 그냥 지나쳐,
      손으로 고친 백업의 아주 긴 설명이 격자 한 칸을 화면 밖으로 밀어낸다. */
void main() {
  final st = AppState.i;

  Widget host(Widget child) =>
      MaterialApp(theme: buildTheme('sky'), home: Scaffold(body: child));

  void seed(List<Map<String, dynamic>> items) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'title': '앞산 배드민턴',
      'free': true,
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': 'owner'},
      },
    });
    // 실제 앱이 지나는 길과 똑같이 다듬기를 거친다
    st.setItems(Store.tidy(items));
  }

  Map<String, dynamic> photo(String id, String? caption) => {
        'id': id, 'type': 'photo', 'by': 'me',
        'photoId': 'p_$id', 'date': '2026-08-20',
        if (caption != null) 'caption': caption,
      };

  testWidgets('웹에서 적은 사진 설명이 «격자 칸»에 보인다', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    seed([photo('a', '3월 정기 대회 8강')]);
    await t.pumpWidget(host(const BoardTab()));
    await t.pumpAndSettle();

    // 사진첩 쪽으로 옮긴다
    await t.tap(find.text('사진'));
    await t.pumpAndSettle();

    expect(find.text('3월 정기 대회 8강'), findsOneWidget,
        reason: '웹에서 적은 설명이 앱에는 안 보인다 — 앱 회원만 그 글을 못 읽는다');
    expect(t.takeException(), isNull);
  });

  testWidgets('설명이 없으면 «빈 띠»가 사진을 가리지 않는다', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    seed([photo('b', null), photo('c', '  ')]);
    await t.pumpWidget(host(const BoardTab()));
    await t.pumpAndSettle();
    await t.tap(find.text('사진'));
    await t.pumpAndSettle();

    /* 공백만 적힌 설명도 «없는 것»이다 — 그것까지 띠를 깔면
       사진 아래가 까맣게 가려진 채 아무 글도 없는 꼴이 된다. */
    expect(find.byType(Text).evaluate().where((e) {
      final w = e.widget as Text;
      return (w.data ?? '').trim().isEmpty && (w.data ?? '') != '';
    }), isEmpty, reason: '빈 설명에도 띠를 깔았다');
    expect(t.takeException(), isNull);
  });

  test('다듬기가 «설명»을 한 줄로 자른다', () {
    /* 웹 입력칸은 40자지만, 손으로 고친 백업은 무엇이든 담을 수 있다.
       안 자르면 격자 한 칸이 화면 밖으로 나간다 (직책 2000자로 실제로 겪은 일). */
    final out = Store.tidy([photo('d', 'ㄱ' * 5000)]);
    final cap = out.first['caption'] as String;
    expect(cap.length, lessThanOrEqualTo(Store.oneLineMax + 1),
        reason: '설명을 안 잘라 사진 격자가 화면 밖으로 나간다 (${cap.length}자)');
  });

  test('웹과 «같은 칸 이름»을 쓴다', () {
    /* 이름이 다르면 서로 못 읽는다 — 웹이 적은 것을 앱이 못 보고, 그 반대도 마찬가지다. */
    final web = File('../앞산배드민턴/index.html');
    if (!web.existsSync()) {
      markTestSkipped('웹앱 파일을 못 찾았다');
      return;
    }
    expect(web.readAsStringSync().contains('caption'), isTrue,
        reason: '웹이 쓰는 칸 이름이 바뀌었다 — 앱과 어긋난다');
    expect(File('lib/store.dart').readAsStringSync().contains("'caption'"), isTrue,
        reason: '앱 다듬기가 설명 칸을 모른다');
  });
}
