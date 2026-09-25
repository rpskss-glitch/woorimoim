import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

/* 👀 「읽음 N」 — «볼 수 있는 사람» 중에서만 센다. (2026-09-25 조사)
   · 대화는 가입한 뒤부터 보인다(chatFloor). 그런데 나중에 들어온 회원도 마지막으로 읽은 시각이
     더 뒤라 옛 메시지에 «읽음»으로 세어졌다 — 볼 수도 없는 말을 읽은 것으로.
   · 운영진 방 말은 평회원에게 안 보이는데, 평회원의 읽은 시각도 더 뒤라 «읽음»으로 세어졌다.
   보낸 사람은 「모두 봤구나」로 착각한다. */
void main() {
  const t = 1000000000000; // 메시지 시각
  final members = {
    'me': {'role': 'owner', 'joinedAt': t - 999999},
    'old': {'role': 'member', 'joinedAt': t - 999999},
    'staff': {'role': 'admin', 'joinedAt': t - 999999},
    'late': {'role': 'member', 'joinedAt': t + 3600000}, // 한 시간 뒤 가입
  };
  final reads = {'me': t + 10, 'old': t + 10, 'staff': t + 10, 'late': t + 7200000, 'gone': t + 10};

  test('나중에 들어온 사람·나간 사람·나는 안 센다', () {
    expect(Logic.readCount({'createdAt': t}, members, reads, 'me'), 2); // old, staff
  });

  test('운영진 방 말은 운영진만 센다', () {
    expect(Logic.readCount({'createdAt': t, 'room': 'staff'}, members, reads, 'me'), 1); // staff
  });

  test('가입 5분 전 말은 보인다(chatFloor 와 같은 여유)', () {
    final m = {...members, 'late': {'role': 'member', 'joinedAt': t + 60000}}; // 1분 뒤 가입
    expect(Logic.readCount({'createdAt': t}, m, reads, 'me'), 3);
  });

  test('대화 화면이 이 규칙을 쓴다', () {
    final s = File('lib/ui/chat.dart').readAsStringSync();
    expect(s, contains('Logic.readCount('));
  });
}
