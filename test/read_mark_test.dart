// 「읽음」을 언제 찍는지.
//
// 84회차: 문지기가 「채팅 탭인지」 하나뿐이었다. 회원이 채팅 탭에 둔 채 폰을 주머니에 넣어도
// 구독은 살아 있어서 새 대화가 오는 족족 «읽음»으로 적혔다 —
// 보낸 사람에게는 「읽음 1」이 뜨고, 받는 사람의 안읽음 배지는 영영 0이었다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/ui/chat.dart';

void main() {
  test('채팅 탭이 아니면 무엇이든 읽음이 아니다', () {
    for (final s in [null, ...AppLifecycleState.values]) {
      expect(countsAsRead(false, s), isFalse, reason: '$s');
    }
  });

  test('앱이 앞에 있을 때만 읽음이다', () {
    expect(countsAsRead(true, AppLifecycleState.resumed), isTrue);
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
      AppLifecycleState.hidden,
    ]) {
      expect(countsAsRead(true, s), isFalse,
          reason: '$s 인데 읽음으로 치면 안읽음 배지가 영영 0이 된다');
    }
  });

  test('아직 앱 상태를 모르면(첫 화면) 읽음으로 본다', () {
    expect(countsAsRead(true, null), isTrue);
  });

  test('읽음 표시가 이 판단을 실제로 쓴다', () {
    final src = File('lib/ui/chat.dart').readAsStringSync();
    final at = src.indexOf('Future<void> _markSeen()');
    expect(at, greaterThan(0));
    final body = src.substring(at, src.indexOf('\n  }\n', at));
    expect(body.contains('countsAsRead('), isTrue,
        reason: '탭만 보면 뒤에 있는 앱이 읽음을 찍는다');
    expect(body.contains('lifecycleState'), isTrue);
  });

  test('앱으로 돌아왔을 때 다시 읽음을 찍는다', () {
    final src = File('lib/ui/chat.dart').readAsStringSync();
    expect(src.contains('with WidgetsBindingObserver'), isTrue,
        reason: '앱 상태를 안 들으면 돌아와도 배지가 안 지워진다');
    final at = src.indexOf('didChangeAppLifecycleState');
    expect(at, greaterThan(0));
    expect(src.substring(at, at + 260).contains('_markSeen()'), isTrue);
    // 들었으면 반드시 떼야 한다 — 안 떼면 화면이 사라진 뒤에도 불린다
    expect(src.contains('removeObserver(this)'), isTrue);
  });
}
