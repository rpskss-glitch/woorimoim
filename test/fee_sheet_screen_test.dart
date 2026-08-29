import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/fee_sheet_screen.dart';

/* 📋 회비 표를 «실제로 그려» 본다.

   셈 시험(fee_sheet_test)은 값이 맞는지만 본다. 이 시험은 그 값이 **화면에 나오는지**를 본다.
   2026-08-29 에뮬에서 잡은 버그가 정확히 그 틈에 있었다 —
   셈은 「안 냈다」인데 화면에는 아무것도 안 찍혀, 가입 전 칸과 구별이 안 됐다. */
void main() {
  final st = AppState.i;

  Future<void> open(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(
      theme: buildTheme(null),
      home: const FeeSheetScreen(),
    ));
    await t.pumpAndSettle();
  }

  setUp(() {
    // 7월에 들어온 회원 둘 — 하나는 7월치를 냈고, 하나는 안 냈다
    final joined = DateTime(2026, 7, 1).millisecondsSinceEpoch;
    st.profile = {'code': 'C', 'slot': 'u1', 'name': '김총무'};
    st.setCouple({
      'fee': {'amount': 20000},
      'members': {
        'u1': {'uid': 'u1', 'name': '김총무', 'role': 'owner', 'joinedAt': joined},
        'u2': {'uid': 'u2', 'name': '박회원', 'role': 'member', 'joinedAt': joined},
      },
    });
    st.setItems([
      {
        'id': 'a',
        'type': 'ledger',
        'kind': 'in',
        'payer': 'u1',
        'amount': 20000,
        'date': '2026-07-05',
      },
    ]);
  });

  testWidgets('낸 칸엔 ○, 안 낸 칸엔 −가 «찍힌다»', (t) async {
    await open(t);
    expect(find.text('○'), findsWidgets, reason: '낸 달이 표에 안 보인다');
    expect(find.text('−'), findsWidgets,
        reason: '안 낸 달이 표에서 빈칸이다 — 총무가 「누가 안 냈나」를 읽을 수가 없다');
  });

  testWidgets('회원 이름이 표에 나온다', (t) async {
    await open(t);
    expect(find.textContaining('김총무'), findsWidgets);
    expect(find.textContaining('박회원'), findsWidgets);
  });

  testWidgets('「가입」 글자는 이제 안 쓴다 — 미납을 덮었다', (t) async {
    /* 가입한 달도 내야 하는 달이다. 「가입」으로 덮으면 그 달 미납이 안 보이고,
       현황 화면(「2달 밀림」)과 표가 서로 다른 말을 하게 된다. */
    await open(t);
    expect(find.text('가입'), findsNothing,
        reason: '「가입」이 그 달 미납을 덮고 있다');
  });

  testWidgets('표를 그리다 터지지 않는다', (t) async {
    await open(t);
    expect(t.takeException(), isNull);
  });
}
