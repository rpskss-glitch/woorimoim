// 승인 대기 줄의 «차례»와 «기다린 날» (143회차).
//
// 예전에는 서버 묶음이 준 차례 그대로였다 — 그건 번호(uid) 순이라 사실상 아무렇게나다.
//   · 방장은 누가 먼저 신청했는지 알 수 없고
//   · 새 신청이 올 때마다 줄 «중간»에 끼어들어 순서가 뒤바뀐다
// 신청한 때(requestedAt)는 처음부터 적히고 있었는데 **어디에서도 쓰지 않았다.**
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

int ms(DateTime d) => d.millisecondsSinceEpoch;

void seed(Map<String, dynamic> pending) {
  AppState.i.couple = Store.tidyCouple({
    'members': {
      'u0': {'uid': 'u0', 'name': '방장', 'role': 'owner'}
    },
    'pending': pending,
  });
}

void main() {
  final now = DateTime.now();

  test('먼저 신청한 사람이 위에 온다 — 번호 차례가 아니다', () {
    /* 번호는 «늦게» 신청한 사람이 앞서도록 일부러 거꾸로 지었다.
       차례를 안 세우면 이 시험이 그 사실을 드러낸다. */
    seed({
      'aaa': {'uid': 'aaa', 'name': '늦게', 'requestedAt': ms(now)},
      'zzz': {'uid': 'zzz', 'name': '먼저', 'requestedAt': ms(now.subtract(const Duration(days: 3)))},
    });
    expect(Logic.pendingList().map((p) => p['name']).toList(), ['먼저', '늦게']);
  });

  test('때가 안 적힌 옛 신청은 «가장 오래된 것»으로 본다', () {
    seed({
      'a': {'uid': 'a', 'name': '오늘', 'requestedAt': ms(now)},
      'b': {'uid': 'b', 'name': '옛것'},
    });
    expect(Logic.pendingList().first['name'], '옛것');
  });

  test('신청이 없으면 빈 목록', () {
    seed({});
    expect(Logic.pendingList(), isEmpty);
  });

  test('기다린 날을 «날짜로» 센다 — 밤 11시 신청은 새벽 1시에 「어제」', () {
    final at = DateTime(2026, 8, 22, 23, 30);
    final nextDawn = DateTime(2026, 8, 23, 1, 0);
    expect(Logic.waitedFor(ms(at), nextDawn), '어제 신청',
        reason: '지난 시간(1시간 반)으로 세면 「오늘」이 된다');
    expect(Logic.waitedFor(ms(DateTime(2026, 8, 23, 9)), nextDawn), '오늘 신청');
    expect(Logic.waitedFor(ms(DateTime(2026, 8, 18)), nextDawn), '5일째 기다림');
  });

  test('없거나 말이 안 되는 때에는 «아무 말도 안 한다»', () {
    expect(Logic.waitedFor(null, now), isNull);
    expect(Logic.waitedFor(0, now), isNull);
    expect(Logic.waitedFor('글자', now), isNull);
    expect(Logic.waitedFor(ms(DateTime(1999, 1, 1)), now), isNull, reason: '너무 옛 값');
    expect(Logic.waitedFor(ms(now.add(const Duration(days: 30))), now), isNull,
        reason: '앞선 시계는 안 믿는다');
  });

  test('회원 화면이 «차례 세운 목록»과 «기다린 날»을 쓴다', () {
    final code = stripComments(File('lib/ui/members.dart').readAsStringSync());
    expect(code.contains('Logic.pendingList()'), isTrue,
        reason: '서버가 준 차례 그대로면 방장이 누가 먼저인지 모른다');
    expect(code.contains('Logic.waitedFor('), isTrue);
    expect(code.contains('st.pending.values'), isFalse,
        reason: '차례 없는 옛 방식이 돌아왔다');
  });
}
