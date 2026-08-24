// 일정 화면의 «숫자»가 맞는지 (108회차).
//
// 참석 투표 수는 적힌 표를 모두 셌다 — 탈퇴한 회원의 옛 표와, 폰을 바꾼 회원의 옛 번호까지.
// 실측: 실제 2명인데 「참석 4」. 방장은 그 숫자로 코트를 잡는다.
// (출석 수는 `memberList` 로 세어 정확했다 — 같은 화면에서 규칙이 둘이었다)
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

const d = '2026-08-29';

Map<String, dynamic> setUpClub() {
  AppState.i.couple = Store.tidyCouple({
    'members': {
      'u1': {'uid': 'u1', 'name': '갑', 'role': 'owner'},
      'u2': {'uid': 'u2', 'name': '을', 'role': 'member'},
      'u3': {'uid': 'u3', 'name': '병', 'role': 'member'},
    },
    'former': {
      'u9': {'uid': 'u9', 'name': '정', 'leftAt': 1755000000000},
      'u1old': {'uid': 'u1old', 'name': '갑', 'movedTo': 'u1'},
    },
  });
  AppState.i.setItems(Store.tidy([
    {
      'id': 'e1',
      'type': 'event',
      'title': '정기모임',
      'date': d,
      'repeat': 'none',
      'rsvp': {
        '${d}_u1': 'yes', // 지금 회원
        '${d}_u2': 'yes', // 지금 회원
        '${d}_u9': 'yes', // 탈퇴한 사람
        '${d}_u1old': 'yes', // 갑이 폰 바꾸기 «전» 번호 — 그대로 세면 갑이 두 번
        '${d}_u3': 'no',
        '${d}_u9b': 'no', // 탈퇴한 사람의 불참
      },
      'attend': {'${d}_u1': true, '${d}_u2': true, '${d}_u9': true, '${d}_u1old': true},
      'createdAt': 1755800000000,
    }
  ]));
  return AppState.i.by('event').first;
}

void main() {
  test('참석·불참 표는 «지금 회원»만 센다', () {
    final e = setUpClub();
    expect(Logic.rsvpCount(e, d, 'yes'), 2, reason: '갑·을 — 탈퇴자와 갑의 옛 번호는 빼야 한다');
    expect(Logic.rsvpCount(e, d, 'no'), 1, reason: '병만');
  });

  test('출석 수와 «같은 규칙»을 쓴다', () {
    final e = setUpClub();
    final attendN =
        AppState.i.memberList.where((m) => Logic.attended(e, d, m['uid'] as String)).length;
    expect(attendN, 2);
    expect(Logic.rsvpCount(e, d, 'yes'), attendN,
        reason: '같은 사람들이 찍었는데 두 숫자가 다르면 방장이 헷갈린다');
  });

  test('자료는 그대로 둔다 — 세기만 안 한다', () {
    /* 탈퇴자의 옛 표를 «지우지» 않는다: 나중에 재가입하면 그대로 살아나고,
       무엇보다 남의 자료를 함부로 없애지 않는다. */
    final e = setUpClub();
    final rsvp = e['rsvp'] as Map;
    expect(rsvp['${d}_u9'], 'yes');
    expect(rsvp['${d}_u1old'], 'yes');
    expect(rsvp.length, 6);
  });

  test('다른 날짜의 표는 안 센다', () {
    final e = setUpClub();
    expect(Logic.rsvpCount(e, '2026-09-05', 'yes'), 0);
  });

  test('망가진 열쇠가 섞여 있어도 안 터진다', () {
    AppState.i.couple = Store.tidyCouple({
      'members': {'u1': {'uid': 'u1', 'name': '갑', 'role': 'owner'}}
    });
    AppState.i.setItems(Store.tidy([
      {
        'id': 'e2',
        'type': 'event',
        'date': d,
        'repeat': 'none',
        'rsvp': {'짧음': 'yes', '': 'yes', '${d}_': 'yes', '${d}_u1': 'yes'},
        'createdAt': 1755800000000,
      }
    ]));
    final e = AppState.i.by('event').first;
    expect(() => Logic.rsvpCount(e, d, 'yes'), returnsNormally);
    expect(Logic.rsvpCount(e, d, 'yes'), 1);
  });

  test('회차 목록 — 매주 모임이 날짜 순으로 펼쳐진다', () {
    final e = {'type': 'event', 'date': '2026-08-03', 'repeat': 'week'};
    final got = Logic.occurrences(e,
        from: DateTime(2026, 8, 3), to: DateTime(2026, 8, 31));
    expect(got, [
      '2026-08-03', '2026-08-10', '2026-08-17', '2026-08-24', '2026-08-31',
    ]);
  });

  test('회차 목록 — 끝나는 날을 넘지 않는다', () {
    final e = {'type': 'event', 'date': '2026-08-03', 'repeat': 'week', 'until': '2026-08-17'};
    expect(
      Logic.occurrences(e, from: DateTime(2026, 8, 3), to: DateTime(2026, 8, 31)),
      ['2026-08-03', '2026-08-10', '2026-08-17'],
    );
  });
}
