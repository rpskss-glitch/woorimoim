// 망가진 자료가 들어와도 «화면이 통째로 멈추지 않는지».
// 들어오는 길: 백업 복원 · 옛 버전 앱 · 손으로 고친 백업.
// 2026-08-22 실측 — 막기 전에는 아래 여덟 가지 중 여섯 가지가 TypeError 로 앱을 세웠다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

void main() {
  group('망가진 기록', () {
    test('글이 배열이어도 채팅이 그린다', () {
      final m = Store.tidy([{'id': 'm1', 'type': 'msg', 'text': ['가', '나']}]).first;
      expect(() => (m['text'] as String?) ?? '', returnsNormally);
      expect(m['text'], '');
    });

    test('제목이 숫자면 글자로 바꾼다 (버리지 않는다)', () {
      final d = Store.tidy([{'id': 'd1', 'type': 'diary', 'title': 123}]).first;
      expect(d['title'], '123', reason: '숫자는 글자로 살려 둔다 — 회원이 적은 값이다');
    });

    test('사진번호가 배열이 아니면 빈 목록으로', () {
      final p = Store.tidy([{'id': 'p1', 'type': 'photo', 'photoIds': '망가짐'}]).first;
      expect(() => (p['photoIds'] as List?)?.cast<String>(), returnsNormally);
      expect(p['photoIds'], isEmpty);
    });

    test('사진번호 배열 안의 이상한 값은 «자리를 지키며» 바꾼다', () {
      // 빼면 썸네일과 원본이 한 칸씩 밀려 서로 엇갈린다
      final p = Store.tidy([{'id': 'p1', 'type': 'photo', 'photoIds': ['a', 5, 'c']}]).first;
      expect((p['photoIds'] as List).length, 3);
      expect((p['photoIds'] as List)[1], isNull);
    });

    test('음수·너무 큰 회비는 0으로 (합계가 뒤집히지 않게)', () {
      expect(Store.tidy([{'type': 'ledger', 'amount': -500000}]).first['amount'], 0);
      expect(Store.tidy([{'type': 'ledger', 'amount': 999999999999}]).first['amount'], 0);
      expect(Store.tidy([{'type': 'ledger', 'amount': '30000'}]).first['amount'], 30000);
      expect(Store.tidy([{'type': 'ledger', 'amount': 20000}]).first['amount'], 20000);
    });

    test('통장 합계가 음수 한 건에 뒤집히지 않는다', () {
      AppState.i.couple = {'members': <String, dynamic>{}, 'fee': {'amount': 0}};
      AppState.i.setItems(Store.tidy([
        {'id': 'a', 'type': 'ledger', 'kind': 'in', 'amount': 20000},
        {'id': 'b', 'type': 'ledger', 'kind': 'in', 'amount': -500000},
      ]));
      expect(Logic.balance(), 20000);
    });
  });

  group('망가진 모임 문서', () {
    test('모임 이름이 숫자여도 안 터진다', () {
      final c = Store.tidyCouple({'title': 12345});
      expect(() => c?['title'] as String?, returnsNormally);
      expect(c?['title'], '12345');
    });

    test('회원 목록이 글자여도 회원 화면이 뜬다', () {
      AppState.i.couple = Store.tidyCouple({'members': '망가짐'});
      expect(() => AppState.i.memberList, returnsNormally);
      expect(AppState.i.memberList, isEmpty);
    });

    test('월 회비가 배열이거나 음수여도 안 터진다', () {
      expect(() => Store.tidyCouple({'fee': ['망가짐']})?['fee'] as Map?, returnsNormally);
      final c = Store.tidyCouple({'fee': {'amount': -3000}});
      expect((c?['fee'] as Map)['amount'], 0);
    });

    test('null 모임 문서에도 안 터진다', () {
      expect(Store.tidyCouple(null), isNull);
    });
  });

  group('묶음(맵)이어야 하는 칸', () {
    test('채팅 반응이 배열이어도 채팅이 그린다', () {
      // 실측 2026-08-22: 반응이 배열인 대화 한 건에 TypeError → 채팅 화면이 통째로 안 떴다
      final m = Store.tidy([{'id': 'm1', 'type': 'msg', 'text': 'ㄱ', 'reacts': ['망가짐']}]).first;
      expect(() => (m['reacts'] as Map?)?.values.whereType<String>().join(), returnsNormally);
      expect(m['reacts'], isEmpty);
    });

    test('참석 투표·출석표가 망가져도 일정과 홈이 돈다', () {
      final e = Store.tidy([{
        'id': 'e1', 'type': 'event', 'date': '2026-08-05',
        'rsvp': '망가짐', 'attend': ['망가짐'],
      }]).first;
      expect(() => Logic.rsvpCount(e, '2026-08-05', 'yes'), returnsNormally);
      expect(() => Logic.attended(e, '2026-08-05', 'u1'), returnsNormally);
      AppState.i.couple = {'members': <String, dynamic>{}, 'fee': {'amount': 0}};
      AppState.i.setItems([e]);
      expect(() => Logic.attendStats(), returnsNormally);
    });

    test('트랜잭션 안쪽은 «서버 날것»이라 따로 지켜야 한다', () {
      /* 들어올 때 고치는 tidy 는 트랜잭션 콜백에 닿지 않는다 —
         거기서 받는 것은 서버에서 방금 읽은 값 그대로다. */
      final src = File('lib/ui/chat.dart').readAsStringSync();
      final at = src.indexOf("'reacts'");
      expect(at, greaterThan(0));
      expect(src.substring(at - 200, at + 80).contains('Logic.asMap'), isTrue,
          reason: '날것을 as Map? 으로 읽으면 그 자리에서 터진다');
    });
  });

  group('회원 한 명이 망가져도', () {
    /* `members` 는 회원 목록·채팅 이름·아바타·「내 권한」까지 모든 화면이 읽는다 —
       한 사람 때문에 단추가 전부 사라지거나 화면이 안 뜨면 안 된다.
       실측 2026-08-22: 이름이 숫자·이모지가 배열인 회원 한 명에 여섯 곳이 모두 TypeError. */
    setUp(() {
      AppState.i.couple = Store.tidyCouple({
        'members': {
          'u1': {'uid': 'u1', 'name': 123, 'emoji': ['x'], 'role': 5, 'photo': 7, 'title': ['총무']},
          'u2': {'uid': 'u2', 'name': '정상', 'emoji': '🏸', 'role': 'member'},
          'u3': '사람이 아님',
        },
        'fee': {'amount': 10000},
      });
    });

    test('회원 목록이 뜬다 (망가진 사람은 살려서 보여준다)', () {
      expect(() => AppState.i.memberList, returnsNormally);
      expect(AppState.i.memberList.length, 2, reason: '묶음이 아닌 자리는 사람으로 볼 수 없다');
      expect(AppState.i.nameOf('u1'), '123', reason: '숫자 이름은 글자로 살려 둔다');
    });

    test('아바타·권한을 읽어도 안 터진다', () {
      expect(() => AppState.i.emojiOf('u1'), returnsNormally);
      expect(() => AppState.i.photoOf('u1'), returnsNormally);
      AppState.i.profile = {'code': 'C1', 'slot': 'u1', 'name': 'x'};
      expect(() => AppState.i.isAdmin, returnsNormally);
      expect(AppState.i.isAdmin, isFalse, reason: '알 수 없는 권한은 «평회원»으로 본다');
      expect(() => AppState.i.isTreasurer, returnsNormally);
    });

    test('가입 신청·탈퇴 목록도 같이 지킨다', () {
      final c = Store.tidyCouple({
        'pending': {'p1': {'uid': 'p1', 'name': 9}},
        'former': {'f1': '사람이 아님'},
      });
      expect(((c?['pending'] as Map)['p1'] as Map)['name'], '9');
      expect((c?['former'] as Map).containsKey('f1'), isFalse);
    });
  });

  test('회비 주인 옮기기가 한 건씩 조용히 실패하지 않는다', () {
    // 못 옮긴 기록은 그 달만 «미납»으로 남는데, 새 폰의 회원은 이유를 알 수 없다
    final src = File('lib/store.dart').readAsStringSync();
    final at = src.indexOf('migrateFeePayer');
    expect(at, greaterThan(0));
    final body = src.substring(at, at + 1200);
    expect(body.contains('미납으로 보입니다'), isTrue);
  });

  group('묶음·목록 «안쪽 값»', () {
    test('선납 달 목록에 이상한 값이 섞여도 회비 화면이 돈다', () {
      /* 낸 달 세기·미납 계산이 전부 이 목록을 훑는다 —
         `.cast<String>()` 을 훑는 순간 터지면 회비 화면이 통째로 안 뜬다. */
      AppState.i.couple = Store.tidyCouple(
          {'members': <String, dynamic>{}, 'fee': {'amount': 10000}});
      AppState.i.setItems(Store.tidy([
        {
          'id': 'l1', 'type': 'ledger', 'kind': 'in', 'amount': 20000,
          'payer': 'u1', 'feeMonths': ['2026-08', 5, null],
        },
      ]));
      expect(() => Logic.paidIn('u1', '2026-08'), returnsNormally);
      expect(Logic.paidIn('u1', '2026-08'), isTrue, reason: '멀쩡한 달은 살아 있어야 한다');
      expect(() => Logic.unpaidMonths('u1'), returnsNormally);
    });

    test('회비 «내는 날»이 글자여도 안 터진다', () {
      final c = Store.tidyCouple({'fee': {'amount': 10000, 'day': '5일'}});
      expect(() => (c?['fee'] as Map?)?['day'] as num?, returnsNormally);
    });

    test('모임 상징의 크기·회전이 숫자가 아니어도 홈이 뜬다', () {
      // 상징은 홈 맨 위에서 그린다 — 여기가 터지면 홈 화면이 통째로 안 뜬다
      final c = Store.tidyCouple({
        'emblem': {'kind': 'emoji', 'emoji': '🏸', 'size': '크게', 'rot': ['x']},
      });
      final em = (c?['emblem'] as Map?)?.cast<String, dynamic>();
      expect(() => (em?['size'] as num?)?.toDouble() ?? 1, returnsNormally);
      expect(() => (em?['rot'] as num?)?.toDouble() ?? 0, returnsNormally);
      // 글자로 된 숫자는 살려 둔다
      final c2 = Store.tidyCouple({'emblem': {'size': '1.5'}});
      expect(((c2?['emblem'] as Map)['size'] as num).toDouble(), 1.5);
    });

    test('참석·출석 «값»이 이상해도 세기가 돈다', () {
      final e = Store.tidy([{
        'id': 'e1', 'type': 'event', 'date': '2026-08-05',
        'rsvp': {'2026-08-05_u1': ['yes']},
        'attend': {'2026-08-05_u1': 'true'},
      }]).first;
      expect(() => Logic.rsvpCount(e, '2026-08-05', 'yes'), returnsNormally);
      expect(Logic.attended(e, '2026-08-05', 'u1'), isFalse,
          reason: '「true」라는 글자는 출석으로 세지 않는다');
    });
  });

  test('고치는 함수가 스스로 터지지 않는다 (좁은 종류의 묶음)', () {
    /* Dart에서는 `Map<String,String>` 도 `is Map<String,dynamic>` 검사를 통과한다(공변성).
       그것만 믿고 값을 넣으면 **막으려던 함수가 그 자리에서 터진다.** */
    expect(
        () => Store.tidyCouple(<String, dynamic>{
              'emblem': <String, String>{'size': '1.5', 'kind': 'emoji'},
              'fee': <String, String>{'day': '5일'},
              'members': <String, Map<String, String>>{
                'u1': {'uid': 'u1', 'name': '홍길동'},
              },
            }),
        returnsNormally);
  });

  group('알림·읽음·입력중 묶음의 «속값»', () {
    late Map<String, dynamic> c;
    setUp(() {
      c = Store.tidyCouple({
        'members': {'u1': {'uid': 'u1', 'name': '나', 'role': 'member'}},
        'push': {'u1': {'token': 5, 'mute': 3, 'at': 'x'}, 'u2': '묶음 아님'},
        'lastRead': {'u1': '어제', 'u2': 1700000000000},
        'lastSeen': {'u1': ['x']},
        'typing': {'u1': '치는 중'},
        'fee': {'amount': 10000},
      })!;
    });

    test('알림 범위를 읽어도 설정·홈 카드가 안 터진다', () {
      final p = (c['push'] as Map?)?['u1'] as Map?;
      expect(() => (p?['mute'] as String?) ?? 'all', returnsNormally);
      expect((c['push'] as Map).containsKey('u2'), isFalse, reason: '묶음이 아니면 사람으로 볼 수 없다');
    });

    test('읽음·접속·입력중은 «시각(숫자)»만 남는다', () {
      /* 채팅 말풍선 하나하나가 읽음을 세고, 글자를 칠 때마다 접속 시각을 본다 —
         숫자가 아닌 것이 하나만 섞여도 채팅 화면이 통째로 안 뜬다. */
      for (final k in ['lastRead', 'lastSeen', 'typing']) {
        final m = (c[k] as Map).cast<String, dynamic>();
        for (final v in m.values) {
          expect(v, isA<num>(), reason: '$k 에 숫자가 아닌 값이 남았다');
        }
      }
      expect((c['lastRead'] as Map)['u2'], 1700000000000, reason: '멀쩡한 값은 그대로');
      expect((c['lastRead'] as Map).containsKey('u1'), isFalse,
          reason: '언제 봤는지 알 수 없으면 «없는 것»으로 본다');
    });
  });

  group('시각(숫자) 칸 — 앱 곳곳이 읽는다', () {
    test('대화 시각이 글자면 정리하는 함수 «자신»이 터졌었다', () {
      /* 시각은 모든 기록에 공통이고 18곳이 숫자로 읽는다(정렬·날짜 구분선·안읽음 세기).
         게다가 「날짜 채우기」도 이 값을 읽어서, 여기가 글자면 정리가 통째로 멈춰 모든 화면이 죽는다. */
      expect(() => Store.tidy([{'id': 'p1', 'type': 'photo', 'createdAt': '어제'}]), returnsNormally);
      final m = Store.tidy([{'id': 'm1', 'type': 'msg', 'text': 'ㄱ', 'createdAt': '어제'}]).first;
      expect(() => ((m['createdAt'] as num?) ?? 0).toInt(), returnsNormally);
      // 글자로 된 숫자는 살려 둔다
      final ok = Store.tidy([{'id': 'm2', 'type': 'msg', 'createdAt': '1700000000000'}]).first;
      expect(ok['createdAt'], 1700000000000);
    });

    test('들어온 때가 글자여도 회비 화면과 회원 차례가 돈다', () {
      AppState.i.couple = Store.tidyCouple({
        'members': {
          'u1': {'uid': 'u1', 'name': '가', 'role': 'member', 'joinedAt': '작년'},
          'u2': {'uid': 'u2', 'name': '나', 'role': 'member', 'joinedAt': 1700000000000},
        },
        'fee': {'amount': 10000},
      });
      AppState.i.setItems([]);
      expect(() => Logic.unpaidMonths('u1'), returnsNormally);
      expect(() => AppState.i.memberList, returnsNormally);
      expect(AppState.i.memberList.length, 2);
    });

    test('총괄 목록의 방 한 칸이 망가져도 콘솔이 열린다', () {
      // 여기가 터지면 방을 만들지도 고치지도 지우지도 못한다
      final meta = Store.tidyCouple({
        'isMeta': true,
        'clubs': {'C1': {'title': 123, 'createdAt': '어제'}, 'C2': '묶음 아님'},
      });
      final clubs = (meta?['clubs'] as Map?)?.cast<String, dynamic>() ?? {};
      expect(clubs.containsKey('C2'), isFalse);
      expect(() => (clubs['C1'] as Map)['title'] as String?, returnsNormally);
      expect((clubs['C1'] as Map)['title'], '123');
    });
  });

  group('정리(tidy) 자체를 지키는 것 — 열 회차에 걸쳐 자란 자리다', () {
    test('소식이 올 때마다 다시 돌아도 값이 «그대로»', () {
      /* tidy 는 기록이 갈릴 때마다 «같은 기록에» 다시 돈다.
         돌 때마다 값이 조금씩 바뀌면 화면 숫자가 스스로 흘러간다. */
      final rows = <Map<String, dynamic>>[
        {'id': 'm1', 'type': 'msg', 'text': ['가'], 'createdAt': '1700000000000', 'reacts': ['x']},
        {'id': 'e1', 'type': 'event', 'date': '2026-8-5', 'until': '2026-9-1', 'rsvp': 'x'},
        {'id': 'l1', 'type': 'ledger', 'kind': 'in', 'amount': '30000', 'months': '3',
         'feeMonths': ['2026-08', 5], 'createdAt': 1700000000000},
        {'id': 'p1', 'type': 'photo', 'photoIds': ['a', 5, 'c'], 'createdAt': 1700000000000},
      ];
      Store.tidy(rows);
      final first = rows.map((x) => Map<String, dynamic>.from(x)).toList();
      for (var i = 0; i < 5; i++) {
        Store.tidy(rows);
      }
      for (var i = 0; i < rows.length; i++) {
        expect(rows[i].length, first[i].length, reason: '${rows[i]['id']} 의 칸 수가 달라졌다');
        rows[i].forEach((k, v) {
          final a = first[i][k];
          expect((a is List && v is List) ? '$a' == '$v' : a == v, isTrue,
              reason: '${rows[i]['id']}.$k 가 $a → $v 로 흘러갔다');
        });
      }
    });

    test('고치는 «차례»가 지켜진다', () {
      /* 뒤 단계가 읽는 값은 먼저 고쳐야 한다 (55·57회차):
         글자 → 날짜 0채우기 → 배열·묶음 → **시각** → 날짜 채우기 → 숫자·돈 */
      final src = File('lib/store.dart').readAsStringSync();
      final at = src.indexOf('static List<Map<String, dynamic>> tidy');
      expect(at, greaterThan(0));
      final body = src.substring(at, at + 3000);
      int pos(String s) => body.indexOf(s);
      expect(pos('_strFields'), greaterThan(0));
      expect(pos('_strFields'), lessThan(pos('_dateFields')), reason: '글자를 먼저 고쳐야 한다');
      // 인자가 늘어도(102회차의 asTime) 차례 자체는 그대로여야 한다 — 함수 이름까지만 본다
      expect(pos('_dateFields'), lessThan(pos("_num(x, 'createdAt'")));
      expect(pos("_num(x, 'createdAt'"), lessThan(pos("x['date'] == null")),
          reason: '날짜를 채울 때 시각을 읽으므로 시각을 먼저 고쳐야 한다');
      expect(pos("x['date'] == null"), lessThan(pos('_moneyFields')));
    });
  });
}
