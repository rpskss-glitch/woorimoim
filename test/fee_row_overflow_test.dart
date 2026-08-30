import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 📏 회비 현황 줄에 «가입비» 단추가 붙었다 — 이름 + [가입비] + [회비 등록].
   좁은 폰·큰 글자에서 두 단추가 겹쳐 오른쪽으로 넘치면, 넘친 단추는 못 누른다.
   회비를 다루는 사람(방장)으로 놓고, 가입비를 켜고, 밀린 회원까지 둔 채로 그린다. */
void main() {
  final st = AppState.i;

  void seed() {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'title': '앞산 배드민턴 수요일 저녁 초보반',
      'fee': {'amount': 20000, 'joinAmount': 30000},
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': 'owner',
               'joinedAt': DateTime(2026, 2, 1).millisecondsSinceEpoch},
        'u2': {'uid': 'u2', 'name': '박영진롱네임회원',
               'joinedAt': DateTime(2026, 2, 1).millisecondsSinceEpoch},
      },
    });
    st.setItems([]);
  }

  tearDown(() {
    st.setCouple({});
    st.setItems([]);
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('회비 줄(가입비+회비등록) — 360px · 글자 ${scale}배', (t) async {
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      t.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

      seed();
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: const Scaffold(body: WalletTab()),
      ));
      await t.pumpAndSettle();

      // 두 단추가 다 있어야 이 시험이 뜻이 있다 (미끼 확인)
      expect(find.text('가입비'), findsWidgets,
          reason: '가입비 단추가 안 떠서 이 시험은 아무것도 못 지킨다');
      expect(find.text('회비 등록'), findsWidgets);
      expect(t.takeException(), isNull,
          reason: '회비 줄이 360px·${scale}배에서 넘친다 — 넘친 단추는 못 누른다');
    });
  }
}
