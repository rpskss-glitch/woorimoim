import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/calendar.dart';

/* 🙆 일정 카드에 참석·불참을 «이름으로» 바로 보여 준다 (2026-08-31 추가).
   회원이 많고 이름이 길어도, 좁은 폰·큰 글자·다크모드에서 안 넘쳐야 한다.
   그리고 탈퇴자·폰 바꾼 옛 번호는 이름에 안 껴야 한다(세는 규칙과 같아야). */
void main() {
  final st = AppState.i;

  /* ⚠️ 날짜를 «박아 두면» 그 날이 지나는 순간 시험이 깨진다 —
     일정 탭은 «다가오는 모임»만 그리므로 지난 날짜는 아예 안 나온다
     (2026-09-06 에 겪었다: '2026-09-04' 로 박아 두었더니 이틀 뒤 넷이 깨졌다).
     늘 «사흘 뒤»로 만든다. */
  final _d = DateTime.now().add(const Duration(days: 3));
  final day = '${_d.year}-${_d.month.toString().padLeft(2, '0')}-'
      '${_d.day.toString().padLeft(2, '0')}';

  void seed() {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    final members = <String, dynamic>{
      'me': {'uid': 'me', 'name': '나', 'role': 'owner'},
    };
    // 이름이 긴 회원 여럿
    for (var i = 0; i < 12; i++) {
      members['u$i'] = {'uid': 'u$i', 'name': '김아무개$i번회원'};
    }
    final rsvp = <String, dynamic>{'${day}_me': 'yes'};
    for (var i = 0; i < 12; i++) {
      rsvp['${day}_u$i'] = i.isEven ? 'yes' : 'no';
    }
    // 탈퇴자·옛 번호 표는 이름에 안 껴야 한다
    rsvp['${day}_gone'] = 'yes';
    st.setCouple({
      'title': '앞산 배드민턴',
      'members': members,
      'events': {
        'e1': {
          'id': 'e1', 'type': 'event', 'title': '대회 연습',
          'date': day, 'time': '10:00', 'place': '앞산 체육관',
          'rsvp': rsvp,
        },
      },
    });
    st.setItems([
      {'id': 'e1', 'type': 'event', 'title': '대회 연습', 'date': day,
       'time': '10:00', 'place': '앞산 체육관', 'rsvp': rsvp},
    ]);
  }

  tearDown(() {
    st.setCouple({});
    st.setItems([]);
  });

  test('rsvpNames 는 지금 회원만 — 탈퇴자·옛 번호는 안 낀다', () {
    seed();
    final e = st.items.first;
    final yes = Logic.rsvpNames(e, day, 'yes');
    expect(yes.contains('나'), isTrue);
    expect(yes.any((n) => n.contains('김아무개')), isTrue);
    // 'gone'은 members 에 없으니 빠져야
    expect(yes.length, 7, reason: '나 + 짝수 6명 = 7 (탈퇴자 gone 제외)');
    final no = Logic.rsvpNames(e, day, 'no');
    expect(no.length, 6);
  });

  for (final scale in [1.0, 2.0]) {
    for (final dark in [false, true]) {
      testWidgets('일정 참석/불참 이름 — 360px·${scale}배·${dark ? "다크" : "밝음"} 안 넘침',
          (t) async {
        t.view.physicalSize = const Size(360, 800);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

        seed();
        await t.pumpWidget(MaterialApp(
          theme: buildTheme('sky', dark: dark),
          home: const Scaffold(body: CalendarTab()),
        ));
        await t.pumpAndSettle();

        expect(find.textContaining('참석'), findsWidgets);
        expect(t.takeException(), isNull,
            reason: '일정 참석자 이름이 360px·${scale}배에서 넘친다');
      });
    }
  }
}
