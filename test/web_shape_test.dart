// 웹앱(아이폰 회원)이 만든 «모양 그대로»의 자료가 이 앱을 지나는가 (147회차).
//
// 두 앱은 같은 방을 쓴다. 145·146회차에 그 경계에서 버그가 둘 나왔다
// (음성 메시지가 빈 말풍선 · 지출 갈래가 두 줄로 갈림).
// 그래서 «웹이 실제로 적는 모양»을 한 벌 두고 앱의 셈을 전부 지나가게 한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/common.dart';

String d2(int v) => v.toString().padLeft(2, '0');
String ymdOf(DateTime d) => '${d.year}-${d2(d.month)}-${d2(d.day)}';

void main() {
  final now = DateTime.now();
  final lastWeek = DateTime(now.year, now.month, now.day - 7);
  final thisMonth = '${now.year}-${d2(now.month)}';
  final joined = DateTime(now.year, now.month - 2, 1).millisecondsSinceEpoch;

  setUp(() {
    /* 웹앱이 실제로 적는 것들:
       · 회원 사진은 `data:` (문서 안에 통째로 든 옛 방식)
       · 폰 바꾼 사람은 former[옛번호].movedTo
       · 지출은 영어 갈래 열쇠(court)와 payer: 'wallet'
       · 회비는 feeMonths 없이 date 만 있는 것도 있다
       · 웹 전용 갈래(todo·dday)와 웹 전용 칸(pinned·goal·memo·subKey·rcptId) */
    AppState.i.couple = Store.tidyCouple({
      'title': '앞산 배드민턴',
      'titleKey': '앞산배드민턴',
      'theme': 'sky',
      'fee': {'day': 5, 'amount': 20000},
      'pinned': {'id': 'd1'},
      'goal': {'name': '연말 대회'},
      'members': {
        'u1': {'uid': 'u1', 'name': '갑', 'role': 'owner', 'emoji': '🏸', 'joinedAt': joined},
        'u2': {'uid': 'u2', 'name': '을', 'role': 'member',
               'photo': 'data:image/jpeg;base64,AAAA', 'joinedAt': joined},
      },
      'former': {
        'u9': {'uid': 'u9', 'name': '을(옛폰)', 'movedTo': 'u2', 'leftAt': 1700000000000}
      },
      'push': {'u1': {'token': 't', 'mute': 'admin'}},
    });
    final lw = ymdOf(lastWeek);
    AppState.i.setItems(Store.tidy([
      {'id': 'l1', 'type': 'ledger', 'kind': 'out', 'amount': 240000,
       'title': '체육관 대관료', 'cat': 'court', 'payer': 'wallet', 'memo': '정기 지출',
       'subKey': 'sb1', 'rcptId': 'st:c/r1', 'rcptThumb': 'data:image/jpeg;base64,BB',
       'date': lw, 'createdAt': lastWeek.millisecondsSinceEpoch},
      {'id': 'l2', 'type': 'ledger', 'kind': 'out', 'amount': 30000,
       'title': '셔틀콕', 'cat': 'shuttle', 'payer': 'wallet',
       'date': lw, 'createdAt': lastWeek.millisecondsSinceEpoch + 1},
      // 이 앱이 적은 «같은 뜻»의 갈래 — 웹 것과 한 줄로 합쳐져야 한다
      {'id': 'l3', 'type': 'ledger', 'kind': 'out', 'amount': 20000,
       'title': '셔틀콕 추가', 'cat': '셔틀콕',
       'date': lw, 'createdAt': lastWeek.millisecondsSinceEpoch + 2},
      // 회비 — feeMonths 없이 «날짜»만 있고, 게다가 «옛 번호»로 냈다
      {'id': 'l4', 'type': 'ledger', 'kind': 'in', 'amount': 20000,
       'title': '이번 달 회비', 'cat': null, 'payer': 'u9',
       'date': ymdOf(now), 'createdAt': now.millisecondsSinceEpoch},
      {'id': 'e1', 'type': 'event', 'title': '정기 모임', 'date': lw,
       'time': '19:00', 'cat': 'meet', 'repeat': 'week',
       'rsvp': {'${lw}_u9': 'yes'},
       'attend': {'${lw}_u9': true},
       'createdAt': lastWeek.millisecondsSinceEpoch},
      {'id': 'd1', 'type': 'diary', 'title': '공지', 'text': '이번 주 모임',
       'photoIds': ['st:c/p1', 'st:c/p2'], 'by': 'u1',
       'date': lw, 'createdAt': lastWeek.millisecondsSinceEpoch},
      // 웹 전용 갈래 — 앱이 안 읽지만 들어와도 다른 화면을 망가뜨리면 안 된다
      {'id': 't1', 'type': 'todo', 'title': '셔틀콕 주문', 'done': false,
       'createdAt': now.millisecondsSinceEpoch},
      {'id': 'dd1', 'type': 'dday', 'title': '대회', 'date': ymdOf(now),
       'createdAt': now.millisecondsSinceEpoch},
      {'id': 'm1', 'type': 'msg', 'kind': 'voice', 'text': '', 'by': 'u9',
       'createdAt': now.millisecondsSinceEpoch},
      /* 웹이 적은 «투표» — 질문이 poll.q 와 text 에 둘 다 있고,
         표는 옛 번호(u9)와 «탈퇴한 회원»(u7) 것까지 섞여 있다 */
      {'id': 'm2', 'type': 'msg', 'kind': 'poll', 'by': 'u1',
       'text': '이번 주 토요일 번개 어때요? 오는 사람만 코트 잡을게요',
       'poll': {'q': '이번 주 토요일 번개 어때요? 오는 사람만 코트 잡을게요',
                'opts': ['오전 9시 (초보 레슨 먼저)', '저녁 7시'], 'multi': false, 'closed': false},
       'votes': {'u9': [1], 'u7': [0]},
       'createdAt': now.millisecondsSinceEpoch + 1},
    ]));
  });

  test('폰 바꾼 회원의 «출석»이 새 번호로 이어진다', () {
    expect(Logic.attendStats()['u2'], 1, reason: '웹에서 옛 번호로 찍힌 출석');
    expect(Logic.monthRank().map((e) => e.key), contains('u2'));
  });

  test('폰 바꾼 회원의 «회비»가 새 번호로 이어진다', () {
    expect(Logic.paidIn('u2', thisMonth), isTrue,
        reason: 'feeMonths 없이 날짜만 있는 웹 기록도 그 달로 세야 한다');
    expect(Logic.unpaidMonths('u2'), isNot(contains(thisMonth)));
  });

  test('지출 갈래가 두 앱에서 «한 줄»로 합쳐진다', () {
    final byCat = <String, int>{};
    for (final x in AppState.i.by('ledger').where((x) => x['kind'] != 'in')) {
      final c = Logic.catLabel(x['cat']) ?? '기타';
      byCat[c] = (byCat[c] ?? 0) + Logic.asInt(x['amount']);
    }
    expect(byCat['체육관'], 240000, reason: '영어 열쇠 court');
    expect(byCat['셔틀콕'], 50000, reason: '웹 shuttle 3만 + 앱 셔틀콕 2만');
    expect(byCat.keys, isNot(contains('court')));
  });

  test('통장 잔액이 맞다', () {
    expect(Logic.balance(), 20000 - 290000);
  });

  test('웹 전용 갈래가 들어와도 다른 화면을 망가뜨리지 않는다', () {
    expect(AppState.i.by('event'), hasLength(1));
    expect(AppState.i.by('diary'), hasLength(1));
    expect(Logic.eventRows(past: true), isNotEmpty);
    expect(Logic.nextEvent(), isNotNull);
  });

  test('지울 때 웹이 붙인 사진·영수증 원본을 빠짐없이 챙긴다', () {
    expect(Store.photoIdsOf(AppState.i.byId('d1')).toSet(), {'st:c/p1', 'st:c/p2'});
    expect(Store.photoIdsOf(AppState.i.byId('l1')), contains('st:c/r1'));
    expect(Store.photoIdsOfCouple(AppState.i.couple),
        contains('data:image/jpeg;base64,AAAA'));
  });

  test('음성 메시지가 «음성»이라고 보인다', () {
    /* 「빈 자리가 아니다」로만 보면 «모르는 갈래» 되돌림 문구에 속는다 —
       무엇인지까지 말해야 알림(「🎤 음성 메시지를 보냈어요」)과 화면이 맞는다. */
    final s = msgLabel(AppState.i.byId('m1')!);
    expect(s, isNotEmpty);
    expect(s.contains('음성'), isTrue,
        reason: '알림은 음성이라 했는데 화면은 「볼 수 없는 메시지」라고 한다');
  });

  test('웹이 만든 투표가 «투표»라고 보이고, 표를 바르게 센다', () {
    final m = AppState.i.byId('m2')!;
    expect(msgLabel(m).contains('투표'), isTrue);
    expect(msgLabel(m).contains('번개'), isTrue, reason: '질문이 안 보이면 무슨 투표인지 모른다');
    final t = Logic.pollTally(m);
    // 옛 번호로 찍은 표는 «지금 회원»의 표로, 탈퇴한 회원(u7)의 표는 빼고
    expect(t.per[1], ['u2']);
    expect(t.per[0], isEmpty, reason: '탈퇴한 회원의 옛 표까지 센다');
    expect(t.voters, 1);
    // 옛 번호로 찍은 것도 «내 표»로 잡혀야 단추가 눌린 것으로 보인다
    expect(Logic.pollMine(m, 'u2'), [1]);
  });

  testWidgets('웹이 보낸 것들을 좁은 화면·큰 글자로 그려도 안 넘친다', (t) async {
    final errs = <String>[];
    final prev = FlutterError.onError;
    FlutterError.onError = (d) => errs.add(d.exception.toString());
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
      child: MaterialApp(
        theme: buildTheme('sky'),
        home: Scaffold(
          body: Column(children: [
            Row(children: [
              const Avatar('u2', size: 34),
              const SizedBox(width: 6),
              Flexible(child: Text(msgLabel(AppState.i.byId('m1')!))),
            ]),
            // 투표 카드는 말풍선(폭 260) 안에 든다 — 그 안에서 안 넘쳐야 한다
            Row(children: [
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 260),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  child: PollCard(
                      msg: AppState.i.byId('m2')!, mine: false, myUid: 'u2'),
                ),
              ),
            ]),
            const Emblem(basePx: emblemBasePx, capScale: 2),
          ]),
        ),
      ),
    ));
    await t.pump(const Duration(milliseconds: 200));
    FlutterError.onError = prev;
    expect(errs.where((e) => e.contains('overflow')), isEmpty);
  });
}
