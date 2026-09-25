import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/moderation.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/members.dart';

/* 🚩 신고가 «운영진에게 실제로 보이고», 처리할 수 있다.

   2026-09-25 조사: 신고는 기록으로 적히기만 했고 앱·웹·서버 어디서도 안 읽었다.
   회원은 「신고했어요 — 운영진이 확인합니다」를 봤지만 운영진이 볼 곳이 없었다.
   애플 1.2(사용자 콘텐츠)는 신고가 «처리»되는 길을 요구한다. */
void main() {
  final st = AppState.i;

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    Demo.start(); // 나는 방장
    Demo.addItem({
      'type': 'msg',
      'coupleId': Demo.code,
      'by': 'u_jh',
      'text': '광고 링크 http://spam',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    }, docId: 'bad1');
    Demo.addItem({
      'type': 'report',
      'coupleId': Demo.code,
      'by': 'u_sh',
      'targetId': 'bad1',
      'targetBy': 'u_jh',
      'reason': '광고·스팸',
      'text': '광고 링크 http://spam',
      'done': false,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    }, docId: 'rep1');
    await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: const MembersScreen()));
    await t.pumpAndSettle();
  }

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });

  testWidgets('운영진 회원 화면에 신고가 보인다 — 무엇이, 왜, 누가', (t) async {
    await open(t);
    expect(find.text('🚩 신고 1건'), findsOneWidget, reason: '신고가 들어왔는데 운영진이 볼 곳이 없다');
    expect(find.textContaining('광고·스팸'), findsOneWidget);
    expect(find.textContaining('광고 링크'), findsWidgets);
    expect(find.textContaining('신고한 사람:'), findsOneWidget);
  });

  testWidgets('「처리 끝」 — 신고함에서 빠진다', (t) async {
    await open(t);
    await t.tap(find.text('처리 끝'));
    await t.pumpAndSettle();
    expect(Moderation.openReports(), isEmpty);
    expect(find.textContaining('🚩 신고'), findsNothing);
  });

  testWidgets('「그 글 지우기」 — 신고된 글이 사라지고 신고도 닫힌다', (t) async {
    await open(t);
    await t.tap(find.text('그 글 지우기'));
    await t.pumpAndSettle();
    await t.tap(find.text('지우기').last); // 확인창
    await t.pumpAndSettle();
    expect(st.byId('bad1'), isNull, reason: '신고된 글이 그대로다');
    expect(Moderation.openReports(), isEmpty, reason: '지웠는데 신고가 계속 남아 있다');
  });

  test('처리 안 한 신고만, 새것이 위', () {
    Demo.start();
    Demo.addItem({'type': 'report', 'coupleId': Demo.code, 'done': true, 'createdAt': 3}, docId: 'r_done');
    Demo.addItem({'type': 'report', 'coupleId': Demo.code, 'done': false, 'createdAt': 1790000000000}, docId: 'r_old');
    Demo.addItem({'type': 'report', 'coupleId': Demo.code, 'done': false, 'createdAt': 1790000009000}, docId: 'r_new');
    expect(Moderation.openReports().map((r) => r['id']), ['r_new', 'r_old']);
  });
}
