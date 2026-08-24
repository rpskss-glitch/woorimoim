// 채팅 한 줄의 짜임 — 아바타 + 말풍선 + 읽음·시각이 한 줄에 놓인다.
// 좁은 화면·큰 글자에서 이 줄이 넘치면 시각이 잘리거나 노란 줄무늬가 뜬다.
//
// ⚠️ 이 시험은 앱과 «같은 구조»로 지어서 잰다(말풍선 위젯이 private 이라 직접 못 띄운다).
//    구조가 바뀌면 이 시험도 같이 고쳐야 한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/theme.dart';

Widget bubbleRow({required bool mine, required String text}) {
  final meta = Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: const [
        Text('안읽음', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        Text('오후 7:30', style: TextStyle(fontSize: 10)),
      ],
    ),
  );
  final bubble = Container(
    constraints: const BoxConstraints(maxWidth: 260),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    color: Colors.blue.shade100,
    child: Text(text, style: const TextStyle(fontSize: 15, height: 1.35)),
  );
  return Row(
    mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      if (!mine) const SizedBox(width: 38, child: CircleAvatar(radius: 17)),
      if (!mine) const SizedBox(width: 6),
      if (mine) meta,
      // ⚠️ 이 Flexible 이 없으면 «보통 글자·보통 폰»에서도 넘친다 (실측: 내 말풍선 3.8px, 남 48px)
      Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bubble])),
      if (!mine) meta,
    ],
  );
}

void main() {
  for (final scale in [1.0, 1.6, 2.0]) {
    for (final mine in [true, false]) {
      testWidgets('${mine ? '내' : '남의'} 말풍선 줄이 안 넘친다 · 글자 $scale배 · 360px 폰', (t) async {
        t.view.physicalSize = const Size(360, 640);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        await t.pumpWidget(MaterialApp(
          theme: buildTheme('sky'),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: bubbleRow(mine: mine, text: '이번 주 수요일 저녁 7시에 앞산 체육관에서 모임 합니다'),
            ),
          ),
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '줄이 넘치면 시각·읽음 표시가 잘린다');
      });
    }
  }

  testWidgets('붙여넣은 긴 주소도 말풍선 안에서 접힌다', (t) async {
    // 회원들이 지도·영상 링크를 그대로 붙여넣는다 — 띄어쓰기가 없어 안 접히면 옆으로 삐져나간다
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    const url = 'https://map.naver.com/p/entry/place/1234567890?c=15.00,0,0,0,dh&placePath=%2Fhome';
    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: Scaffold(body: Align(alignment: Alignment.topLeft, child: bubbleRow(mine: false, text: url))),
    ));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(t.getRect(find.text(url)).width, lessThanOrEqualTo(235),
        reason: '말풍선 칸(260에서 안쪽 여백 26을 뺀 234)을 넘으면 안 된다');
  });
}
