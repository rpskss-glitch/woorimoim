import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/board.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/shell.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 🔒 「이용권이 끊긴 모임」을 실제로 만들어 놓고 화면을 눌러 본다.

   팔리려면 이 상태가 «말이 되어야» 한다 —
     · 읽기는 그대로 된다 (돈 안 낸 벌을 회원이 받으면 안 된다)
     · 왜 막혔는지 보인다 (모르면 결제도 안 한다)
     · 결제하러 갈 길이 있다 */
void main() {
  final st = AppState.i;

  /// 이용권이 «끊긴» 모임을 세운다 (유예 사흘도 지난 상태)
  void seedLocked({String role = 'owner'}) {
    final longAgo = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'title': '앞산 배드민턴',
      'paidUntil': longAgo,
      'fee': {'amount': 20000},
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': role},
        'u2': {'uid': 'u2', 'name': '남', 'role': 'member'},
      },
    });
    st.setItems([
      {'id': 'm1', 'type': 'msg', 'by': 'u2', 'text': '안녕하세요', 'createdAt': 1},
      {'id': 'd1', 'type': 'diary', 'by': 'u2', 'title': '공지', 'text': '내용'},
    ]);
  }

  Widget host(Widget child) =>
      MaterialApp(theme: buildTheme('sky'), home: child);

  test('사흘이 지나면 잠긴다', () {
    seedLocked();
    expect(Fee.locked, isTrue, reason: '유예가 지났는데 안 잠긴다');
  });

  test('유예 안에서는 «아직» 안 잠긴다', () {
    final justNow = DateTime.now()
        .subtract(const Duration(days: 1))
        .millisecondsSinceEpoch;
    st.setCouple({
      'paidUntil': justNow,
      'members': {'me': {'uid': 'me', 'name': '나', 'role': 'owner'}},
    });
    expect(Fee.locked, isFalse,
        reason: '카드 갱신이 하루 늦었다고 곧바로 잠그면 억울하다');
  });

  testWidgets('잠겨도 «읽기»는 그대로 된다', (t) async {
    seedLocked();
    await t.pumpWidget(host(Scaffold(body: const ChatTab(active: true))));
    await t.pumpAndSettle();
    expect(find.textContaining('안녕하세요'), findsWidgets,
        reason: '돈 안 낸 벌을 회원이 받으면 안 된다 — 쓰던 대화는 그대로 보여야 한다');
    expect(t.takeException(), isNull);
  });

  testWidgets('잠기면 «왜»가 화면에 보인다', (t) async {
    seedLocked();
    await t.pumpWidget(host(ShellScreen(onTouch: () {})));
    await t.pumpAndSettle();
    expect(find.textContaining('이용권'), findsWidgets,
        reason: '왜 막혔는지 안 보이면 결제할 생각도 못 한다');
    expect(t.takeException(), isNull);
  });

  testWidgets('방장에게는 «결제하면 된다»고, 회원에게는 «방장이 낸다»고 말한다', (t) async {
    seedLocked(role: 'owner');
    expect(Fee.lockedLine, contains('결제하면'));
    seedLocked(role: 'member');
    expect(Fee.lockedLine, contains('방장이'),
        reason: '회원에게 결제하라고 하면 애플이 되돌려보낸다');
    expect(Fee.lockedLine, contains('읽기는'),
        reason: '읽기는 된다는 것을 알려야 «앱이 죽었다»고 오해하지 않는다');
  });

  testWidgets('잠긴 채로 화면들을 눌러도 안 터진다', (t) async {
    seedLocked();
    for (final make in <Widget Function()>[
      () => const BoardTab(),
      () => const WalletTab(),
      () => const ChatTab(active: true),
    ]) {
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(host(Scaffold(body: make())));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '잠긴 화면을 그리다 터진다');
    }
  });

  tearDown(() => st.setItems([]));
}
