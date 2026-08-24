// 모임을 «옮겼을 때» 앞 방의 것이 따라오지 않는가 (152회차).
//
// 151회차에 「채팅 탭으로 가라」 신호가 따라오는 것을 찾았다.
// 그래서 방마다 다른 값을 **한 벌씩 채우고 바꿔 가며** 통째로 확인한다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

String d2(int v) => v.toString().padLeft(2, '0');
String ymdOf(DateTime d) => '${d.year}-${d2(d.month)}-${d2(d.day)}';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

void seed(String who, {required int fee, required bool withData}) {
  final now = DateTime.now();
  final lw = DateTime(now.year, now.month, now.day - 7);
  final lwS = ymdOf(lw);
  AppState.i.couple = Store.tidyCouple({
    'title': who,
    'fee': {'amount': fee},
    'members': {
      'u1': {'uid': 'u1', 'name': '$who갑', 'role': 'owner',
             'joinedAt': DateTime(now.year, now.month - 1, 1).millisecondsSinceEpoch},
    },
    'former': withData
        ? {'u9': {'uid': 'u9', 'name': '옛', 'movedTo': 'u1'}}
        : <String, dynamic>{},
  });
  AppState.i.setItems(Store.tidy(withData
      ? [
          {'id': '$who-e', 'type': 'event', 'title': '$who모임', 'date': lwS,
           'repeat': 'week', 'attend': {'${lwS}_u9': true},
           'createdAt': lw.millisecondsSinceEpoch},
          {'id': '$who-l', 'type': 'ledger', 'kind': 'in', 'payer': 'u9',
           'amount': fee, 'date': '${now.year}-${d2(now.month)}-01',
           'createdAt': now.millisecondsSinceEpoch},
        ]
      : []));
}

Map<String, Object?> snap() => {
      '제목': AppState.i.couple?['title'],
      '회원': AppState.i.memberList.map((m) => m['name']).toList(),
      '내출석': Logic.attendStats()['u1'] ?? 0,
      '이번달순위': Logic.monthRank().length,
      '다음모임있나': Logic.nextEvent() != null,
      '지난회차': Logic.eventRows(past: true).length,
      '잔액': Logic.balance(),
      '옛번호잇기': Logic.liveUid('u9'),
    };

void main() {
  test('자료가 많던 방 → 텅 빈 방: 앞 방 것이 하나도 안 남는다', () {
    seed('A', fee: 20000, withData: true);
    final a = snap();
    expect(a['내출석'], 1, reason: '먼저 방 A가 제대로 세어져야 견줄 수 있다');
    expect(a['잔액'], 20000);

    AppState.i.resetRoom();
    seed('B', fee: 30000, withData: false);
    expect(snap(), {
      '제목': 'B',
      '회원': ['B갑'],
      '내출석': 0,
      '이번달순위': 0,
      '다음모임있나': false,
      '지난회차': 0,
      '잔액': 0,
      '옛번호잇기': 'u9', // 방 B에는 옛 번호 표가 없다 → 그대로
    });
  });

  test('텅 빈 방 → 자료가 많은 방: 새 방 것이 제대로 나온다', () {
    seed('A', fee: 20000, withData: false);
    snap(); // 표를 한 번 채워 둔다
    AppState.i.resetRoom();
    seed('B', fee: 30000, withData: true);
    final b = snap();
    expect(b['내출석'], 1);
    expect(b['잔액'], 30000);
    expect(b['다음모임있나'], isTrue);
    expect(b['옛번호잇기'], 'u1', reason: '방 B의 폰 바꾸기 표를 써야 한다');
  });

  test('같은 모양의 두 방을 오가도 «앞 방 이름»이 안 남는다', () {
    seed('A', fee: 20000, withData: true);
    snap();
    AppState.i.resetRoom();
    seed('B', fee: 20000, withData: true);
    expect(snap()['회원'], ['B갑']);
    expect(AppState.i.couple?['title'], 'B');
  });

  test('방을 «세 번» 오가도 어긋나지 않는다', () {
    for (final r in ['A', 'B', 'C']) {
      AppState.i.resetRoom();
      seed(r, fee: 10000, withData: r != 'B');
      expect(AppState.i.memberList.first['name'], '$r갑');
      expect(Logic.attendStats()['u1'] ?? 0, r == 'B' ? 0 : 1);
    }
  });

  test('방에 들어갈 때 «세는 값»을 처음으로 되돌린다', () {
    /* 접속 표시는 5분에 한 번만 보낸다. 그 막이가 남으면 새 방에는
       「내가 있다」가 최대 5분 동안 안 적혀, 다른 회원이 글을 쳐도
       「입력 중」이 나에게 안 나간다(볼 사람이 없다고 본다). */
    final code = stripComments(File('lib/main.dart').readAsStringSync());
    final at = code.indexOf('void _enter()');
    expect(at, greaterThan(0));
    final body = code.substring(at, (at + 700).clamp(at, code.length));
    for (final k in ['_prevDoc = null', '_lastTouch = 0', '_wasPending = false']) {
      expect(body.contains(k), isTrue, reason: '$k 이 없다 — 앞 방의 셈이 따라온다');
    }
  });
}
