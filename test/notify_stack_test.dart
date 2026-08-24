import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/push.dart';

/* 🔔 알림이 «쌓이지» 않게.

   서버(functions/index.js)는 알림마다 `tag` 를 함께 보낸다 — 지금은 대화 알림 하나뿐(`club-msg`).
   웹은 그 값으로 **같은 갈래를 한 자리에 덮어쓴다**(알림이 하나로 갱신된다).
   앱은 메시지마다 다른 번호(`m.hashCode`)를 써서 **그대로 쌓였다** —
   단체방에서 대화 오십 마디면 알림창에 **오십 개**가 쌓이고 회원이 하나씩 지워야 한다. */
void main() {
  test('기본 갈래의 «값»을 못 박는다', () {
    // 서버가 보내는 값과 같아야 한다 — 관계만 재면 「늘 같은 값」으로 바꿔도 통과한다
    expect(Push.defaultTag, 'club-msg');
    expect(Push.tagOf(null), 'club-msg');
    expect(Push.tagOf('  club-notice  '), 'club-notice');
  });

  test('자리 번호가 «그 갈래에서 나온다» — 아무 값이나가 아니다', () {
    /* 「늘 같은 자리」로 바꿔도 관계 시험은 통과한다(173회차 잣대).
       그래서 갈래 글자에서 나온 값임을 «곧바로» 못 박는다. */
    expect(Push.slotFor('club-msg'), 'club-msg'.hashCode);
    expect(Push.slotFor(null), 'club-msg'.hashCode);
  });

  test('같은 갈래는 «같은 자리»에 겹친다', () {
    // 서버가 준 값과 앞뒤 공백이 붙은 값이 «같은 자리»라야 그만큼 안 쌓인다
    expect(Push.slotFor(' club-msg '), Push.slotFor(Push.defaultTag),
        reason: '앞뒤 공백 때문에 자리가 갈리면 그만큼 쌓인다');
  });

  test('갈래가 다르면 «자리도 다르다» — 공지가 대화를 덮으면 안 된다', () {
    expect(Push.slotFor('club-notice'), isNot(Push.slotFor('club-msg')));
  });

  test('갈래가 없거나 비었으면 «기본 자리»로 본다', () {
    for (final v in [null, '', '   ', 7]) {
      expect(Push.tagOf(v), Push.defaultTag, reason: '$v');
      expect(Push.slotFor(v), Push.slotFor(Push.defaultTag));
    }
  });

  test('기본 갈래가 서버가 보내는 값과 «같다»', () {
    final f = File(r'C:\Users\asas3\Desktop\앞산배드민턴\functions\index.js');
    if (!f.existsSync()) return;
    expect(f.readAsStringSync(), contains("tag: '${Push.defaultTag}'"),
        reason: '서버가 보내는 갈래가 바뀌었다 — 앱의 기본값도 맞춰야 한다');
  });

  test('앞에 있을 때·뒤에 있을 때 «둘 다» 그 자리를 쓴다', () {
    final s = File('lib/push.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//.*'), '');
    expect(RegExp(r'id:\s*(Push\.)?slotFor\(').allMatches(s).length, 2,
        reason: '알림을 띄우는 두 자리(앞/뒤) 모두 «겹칠 자리»를 써야 한다 — '
            '한쪽만 고치면 뒤에서 온 알림이 따로 쌓인다');
    expect(s.contains('m.hashCode'), isFalse,
        reason: '메시지마다 다른 번호를 쓰면 알림이 그대로 쌓인다');
    expect(RegExp(r'tag:\s*tag').allMatches(s).length, 2,
        reason: '안드로이드에도 갈래를 알려 줘야 같은 자리에 덮어쓴다');
  });
}
