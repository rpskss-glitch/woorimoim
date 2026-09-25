import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/shell.dart';

/* ⏳ 유예 띠를 «실제로 그려» 본다 — 체험 모드는 이용권이 없어 에뮬레이터로는 못 본다. */
void main() {
  final st = AppState.i;

  void club({required String myRole, required DateTime paidUntil}) {
    Demo.stop();
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'title': '시험 모임',
      'paidUntil': paidUntil.millisecondsSinceEpoch,
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': myRole},
        'o': {'uid': 'o', 'name': '방장', 'role': myRole == 'owner' ? 'member' : 'owner'},
      },
    });
    st.setItems([]);
  }

  Future<void> open(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: ShellScreen(onTouch: () {})));
    await t.pump(const Duration(milliseconds: 300));
  }

  testWidgets('방장 · 끝난 지 하루 → 「2일 뒤 모임이 잠겨요」 띠', (t) async {
    club(myRole: 'owner', paidUntil: DateTime.now().subtract(const Duration(days: 1)));
    await open(t);
    expect(find.textContaining('2일 뒤 모임이 잠겨요'), findsOneWidget);
  });

  testWidgets('회원에게는 유예 띠가 없다', (t) async {
    club(myRole: 'member', paidUntil: DateTime.now().subtract(const Duration(days: 1)));
    await open(t);
    expect(find.textContaining('모임이 잠겨요'), findsNothing);
  });

  testWidgets('기간 안이면 띠가 없다', (t) async {
    club(myRole: 'owner', paidUntil: DateTime.now().add(const Duration(days: 20)));
    await open(t);
    expect(find.textContaining('모임이 잠겨요'), findsNothing);
  });
}
