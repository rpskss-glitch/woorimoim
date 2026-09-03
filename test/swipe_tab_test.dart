import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/shell.dart';

/* 👉 「옆으로 밀어 화면 넘기기」 — 손가락을 따라 페이지가 «밀려온다».

   2026-09-03: 처음에는 IndexedStack + 수평 끌기였다(화면이 «확» 바뀜).
   사장님이 «폰 홈처럼 부드럽게 이어지게» 원하셔서 PageView 로 바꿨다.
   ⚠️ 그냥 바꾸면 화면 밖 탭이 버려져 읽던 자리·스크롤·셈을 잃는다 →
      «살려 두기»(AutomaticKeepAliveClientMixin)로 감싸 둘 다 얻는다. 그것도 여기서 지킨다. */
void main() {
  final st = AppState.i;

  int tabOf(WidgetTester t) =>
      t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start();
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: ShellScreen(onTouch: () {}),
    ));
    await t.pumpAndSettle();
  }

  tearDown(() {
    st.setCouple({});
    st.setItems([]);
  });

  Future<void> fling(WidgetTester t, {required bool left}) async {
    // 손으로 미는 정도의 속도 — 너무 세게 던지면 두 칸이 넘어간다(폰 홈도 그렇다)
    await t.fling(find.byType(PageView), Offset(left ? -300 : 300, 0), 500);
    await t.pumpAndSettle();
  }

  testWidgets('왼쪽으로 밀면 다음 탭, 오른쪽으로 밀면 이전 탭', (t) async {
    await open(t);
    expect(tabOf(t), 0);

    await fling(t, left: true);
    expect(tabOf(t), 1, reason: '채팅으로 안 넘어간다');

    await fling(t, left: true);
    expect(tabOf(t), 2, reason: '일정으로 안 넘어간다');

    await fling(t, left: false);
    expect(tabOf(t), 1, reason: '뒤로 안 간다');
  });

  testWidgets('맨 끝에서 더 밀어도 머문다', (t) async {
    await open(t);
    await fling(t, left: false);
    expect(tabOf(t), 0);

    for (var i = 0; i < 4; i++) {
      await fling(t, left: true);
    }
    expect(tabOf(t), 4, reason: '맨 끝(회비)까지 가야 한다');
    await fling(t, left: true);
    expect(tabOf(t), 4, reason: '맨 끝에서 더 밀었는데 넘어갔다');
  });

  testWidgets('아래 단추로 옮겨도 화면이 따라온다', (t) async {
    await open(t);
    await t.tap(find.text('회비'));
    await t.pumpAndSettle();
    expect(tabOf(t), 4, reason: '단추를 눌렀는데 탭이 안 바뀐다');
    // 페이지도 같이 옮겨졌는지 — 다시 오른쪽으로 밀면 «게시판»(3)이라야 한다
    await fling(t, left: false);
    expect(tabOf(t), 3, reason: '단추로 옮겼을 때 페이지가 안 따라왔다');
  });

  testWidgets('🧷 넘겨도 탭이 «살아 있다» — 읽던 자리를 안 잃는다', (t) async {
    await open(t);
    /* PageView 로 바꾸면서 가장 위험해진 자리다. 살려 두기가 빠지면
       옆으로 넘길 때마다 화면 밖 탭이 버려져 스크롤·셈이 처음으로 돌아간다. */
    expect(find.byType(PageView), findsOneWidget);
    // 끝까지 갔다가 돌아와도 «같은 것»이 살아 있어야 한다
    for (var i = 0; i < 4; i++) {
      await fling(t, left: true);
    }
    for (var i = 0; i < 4; i++) {
      await fling(t, left: false);
    }
    expect(tabOf(t), 0);
    expect(t.takeException(), isNull);
  });
}
