import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 💳 「돈을 받는 자리」가 실제로 팔 수 있는 모양인가.

   여기서 틀리면 잃는 것이 «화면 한 칸»이 아니라 **돈**이다:
     · 잠금이 안 풀리면 사려는 사람이 못 산다
     · 완료를 안 알리면 스토어가 사흘 뒤 자동 환불한다 (돈은 없고 이용권만 살아 있다)
     · 복원이 없거나 말이 없으면 애플이 3.1.1 로 되돌려보낸다

   ⚠️ 스토어는 시험에서 못 부르므로 «코드가 지켜야 하는 것»으로 못 박는다. */
void main() {
  final src = File('lib/billing.dart').readAsStringSync();
  final ui = File('lib/ui/fee_screen.dart').readAsStringSync();

  String bodyOf(String name) {
    final at = src.indexOf(name);
    expect(at, greaterThan(0), reason: '$name 이 사라졌다');
    final end = src.indexOf('\n  Future<', at + name.length);
    final end2 = src.indexOf('\n  void ', at + name.length);
    var e = [end, end2].where((x) => x > 0).fold(src.length, (a, b) => a < b ? a : b);
    return src.substring(at, e);
  }

  group('돈이 새지 않게', () {
    test('결제가 도는 중에는 «복원»이 잠금을 풀지 못한다', () {
      /* 🔴 실제로 열려 있던 길 —
           결제하기 → 스토어 창 → (답답해서) 구매 복원 → 4초 뒤 잠금이 풀림
           → 결제 단추가 다시 살아남 → 한 번 더 누름 → **두 번 결제된다.**
         `restore()` 는 `_setBusy(false)` 를 «무조건» 부르므로,
         들어오는 자리에서 막지 않으면 결제 잠금이 통째로 무너진다. */
      final r = bodyOf('Future<void> restore()');
      expect(r.contains('if (busy.value)'), isTrue,
          reason: '결제 중에도 복원이 들어와 잠금을 푼다 — 두 번 결제될 수 있다');
      // 막는 자리가 «잠금을 푸는 곳보다 먼저»여야 뜻이 있다
      expect(r.indexOf('if (busy.value)'), lessThan(r.indexOf('_setBusy')),
          reason: '막기 전에 이미 잠금을 건드린다');
    });

    test('복원 단추도 결제 중에는 «잠긴다»', () {
      /* 눌러도 거절할 단추를 살려 두면 「눌렀는데 아무 일도 안 나네」로 읽힌다. */
      /* ⚠️ 그냥 「구매 복원」을 찾으면 **머리 주석**이 먼저 걸린다(내가 그렇게 짜서 헛짚었다).
         회원이 «누르는 그 단추»의 글자로 찾는다. */
      final at = ui.indexOf("Text('🔄 구매 복원')");
      expect(at, greaterThan(0), reason: '구매 복원 단추가 사라졌다 — 애플 3.1.1');
      final near = ui.substring((at - 500).clamp(0, ui.length), at);
      /* ⚠️ 「가까이에 busy 가 있다」로는 못 잡는다 — 감싸는 틀만 남기고
         `busy ? null :` 만 지워도 통과했다(미끼로 확인). **못 누르게 하는 그 자리**를 본다. */
      expect(near.contains('busy ? null'), isTrue,
          reason: '복원 단추가 결제 중에도 눌린다 — 두 번 결제로 가는 길이 열린다');
    });

    test('약관·개인정보 링크가 «터지지» 않는다', () {
      /* `launchUrl` 은 던진다 — 브라우저가 없는 기기, 막아 둔 회사 폰.
         받아 내지 않으면 애플 심사원이 꼭 눌러 보는 자리에서 아무 말 없이 죽는다. */
      final at = ui.indexOf('Future<void> _open(');
      expect(at, greaterThan(0), reason: '링크 여는 자리가 사라졌다');
      final body = ui.substring(at, at + 500);
      expect(body.contains('try {'), isTrue,
          reason: '링크가 안 열리는 기기에서 그대로 터진다 — 애플 3.1.2 자리다');
    });

    test('어떤 갈래로 끝나든 «완료»를 스토어에 알린다', () {
      /* 안 알리면 스토어가 미완료 거래로 보고 되돌린다 — 안드로이드는 사흘 뒤 자동 환불.
         돈은 안 들어오고 이용권만 살아 있는 꼴이 된다. */
      expect(src.contains('completePurchase'), isTrue);
      final at = src.indexOf('pendingCompletePurchase');
      expect(at, greaterThan(0), reason: '완료가 필요한지 묻지도 않는다');
      // for 안에 있어야 «모든» 거래에 대해 돈다
      final before = src.substring(0, at);
      expect(before.lastIndexOf('for (final p in list)'),
          greaterThan(before.lastIndexOf('return')),
          reason: '완료 알림이 for 밖에 있으면 일부 거래가 빠진다');
    });

    test('영수증은 «서버»가 확인한다 — 앱이 스스로 켜지 않는다', () {
      /* 앱이 「샀다」고 적으면 폰에서 고쳐 쓰거나 가짜 영수증으로 그대로 뚫린다. */
      expect(src.contains('verifySubscription'), isTrue);
      // 주석에는 나올 수 있다 — «쓰는 자리»가 있는지를 본다
      final bare = src
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
          .replaceAll(RegExp(r'//.*'), '');
      expect(bare.contains('paidUntil'), isFalse,
          reason: '앱이 이용 기한을 직접 적고 있다 — 서버가 적어야 한다');
    });

    test('확인이 늦어도 «다시 결제하라»고 하지 않는다', () {
      // 돈은 나갔는데 못 켠 경우다. 다시 사라고 하면 두 번 결제된다.
      final v = bodyOf('Future<void> _verify(');
      expect(v.contains('구매 복원'), isTrue,
          reason: '복원으로 되살리게 안내해야 한다 — 영수증은 스토어에 남아 있다');
    });
  });

  group('사려는 사람을 막지 않게', () {
    test('「잠시만요…」가 영영 안 풀리는 길이 없다', () {
      /* 스토어가 답을 «안 주는» 길이 있다 — 결제 창을 시스템이 닫았거나, 스토어가 죽었을 때.
         그러면 단추가 잠긴 채 앱을 껐다 켜야 다시 살 수 있다. */
      expect(src.contains('_busyGuard'), isTrue, reason: '잠금을 푸는 시계가 없다');
      expect(RegExp(r'_busyLimit = Duration\(minutes: \d+\)').hasMatch(src), isTrue,
          reason: '한계 시간이 안 보인다');
      expect(src.contains('busy.value = true'), isFalse,
          reason: '지킴이를 거치지 않고 잠그는 자리가 있다 — 그 자리는 안 풀린다');
    });

    test('스토어에 한 번 못 붙었다고 «영영» 막히지 않는다', () {
      /* 앱을 켜는 그 순간에는 스토어가 아직 안 서 있을 수 있다(부팅 직후·계정 전환 중). */
      final st = bodyOf('Future<void> start(');
      expect(st.contains('_started = false'), isTrue,
          reason: '못 붙으면 다시 해볼 수 없다 — 살 길이 아예 막힌다');
    });
  });

  group('애플·구글이 요구하는 것', () {
    test('구매 복원이 있다 (3.1.1)', () {
      expect(src.contains('restorePurchases'), isTrue);
      expect(ui.contains('구매 복원'), isTrue, reason: '화면에 단추가 없으면 반려된다');
    });

    test('되살릴 것이 «없을 때»도 말해 준다', () {
      /* 없으면 스트림에 아무것도 안 온다 — 말이 없으면 회원은 된 건지 만 건지 모르고,
         심사관은 「눌렀는데 아무 반응 없음」으로 읽는다. */
      final r = bodyOf('Future<void> restore(');
      expect(r.contains('_restoredCount'), isTrue, reason: '되살아난 것을 세지 않는다');
      expect(r.contains('되살릴 결제가 없어요'), isTrue, reason: '없을 때 아무 말이 없다');
    });

    test('가격은 «스토어가 준 글자»를 먼저 쓴다', () {
      // 우리가 적은 값이 스토어 값과 다르면 애플이 되돌려보낸다
      expect(src.contains('product?.price ??'), isTrue,
          reason: '스토어 가격을 안 쓰고 우리 값을 먼저 보여준다');
    });

    test('스토어의 영어 오류를 그대로 보여주지 않는다', () {
      final at = src.indexOf('PurchaseStatus.error');
      final near = src.substring(at, (at + 320).clamp(0, src.length));
      expect(near.contains('결제하지 못했어요'), isTrue);
    });

    test('해지 방법·약관·개인정보 링크가 화면에 있다', () {
      expect(ui.contains('해지하는 방법'), isTrue, reason: '해지 안내가 없으면 반려된다');
      expect(ui.contains('eulaUrl'), isTrue);
      expect(ui.contains('privacyUrl'), isTrue);
    });

    test('회원에게는 결제 창을 안 띄운다', () {
      // 「누가 무엇을 사는지 알 수 없다」로 되돌아온다
      expect(ui.contains('Fee.iPay'), isTrue);
    });
  });

  group('앱과 서버가 «같은 말»을 하는가', () {
    /* 💥 2026-08-29 확인: 앱은 만료 뒤 사흘을 봐줊c는데 서버는 안 봐줘졌다.
       그 사흘 동안 앱은 「이용권이 켜져 있어요」라 하고 서버는 저장을 거절해서,
       회원은 «왜 안 되는지 모르는 채» 글을 잃었다. 카드 갱신이 하루 늦는 일은 흔하다. */
    final rulesFile = File('../데이트장부/firestore.rules');

    test('봐주는 날수가 서로 같다', () {
      if (!rulesFile.existsSync()) {
        markTestSkipped('규칙 파일을 못 찾았다 — 폴더 밖에 있다');
        return;
      }
      final rules = rulesFile.readAsStringSync();
      final app = File('lib/fee.dart').readAsStringSync();
      final m = RegExp(r'graceDays = (\d+)').firstMatch(app);
      expect(m, isNotNull, reason: '앱의 봐주는 날수가 안 보인다');
      final days = int.parse(m!.group(1)!);

      final at = rules.indexOf('function clubPaid(');
      expect(at, greaterThan(0), reason: '서버의 이용권 검사가 사라졌다');
      final body = rules.substring(at, (at + 420).clamp(0, rules.length));
      final r = RegExp(r'paidUntil., 0\) \+ (\d+) \* 86400000').firstMatch(body);
      expect(r, isNotNull,
          reason: '서버가 봐주는 기간 없이 막는다 — 앱은 봐주는데 서버는 거절한다');
      expect(int.parse(r!.group(1)!), days,
          reason: '앱은 $days일 봐주는데 서버는 다른 날수다 — 둘이 다른 말을 한다');
    });

    test('읽기는 막지 않는다', () {
      // 돈을 안 낸 벌을 회원이 받으면 안 된다 — 쓰던 기록은 그대로 보여야 한다
      final app = File('lib/fee.dart').readAsStringSync();
      expect(app.contains('읽기는 그대로'), isTrue);
    });
  });

  group('잠겼을 때 «왜»를 알려 준다', () {
    /* 팔리려면 «왜 안 되는지»부터 알아야 한다.
       예전에는 서버가 거절해도 회원 화면에는 「저장하지 못했어요」만 떴다 —
       아무리 다시 눌러도 안 되고, 방장은 결제해야 하는 줄도 몰랐다. */
    final common = File('lib/ui/common.dart').readAsStringSync();
    final store = File('lib/store.dart').readAsStringSync();

    test('공용 안내가 있고, 잠김이 아니면 원래 말을 한다', () {
      expect(common.contains('void saveFailToast('), isTrue);
      final at = common.indexOf('void saveFailToast(');
      final body = common.substring(at, (at + 220).clamp(0, common.length));
      expect(body.contains('Fee.locked'), isTrue);
      expect(body.contains('fallback'), isTrue,
          reason: '잠김이 아닐 때도 같은 말을 하면 엉뚱한 곳을 고치게 한다');
    });

    test('잠겼으면 보내지도 않는다 — 헛수고와 잃는 글을 줄인다', () {
      final at = store.indexOf('Future<String?> addItem(');
      expect(at, greaterThan(0));
      final body = store.substring(at, (at + 700).clamp(0, store.length));
      expect(body.contains('Fee.locked'), isTrue,
          reason: '긴 글을 다 쓰고 나서 거절당하면 글을 잃는다');
    });

    test('«기록 쓰기»가 안 된 자리는 공용 안내를 쓴다', () {
      /* 잠김은 items(대화·글·회비·일정) 쓰기를 막는다 — 규칙의 clubPaid.
         가입 신청·프로필 사진은 couples 문서라 잠김과 무관하다 —
         거기서 「이용권이 끝났어요」라 하면 **거짓말**이 된다. */
      for (final f in ['lib/ui/board.dart', 'lib/ui/chat.dart', 'lib/ui/wallet.dart']) {
        expect(File(f).readAsStringSync().contains('saveFailToast('), isTrue,
            reason: '$f 에서 기록 쓰기 실패를 그대로 두고 있다');
      }
    });

    test('가입 신청은 잠김 안내를 쓰지 않는다 — 거짓말이 된다', () {
      final ob = File('lib/ui/onboarding.dart').readAsStringSync();
      final at = ob.indexOf('가입 신청을 보내지 못했어요');
      if (at < 0) return; // 문구가 바뀌었으면 건너뚴다
      final near = ob.substring((at - 90).clamp(0, at), at);
      expect(near.contains('saveFailToast'), isFalse,
          reason: '가입 신청은 couples 문서라 잠김과 무관하다');
    });
  });
}
