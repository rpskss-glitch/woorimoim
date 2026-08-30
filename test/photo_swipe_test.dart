import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/album.dart';

/* 📸 「사진을 열고 옆으로 밀면 다음 사진으로 넘어가는가」

   🔴 실제로 겪은 일 —
     사진을 크게 볼 때 `InteractiveViewer` 로 감싸 두면 **좌우로 미는 손짓을 통째로 먹는다.**
     그래서 사진첩에서 다음 사진으로 넘길 수가 없었다. 화면에는 「1 / 3」이 그대로 있고
     회원은 「이 앱은 사진을 하나씩만 볼 수 있나」로 읽는다.
     (웹 사진첩은 밀어서 넘길 수 있다 — 같은 모임인데 앱만 안 됐다)

   ⚠️ 그렇다고 확대를 끄면 안 된다. 단체 사진에서 얼굴을 확인하려면 확대가 필요하다.
      **확대하지 않은 동안에만** 넘기고, 확대했으면 그 사진 안에서 민다. */
void main() {
  final st = AppState.i;

  Widget host(Widget child) =>
      MaterialApp(theme: buildTheme('sky'), home: child);

  List<Map<String, dynamic>> photos() => Store.tidy([
        for (var i = 1; i <= 3; i++)
          {
            'id': 'p$i', 'type': 'photo', 'by': 'me',
            'photoId': 'pid$i', 'date': '2026-08-2$i',
            'caption': '사진 $i',
            'createdAt': 1756400000000 + i,
          },
      ]);

  setUp(() {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'title': '앞산 배드민턴',
      'free': true,
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': 'owner'},
      },
    });
    st.setItems(photos());
  });

  testWidgets('사진을 옆으로 밀면 다음 사진으로 넘어간다', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    final rows = photos();
    await t.pumpWidget(host(PhotoPage(rows: rows, start: 0)));
    await t.pumpAndSettle();

    expect(find.text('1 / 3'), findsOneWidget, reason: '첫 사진이 아니다');

    // 사진 한가운데를 왼쪽으로 민다 — 회원이 하는 그대로
    await t.drag(find.byType(PageView), const Offset(-400, 0));
    await t.pumpAndSettle();

    expect(find.text('2 / 3'), findsOneWidget,
        reason: '밀어도 안 넘어간다 — 확대 위젯이 손짓을 먹고 있다');

    // 되돌아오기도 돼야 한다
    await t.drag(find.byType(PageView), const Offset(400, 0));
    await t.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget, reason: '뒤로는 안 넘어간다');
    expect(t.takeException(), isNull);
  });

  testWidgets('사진 설명이 «넘길 때마다» 그 사진 것으로 바뀐다', (t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    final rows = photos();
    await t.pumpWidget(host(PhotoPage(rows: rows, start: 0)));
    await t.pumpAndSettle();

    /* ⚠️ 아래 설명·반응은 «지금 쪽»을 보고 그린다. 안 따라가면
       두 번째 사진을 보면서 첫 사진 설명을 읽게 된다. */
    final first = rows.first['caption'] as String;
    expect(find.text(first), findsOneWidget);

    await t.drag(find.byType(PageView), const Offset(-400, 0));
    await t.pumpAndSettle();

    expect(find.text(first), findsNothing, reason: '설명이 앞 사진 것에 머물러 있다');
    expect(find.text(rows[1]['caption'] as String), findsOneWidget);
  });

  testWidgets('확대할 수 있는 채로 남아 있다', (t) async {
    /* 넘기기를 살리려고 확대를 통째로 없애면 안 된다 —
       단체 사진에서 얼굴을 확인하려면 확대가 필요하다. */
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(host(PhotoPage(rows: photos(), start: 0)));
    await t.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsWidgets,
        reason: '확대가 사라졌다 — 단체 사진에서 얼굴을 못 본다');

    /* ⚠️ 위의 «밀어서 넘기기» 시험만으로는 재발을 못 잡는다 —
       시험 화면에서는 확대 위젯이 손짓을 안 먹어서, 늘 밀 수 있게 되돌려도 통과했다
       (미끼로 확인). 진짜 폰에서만 막혔다. 그래서 «막는 그 값»을 직접 못 박는다:
         확대하지 않은 동안 panEnabled 가 참이면 폰에서 넘기기가 죽는다. */
    for (final v in t.widgetList<InteractiveViewer>(find.byType(InteractiveViewer))) {
      expect(v.panEnabled, isFalse,
          reason: '확대하지 않았는데 밀기가 켜져 있다 — 진짜 폰에서 사진을 못 넘긴다');
    }
  });
}
