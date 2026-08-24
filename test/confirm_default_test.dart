import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/common.dart';

/* ❓ 「물어보는 창」의 답 — **닫아 버린 것은 «아니오»다.**

   되돌릴 수 없는 일(방장 넘기기·방 지우기·탈퇴·기록 지우기)이 전부 이 창을 거친다.
   창을 «밖을 눌러» 닫거나 뒤로 가기로 닫으면 답이 없는데, 그때 «예»로 보면
   **누르지도 않은 일이 그냥 일어난다.**
   185회차 흔들기에서 이 기본값을 뒤집어도 아무도 안 울었다 — 그래서 «실제로 창을 띄워» 못 박는다. */
void main() {
  testWidgets('«밖을 눌러» 닫으면 「아니오」다', (t) async {
    bool? got;
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                got = await confirmSheet(c, '지울까요?', '되돌릴 수 없어요', okLabel: '지우기');
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    expect(find.text('지울까요?'), findsOneWidget);

    // 창 «밖»(맨 위 구석)을 누른다 — 답을 안 하고 닫는 것
    await t.tapAt(const Offset(8, 8));
    await t.pumpAndSettle();
    expect(got, isFalse,
        reason: '답을 안 하고 닫았는데 «예»로 본다 — '
            '누르지도 않은 «되돌릴 수 없는 일»이 그냥 일어난다');
  });

  testWidgets('「취소」를 누르면 「아니오」다', (t) async {
    bool? got;
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                got = await confirmSheet(c, '지울까요?', '되돌릴 수 없어요', okLabel: '지우기');
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    await t.tap(find.text('취소'));
    await t.pumpAndSettle();
    expect(got, isFalse);
  });

  testWidgets('«그 단추»를 눌러야만 「예」다', (t) async {
    bool? got;
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                got = await confirmSheet(c, '지울까요?', '되돌릴 수 없어요', okLabel: '지우기');
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('열기'));
    await t.pumpAndSettle();
    await t.tap(find.text('지우기'));
    await t.pumpAndSettle();
    expect(got, isTrue, reason: '눌렀는데 «아니오»면 아무 일도 안 일어난다');
  });
}
