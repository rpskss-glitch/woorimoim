import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/board.dart';
import 'package:woorimoim/ui/wallet.dart';

/* 🧾 지출 영수증 — 총무가 「이거 뭐였지」 할 때 찾는 자리.

   ⚠️ **사진첩과 따로 간다.** 모임 사진들 사이에 영수증이 섞이면
      사진첩이 지저분해지고, 영수증을 찾으려 사진첩을 뒤지게 된다.
      찾을 자리는 «그 지출 기록 옆»이다.

   ⚠️ 칸 이름은 웹앱과 **똑같아야** 한다(`rcptId`·`rcptThumb`) —
      웹이 이미 그 이름으로 적고 읽는다. 다르게 적으면 서로 못 본다. */
void main() {
  final st = AppState.i;

  void seed(List<Map<String, dynamic>> items) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple(Store.tidyCouple({
      'title': '앞산 배드민턴',
      'free': true,
      'fee': {'amount': 20000},
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': 'owner'},
      },
    }));
    st.setItems(Store.tidy(items));
  }

  Map<String, dynamic> spendWithReceipt() => <String, dynamic>{
        'id': 'l1', 'type': 'ledger', 'kind': 'out',
        'title': '셔틀콕 두 통', 'amount': 36000, 'cat': 'shuttle',
        'date': '2026-08-20', 'payer': Store.walletPayer,
        'rcptId': 'r_12345', 'rcptThumb': 'data:image/png;base64,AAAA',
      };

  group('사진첩과 따로 간다', () {
    test('영수증은 «기록 안»에 붙는다 — 사진첩 항목을 만들지 않는다', () {
      seed([spendWithReceipt()]);
      expect(st.by('photo'), isEmpty,
          reason: '영수증이 사진첩에 올라갔다 — 모임 사진들 사이에 섞인다');
      expect(st.by('ledger').length, 1);
      expect(st.by('ledger').first['rcptId'], 'r_12345');
    });

    testWidgets('사진첩 화면에 영수증이 안 보인다', (t) async {
      seed([spendWithReceipt()]);
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: const Scaffold(body: BoardTab()),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      // 사진첩은 photo 갈래만 그린다 — 영수증은 ledger 라 안 걸린다
      expect(st.by('photo'), isEmpty);
    });
  });

  group('다듬기가 영수증 칸을 버리지 않는다', () {
    test('«남길 칸 목록»에 들어 있다', () {
      /* 목록에 없으면 저장은 되는데 **다시 읽을 때 조용히 버려진다** —
         영수증이 붙은 줄 알았는데 다음에 열면 없다. */
      final out = Store.tidy([spendWithReceipt()]);
      expect(out.first['rcptId'], 'r_12345');
      expect(out.first['rcptThumb'], isNotNull);
    });

    test('이상한 값이 와도 안 터지고 글자로 고쳐진다', () {
      for (final w in <Object?>[0, true, 3.14, <Object?>[], <String, Object?>{}]) {
        final out = Store.tidy([
          {...spendWithReceipt(), 'rcptId': w, 'rcptThumb': w},
        ]);
        expect(out.first['rcptId'], isA<String?>(),
            reason: 'rcptId 가 $w 일 때 글자가 아니다 — 그리는 자리에서 터진다');
      }
    });
  });

  group('돈이 새지 않게', () {
    test('기록을 지울 때 영수증 원본도 함께 챙긴다', () {
      /* 한 군데라도 빠뜨리면 그 원본은 보관함에 영원히 남아 매달 요금이 나간다. */
      final ids = Store.photoIdsOf(spendWithReceipt());
      expect(ids, contains('r_12345'),
          reason: '지출을 지워도 영수증 원본이 남아 매달 요금이 나간다');
    });
  });

  group('코드가 지켜야 하는 것', () {
    final wallet = File('lib/ui/wallet.dart').readAsStringSync();

    test('저장에 실패하면 방금 올린 영수증을 도로 지운다', () {
      /* 안 지우면 아무 기록도 안 붙들고 있는 원본이 남는다 — 요금만 나간다. */
      final at = wallet.indexOf('Future<void> _save()');
      expect(at, greaterThan(0));
      final body = wallet.substring(at, (at + 2000).clamp(0, wallet.length));
      expect(body.contains('dropPhotos'), isTrue,
          reason: '저장 실패 때 올려 둔 영수증을 안 치운다');
    });

    test('영수증을 바꾸거나 뗄 때도 옛 원본을 치운다', () {
      expect(wallet.contains('void _removeReceipt()'), isTrue);
      final at = wallet.indexOf('void _removeReceipt()');
      final body = wallet.substring(at, (at + 500).clamp(0, wallet.length));
      expect(body.contains('dropPhotos'), isTrue,
          reason: '떼어 놓고 원본을 안 치우면 요금만 나간다');
    });

    test('웹앱과 «같은 칸 이름»을 쓴다', () {
      // 다르게 적으면 웹에서 영수증이 안 보이고, 웹이 적은 것도 앱에서 안 보인다
      expect(wallet.contains("'rcptId'"), isTrue);
      expect(wallet.contains("'rcptThumb'"), isTrue);
      final web = File('../앞산배드민턴/index.html');
      if (web.existsSync()) {
        final s = web.readAsStringSync();
        expect(s.contains('rcptId'), isTrue, reason: '웹앱에는 이 칸이 없다');
      }
    });

    test('영수증은 «있어도 되고 없어도 되는» 것이다', () {
      // 영수증이 없다고 저장을 막으면, 현금으로 산 것을 못 적는다
      final at = wallet.indexOf('Future<void> _save()');
      final body = wallet.substring(at, (at + 1200).clamp(0, wallet.length));
      expect(body.contains("if (_rcptId != null) 'rcptId'"), isTrue,
          reason: '영수증이 없을 때 빈 값을 적으면 웹이 «있는 것»으로 읽는다');
    });
  });

  group('화면이 터지지 않는다', () {
    testWidgets('영수증이 붙은 지출이 회비 화면에 뜬다', (t) async {
      seed([spendWithReceipt()]);
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: const Scaffold(body: WalletTab()),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('영수증 칸이 이상해도 안 터진다', (t) async {
      for (final w in <Object?>[null, '', 0, true, <Object?>[]]) {
        seed([
          {...spendWithReceipt(), 'rcptId': w, 'rcptThumb': w},
        ]);
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(MaterialApp(
          theme: buildTheme('sky'),
          home: const Scaffold(body: WalletTab()),
        ));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'rcptId 가 $w 일 때 터진다');
      }
    });
  });

  tearDown(() => st.setItems([]));
}
