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
    final body = chat.substring(at, (at + 900).clamp(0, chat.length));
    expect(body.contains('maxScrollExtent'), isTrue,
        reason: '얼마나 위에 있는지 안 보고 무조건 내리고 있다');
    expect(body.contains('return'), isTrue, reason: '멀리 있으면 그냥 두는 갈래가 없다');
  });

  test('«이미 자란 뒤»라는 걸 셈에 넣는다', () {
    /* 이 알림은 사진이 자란 «다음»에 온다. 평소의 아래 판정(80px)을 그대로 쓰면
       아래를 보고 있던 사람도 사진 높이만큼 밀려 「아래가 아니다」가 되어 버린다. */
    final at = chat.indexOf('void _followGrowth()');
    final body = chat.substring(at, (at + 900).clamp(0, chat.length));
    final m = RegExp(r'maxScrollExtent - p\.pixels > (\d+)').firstMatch(body);
    expect(m, isNotNull, reason: '여유 값이 안 보인다');
    expect(int.parse(m!.group(1)!), greaterThan(200),
        reason: '여유가 사진 높이보다 작으면 정작 밀린 사람을 못 잡는다');
  });
}
