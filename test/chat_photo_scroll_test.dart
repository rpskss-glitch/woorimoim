import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 📷 「사진이 그려지면 대화방이 따라 내려간다」

   2026-08-29 에뮬에서 확인: 총무가 회비 표를 대화방에 올렸는데,
   회원이 대화방을 열면 **그 표가 화면 밖에 있었다.** 손으로 내려야 나왔다.

   왜: 사진 자리는 그려지기 «전»에는 납작하다(자리표시). 사진이 오면 세로로 길어지는데,
   목록은 이미 「맨 아래」로 가 버린 뒤라 늘어난 만큼 아래가 밀려 나간다.
   표 그림은 회원 수만큼 세로로 길어 특히 심하다.

   고칠 길이 둘이었다 —
   (가) 올릴 때 가로·세로를 적어 두고 자리를 미리 잡기: 근본이지만 **옛 사진에는 크기가 없다.**
   (나) 그려진 «뒤» 다시 맞추기: 옛 사진에도 통한다. 그래서 (나)를 골랐다. */
void main() {
  final chat = File('lib/ui/chat.dart').readAsStringSync();
  final common = File('lib/ui/common.dart').readAsStringSync();

  test('사진 위젯이 «다 그려졌다»고 알려 준다', () {
    expect(common.contains('onShown'), isTrue,
        reason: '알림이 없으면 언제 키가 자랐는지 알 길이 없다');
    expect(common.contains('frameBuilder'), isTrue,
        reason: '«받아온 때»가 아니라 «그려진 때»를 알아야 한다 — 그때 키가 바뀐다');
  });

  test('대화방이 그 알림을 받아 따라 내려간다', () {
    expect(chat.contains('onPhotoShown'), isTrue);
    expect(chat.contains('void _followGrowth()'), isTrue);
  });

  test('위에서 옛 대화를 읽는 사람은 «끌어내리지 않는다»', () {
    /* 읽던 자리를 잃으면 어디까지 읽었는지 다시 찾아야 한다 — 긴 대화방에서는 치명적이다. */
    final at = chat.indexOf('void _followGrowth()');
    expect(at, greaterThan(0));
    final body = chat.substring(at, (at + 500).clamp(0, chat.length));
    expect(body.contains('!_stick'), isTrue,
        reason: '올려 둔 사람(_stick=false)을 그냥 두는 갈래가 없다 — 무조건 내리고 있다');
    expect(body.contains('return'), isTrue, reason: '그냥 두는 갈래가 없다');
  });

  test('붙기 여부(_stick)는 «손동작으로만» 바뀐다 — 사진이 자라는 것으로는 안 바뀐다', () {
    /* 핵심이다. 사진이 뒤늦게 떠서 내용이 자라면 위치가 흔들리는데, 그걸 「사용자가 올렸다」로
       오해하면 엉뚱하게 끌려 내려간다. 그래서 _stick 은 **손으로 끄는 중(dragDetails)이거나
       스크롤이 완전히 멈췄을 때(ScrollEnd)**만 다시 정한다. */
    final at = chat.indexOf('bool _onScrollNotif(');
    expect(at, greaterThan(0), reason: '스크롤 알림을 «가려서» 받는 자리가 없다');
    final body = chat.substring(at, (at + 300).clamp(0, chat.length));
    expect(body.contains('dragDetails != null'), isTrue,
        reason: '손으로 끄는 중인지 안 가린다 — 내용이 자라는 것까지 손으로 친다');
    expect(body.contains('ScrollEndNotification'), isTrue,
        reason: '스크롤이 멈춘 때(플링 끝)를 안 챙긴다');
  });
}
