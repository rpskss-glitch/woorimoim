// 폰을 바꾼 «직후» 첫 화면이 맞는가 (153회차).
//
// 이어받기는 이름·직책·생일·회비 주인까지 옮기는데 **「어디까지 읽었는지」는 안 가져왔다.**
// 그 값은 기기마다 따로 있어 새 폰에서는 0이다 →
// 창 안의 남의 대화가 전부 안읽음으로 잡혀 **폰을 바꾸자마자 「안읽음 200」**이 뜬다
// (옛 폰에서 이미 다 읽은 것인데도). 서버에는 옛 번호의 읽음 표시가 그대로 남아 있다.
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

/// 폰을 바꾼 «뒤»의 방 — 옛 번호 u9 의 것이 새 번호 u1 로 이어져야 한다
void seedAfterMove() {
  final now = DateTime.now();
  final lw = DateTime(now.year, now.month, now.day - 7);
  AppState.i.couple = Store.tidyCouple({
    'title': '앞산 배드민턴',
    'fee': {'amount': 20000},
    'members': {
      'u1': {'uid': 'u1', 'name': '갑', 'role': 'member', 'title': '총무',
             'birth': '1990-01-01',
             'joinedAt': DateTime(now.year, now.month - 3, 1).millisecondsSinceEpoch},
      'u2': {'uid': 'u2', 'name': '을', 'role': 'owner',
             'joinedAt': DateTime(now.year, now.month - 3, 1).millisecondsSinceEpoch},
    },
    'former': {
      'u9': {'uid': 'u9', 'name': '갑', 'movedTo': 'u1', 'leftAt': 1700000000000}
    },
    'lastRead': {'u9': lw.millisecondsSinceEpoch + 500},
  });
  AppState.i.setItems(Store.tidy([
    // 옛 번호로 쌓인 출석 세 번 (세 회차)
    // ⚠️ 날짜는 «오늘부터 하루씩 전»으로 — 「7·14·21일 전」으로 두면 달 초(1~7일)에는
    //    셋 다 지난달로 빠져 「이번 달 순위」가 비어 시험이 그날만 깨진다(2026-09-01에 겪음).
    for (var i = 0; i < 3; i++)
      {'id': 'e$i', 'type': 'event', 'title': '모임', 'repeat': 'none',
       'date': ymdOf(DateTime(now.year, now.month, now.day - i)),
       'attend': {'${ymdOf(DateTime(now.year, now.month, now.day - i))}_u9': true},
       'createdAt': lw.millisecondsSinceEpoch + i},
    // 옛 번호로 낸 이번 달 회비
    {'id': 'l1', 'type': 'ledger', 'kind': 'in', 'payer': 'u9', 'amount': 20000,
     'feeMonths': ['${now.year}-${d2(now.month)}'], 'date': ymdOf(now),
     'createdAt': now.millisecondsSinceEpoch},
    // 옛 폰에서 «이미 읽은» 남의 대화 둘 + 그 뒤에 온 새 대화 하나
    {'id': 'm1', 'type': 'msg', 'text': '안녕', 'by': 'u2',
     'createdAt': lw.millisecondsSinceEpoch},
    {'id': 'm2', 'type': 'msg', 'text': '반가워요', 'by': 'u2',
     'createdAt': lw.millisecondsSinceEpoch + 100},
    {'id': 'm3', 'type': 'msg', 'text': '오늘 나오세요?', 'by': 'u2',
     'createdAt': lw.millisecondsSinceEpoch + 900},
  ]));
}

/// 새 폰에서 세는 안읽음 (shell 과 같은 규칙)
int unread(int seen) => AppState.i
    .by('msg')
    .where((m) =>
        !Logic.isMe(m['by'] as String?, 'u1') &&
        ((m['createdAt'] as num?) ?? 0) > seen)
    .length;

void main() {
  setUp(seedAfterMove);

  test('출석·순위·배지가 곧바로 이어진다', () {
    expect(Logic.attendStats()['u1'], 3, reason: '옛 번호로 찍힌 출석 세 번');
    expect(Logic.monthRank().map((e) => e.key), contains('u1'));
    expect(Logic.badgesOf(3).length, 2, reason: '첫 출석·세 번째 배지');
    expect(Logic.nextBadge(3)?.$1, 5);
  });

  test('회비가 곧바로 이어진다 — 미납으로 안 뜬다', () {
    final now = DateTime.now();
    final thisMonth = '${now.year}-${d2(now.month)}';
    expect(Logic.paidIn('u1', thisMonth), isTrue);
    expect(Logic.unpaidMonths('u1'), isNot(contains(thisMonth)));
  });

  test('직책도 그대로 — 회비를 다룰 수 있다', () {
    expect(AppState.i.members['u1']?['title'], '총무');
    expect(Logic.keepsMoneyByTitle('총무'), isTrue);
  });

  test('이름 찾기가 옛 번호로도 된다', () {
    expect(AppState.i.nameOf('u9'), '갑');
    expect(Logic.liveUid('u9'), 'u1');
    expect(Logic.pastUids('u1'), contains('u9'));
  });

  test('읽음 표시를 «안» 이어받으면 안읽음이 잘못 나온다 (재현)', () {
    // 새 폰은 이 값을 모른다 → 0
    expect(unread(0), 3, reason: '이미 읽은 둘까지 안읽음으로 잡힌다');
  });

  test('읽음 표시를 이어받으면 «새로 온 것»만 안읽음이다', () {
    final read = (AppState.i.couple?['lastRead'] as Map?)?['u9'] as num;
    expect(unread(read.toInt()), 1, reason: '옛 폰에서 이미 읽은 둘은 빠져야 한다');
  });

  test('이어받기가 읽음 표시를 «실제로» 가져온다', () {
    final code = stripComments(File('lib/ui/onboarding.dart').readAsStringSync());
    final at = code.indexOf('migrateFeePayer(');
    expect(at, greaterThan(0));
    final after = code.substring(at, (at + 500).clamp(at, code.length));
    /* ⚠️ 「oldUid 라는 글자가 있나」로 보면 안 된다 — 바로 옆 `migrateFeePayer(code, oldUid, uid)`
       에도 있어서, 새 번호를 보도록 바꿔 놔도 그냥 통과한다(153회차에 미끼가 새어 나갔다). */
    expect(after.contains("(c['lastRead'] as Map?)?[oldUid]"), isTrue,
        reason: '폰을 바꾸자마자 「안읽음 200」이 뜬다 — «옛» 번호의 읽음 표시라야 한다');
    expect(after.contains('lastSeenChat'), isTrue);
  });
}
