import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/album.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/fee_sheet_screen.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 🧯 망가진 기록(백업을 손으로 고쳤거나 옛 판·웹이 적은 값)이 섞여도 화면이 안 터진다. (2026-09-26 점검)
   · 회비 기록: 날짜가 글자·빈칸, 금액이 글자, 달 목록이 글자
   · 사진: 날짜가 글자
   · 대화: 시각이 없음, 글이 숫자 */
void main() {
  final st = AppState.i;
  setUp(() {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'free': true,
      'fee': {'amount': 20000},
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': 'owner', 'joinedAt': DateTime(2026, 1, 1).millisecondsSinceEpoch},
        'b': {'uid': 'b', 'name': '비', 'role': 'member'},
      },
    });
    st.setItems(Store.tidy([
      {'id': 'l1', 'type': 'ledger', 'kind': 'in', 'payer': 'b', 'amount': '이만원', 'date': '어제', 'feeMonths': '2026-09'},
      {'id': 'l2', 'type': 'ledger', 'kind': 'out', 'amount': 5000, 'date': ''},
      {'id': 'l3', 'type': 'ledger', 'amount': 3000},
      {'id': 'p1', 'type': 'photo', 'photoId': 'x', 'date': '언젠가', 'caption': 12345},
      {'id': 'm1', 'type': 'msg', 'by': 'b', 'text': 777},
      {'id': 'm2', 'type': 'msg', 'by': 'b', 'text': '정상', 'createdAt': 'nope'},
    ]));
  });

  final screens = <String, Widget Function()>{
    '회비': () => const WalletTab(),
    '사진첩': () => AlbumView(onChanged: () {}),
    '채팅': () => const ChatTab(active: true),
    '회비 표': () => const FeeSheetScreen(),
  };
  for (final e in screens.entries) {
    testWidgets('${e.key} 화면이 망가진 기록에도 뜬다', (t) async {
      await t.pumpWidget(MaterialApp(theme: buildTheme('sky'), home: Scaffold(body: e.value())));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: '${e.key} 이 망가진 기록에서 터진다');
    });
  }
}
