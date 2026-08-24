import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/theme.dart';

/* 📏 「줄(Row) 안에 넣는 단추」 — 195회차.

   테마가 `FilledButton` 에 `Size.fromHeight(50)`(= **가로를 꽉 채워라**)를 걸어 두었다.
   큰 단추(저장·가입)에는 맞지만, **줄 안에** 그 단추를 두면 옆에 있는 글이 폭 0으로 눌려
   **「김/민/수」처럼 한 글자씩 세로로 쪼개진다.**
   2026-08-24 에뮬레이터에서 회비 화면이 실제로 그렇게 나왔다 —
   화면으로 띄워 보기 전에는 아무도 몰랐다(시험도 못 잡았다). 그래서 이 시험을 둔다. */
void main() {
  testWidgets('줄 안에 단추를 두어도 옆 글자가 안 눌린다', (t) async {
    t.view.physicalSize = const Size(1080, 400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(radius: 17),
              const SizedBox(width: 10),
              const Expanded(child: Text('김민수', key: Key('name'))),
              FilledButton.tonal(
                style: inlineButtonStyle,
                onPressed: () {},
                child: const Text('회비 받기'),
              ),
            ],
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    final w = t.getSize(find.byKey(const Key('name'))).width;
    expect(w, greaterThan(200),
        reason: '이름 칸이 $w px 로 눌렸다 — 글자가 세로로 쪼개져 보인다');
  });

  testWidgets('그 style 을 빼면 실제로 망가진다 (시험이 헛돌지 않는지)', (t) async {
    t.view.physicalSize = const Size(1080, 400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final errs = <String>[];
    final prev = FlutterError.onError;
    FlutterError.onError = (d) => errs.add(d.exception.toString());

    await t.pumpWidget(MaterialApp(
      theme: buildTheme('sky'),
      home: Scaffold(
        body: Row(
          children: [
            const Expanded(child: Text('김민수')),
            FilledButton.tonal(onPressed: () {}, child: const Text('회비 받기')),
          ],
        ),
      ),
    ));
    await t.pump();
    FlutterError.onError = prev;
    /* style 을 안 얹으면 단추가 «가로를 꽉» 달라고 해서 옆 칸이 0폭이 된다 —
       Flutter 는 그 자리를 아예 못 그리고 오류를 낸다(에뮬레이터에서는 글자가 세로로 쪼개져 보였다). */
    expect(errs, isNotEmpty, reason: '미끼가 안 물렸다 — 이 시험은 아무것도 지키지 못한다');
  });

  test('줄 안에서 쓰는 자리는 모두 그 style 을 얹었다', () {
    /* 회비 화면에서 실제로 터진 자리. 다른 곳도 같은 꼴이면 여기 목록에 더한다. */
    final wallet = File('lib/ui/wallet.dart').readAsStringSync();
    final at = wallet.indexOf('class _MemberFeeRow');
    expect(at, greaterThan(0));
    final body = wallet.substring(at, at + 2200);
    expect(body.contains('inlineButtonStyle'), isTrue,
        reason: '회원별 납부 현황 줄이 다시 «한 글자씩» 쪼개진다');
  });
}
