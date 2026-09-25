import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/album.dart';

/* 📸 사진첩(홈의 «최근 사진»도 이 화면을 연다)에서 크게 본 채로 «진짜로 밀어» 넘어가는가.

   2026-09-25 사장님: 「사진을 크게 본 채로 옆으로 밀어도 다음 사진이 안 나온다」.
   대화방 쪽은 photo_swipe_real_test 가 본다. 여기는 사진첩 화면(PhotoPage)이다 —
   이 화면은 설명·반응 칸이 아래에 붙은 «따로 만든 화면»이라 같은 시험을 따로 한다. */
void main() {
  final st = AppState.i;

  tearDown(() {
    st.setCouple({});
    st.setItems([]);
  });

  Future<List<Map<String, dynamic>>> openAlbum(WidgetTester t, {int start = 0}) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start();
    final rows = [...st.by('photo')];
    expect(rows.length, greaterThanOrEqualTo(2), reason: '둘러보기 모임에 사진이 두 장은 있어야 넘겨 본다');
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: PhotoPage(rows: rows, start: start),
    ));
    await t.pumpAndSettle();
    return rows;
  }

  String title(WidgetTester t) {
    final f = find.descendant(of: find.byType(AppBar), matching: find.textContaining(' / '));
    return f.evaluate().isEmpty ? '' : (t.widget<Text>(f.first).data ?? '');
  }

  testWidgets('사진 위에서 왼쪽으로 밀면 다음 사진', (t) async {
    final rows = await openAlbum(t);
    expect(title(t), '1 / ${rows.length}');
    await t.flingFrom(t.getCenter(find.byType(PageView)), const Offset(-300, 0), 800);
    await t.pumpAndSettle();
    expect(title(t), '2 / ${rows.length}', reason: '밀었는데 다음 사진으로 안 넘어갔다');
  });

  testWidgets('오른쪽으로 밀면 이전 사진', (t) async {
    final rows = await openAlbum(t, start: 1);
    expect(title(t), '2 / ${rows.length}');
    await t.flingFrom(t.getCenter(find.byType(PageView)), const Offset(300, 0), 800);
    await t.pumpAndSettle();
    expect(title(t), '1 / ${rows.length}', reason: '밀었는데 이전 사진으로 안 넘어갔다');
  });
}
