import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'demo.dart';
import 'fee.dart';
import 'state.dart';
import 'store.dart';

/* 💳 스토어 결제 — 모임 이용권(월 정기결제) 사기·되살리기.

   ⚠️ **영수증은 서버가 확인한다.** 앱이 「샀다」고 `paidUntil` 을 적으면
      폰에서 고쳐 쓰거나 가짜 영수증으로 그대로 뚫린다.
      여기서는 스토어가 준 영수증을 서버 함수(`verifySub`)에 넘기기만 한다.

   ⚠️ **completePurchase 를 빠뜨리면 안 된다.** 안 하면 스토어가 그 거래를 «미완료»로 보고
      사흘 뒤 자동 환불한다 — 돈은 안 들어오고 이용권만 살아 있는 꼴이 된다.

   ⚠️ 결제는 «방장»만 한다. 회원은 살 것이 없다(`Fee.iPay`).
      회원에게 결제 창을 띄우면 애플이 「누가 무엇을 사는지 알 수 없다」고 되돌려보낸다. */
class Billing {
  Billing._();
  static final Billing i = Billing._();

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// 스토어를 쓸 수 있는가 (에뮬레이터·중국 롬 등에서는 없을 수 있다)
  bool available = false;

  /// 스토어에서 받아온 상품 (가격 글자를 «스토어가 준 대로» 보여줘야 한다 — 애플 규정)
  ProductDetails? product;

  /// 지금 결제 창이 떠 있는지 (두 번 눌러 두 번 결제되는 것을 막는다)
  final busy = ValueNotifier<bool>(false);

  /* ⏱️ 「잠시만요…」가 **영영 안 풀리는 길**을 막는다.

     `buy()` 는 스토어가 스트림으로 답을 줘야 잠금을 푼다. 그런데 답이 «안 오는» 길이 있다 —
     결제 창을 시스템 수준에서 닫았거나, 스토어 앱이 죽었거나, 기기가 절전으로 들어갔을 때.
     그러면 단추가 「잠시만요…」인 채 영영 잠겨 **앱을 껐다 켜야 다시 살 수 있다.**
     돈 내려는 사람을 막는 셈이라, 시간이 지나면 스스로 푼다. */
  static const _busyLimit = Duration(minutes: 3);
  Timer? _busyGuard;

  void _setBusy(bool v) {
    busy.value = v;
    _busyGuard?.cancel();
    _busyGuard = null;
    if (!v) return;
    _busyGuard = Timer(_busyLimit, () {
      if (!busy.value) return;
      busy.value = false;
      lastMessage.value = '결제 창이 닫힌 것 같아요 — 다시 눌러주세요';
    });
  }

  /// 복원으로 되살아난 것이 있었는지 (없으면 «없다»고 말해 줘야 한다)
  var _restoredCount = 0;

  /// 마지막으로 일어난 일 — 화면이 회원 말로 바꿔서 보여준다
  final lastMessage = ValueNotifier<String?>(null);

  bool _started = false;

  /// 앱 시작 때 한 번. 스토어 연결 + 밀린 거래 처리.
  Future<void> start() async {
    if (_started || Demo.on) return; // 체험 모드에서는 스토어를 부르지 않는다
    _started = true;
    try {
      available = await _iap.isAvailable();
    } catch (e) {
      available = false;
    }
    /* ⚠️ 못 붙었으면 **다시 해볼 수 있게 되돌린다.**
       앱을 켜는 그 순간에는 스토어가 아직 안 서 있을 수 있다(부팅 직후·계정 전환 중).
       여기서 굳혀 버리면 그 뒤로는 아무리 화면을 다시 열어도
       「이 기기에서는 스토어 결제를 쓸 수 없어요」만 나온다 — 살 길이 아예 막힌다. */
    if (!available) {
      _started = false;
      return;
    }
    /* 스트림은 «앱이 사는 동안» 계속 듣는다.
       결제 도중에 앱이 꺼졌다 켜져도 여기로 마저 들어온다 — 안 들으면 돈만 나간 채 끝난다. */
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => lastMessage.value = '스토어와 연결이 끊겼어요 — 잠시 후 다시 해주세요',
    );
    await loadProduct();
  }

  Future<void> loadProduct() async {
    try {
      final r = await _iap.queryProductDetails({Fee.productId});
      if (r.productDetails.isNotEmpty) product = r.productDetails.first;
    } catch (_) {/* 가격은 못 받아도 화면은 떠야 한다 — 예비 문구로 보여준다 */}
  }

  /// 스토어가 준 가격 글자. 못 받았으면 우리가 아는 값으로 (현지 통화로 적는다)
  String get priceText => product?.price ?? '월 ${Fee.wonText}';

  /// 이용권 사기 — **방장만.**
  Future<void> buy() async {
    if (busy.value) return;
    if (!available) {
      lastMessage.value = '이 기기에서는 스토어 결제를 쓸 수 없어요';
      return;
    }
    final p = product;
    if (p == null) {
      lastMessage.value = '상품 정보를 못 받아왔어요 — 잠시 후 다시 눌러주세요';
      await loadProduct();
      return;
    }
    _setBusy(true);
    try {
      // 정기결제는 buyNonConsumable 로 산다 (소모품이 아니다)
      await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
    } catch (e) {
      _setBusy(false);
      lastMessage.value = '결제 창을 열지 못했어요 — 잠시 후 다시 해주세요';
    }
  }

  /* 🔄 구매 복원 — 자동갱신 구독이면 **반드시** 있어야 한다(애플 3.1.1).
     폰을 바꾸거나 앱을 지웠다 깔았을 때 이미 낸 이용권을 되살리는 길이다. */
  Future<void> restore() async {
    /* 🔴 **결제가 도는 중에는 복원을 받지 않는다.**
       예전에는 여기에 아무 문지기가 없었다. 그래서
         결제하기 → 스토어 창이 뜸 → (답답해서) 구매 복원 → 4초 뒤 잠금이 «풀림»
         → 결제 단추가 다시 살아남 → 한 번 더 누름 → **두 번 결제된다.**
       잃는 것이 화면 한 칸이 아니라 돈이라, 여기서는 아예 막는다. */
    if (busy.value) {
      lastMessage.value = '결제를 처리하는 중이에요 — 잠시만 기다려주세요';
      return;
    }
    if (!available) {
      lastMessage.value = '이 기기에서는 스토어 결제를 쓸 수 없어요';
      return;
    }
    _setBusy(true);
    _restoredCount = 0;
    lastMessage.value = '이전 결제를 확인하는 중이에요…';
    try {
      await _iap.restorePurchases();
    } catch (_) {
      _setBusy(false);
      lastMessage.value = '복원하지 못했어요 — 스토어 계정을 확인해주세요';
      return;
    }
    /* ⚠️ 되살릴 것이 **없으면 스트림에 아무것도 안 온다.**
       그러면 「확인하는 중이에요…」인 채로 끝나 회원은 «된 건지 만 건지» 모른다.
       애플 심사에서도 「복원을 눌렀는데 아무 반응이 없다」로 걸리는 자리다.
       그래서 잠깐 기다렸다가, 아무것도 안 왔으면 «없다»고 말해 준다. */
    await Future<void>.delayed(_restoreWait);
    _setBusy(false);
    if (_restoredCount == 0) {
      lastMessage.value = '되살릴 결제가 없어요 — 스토어 계정이 맞는지 확인해주세요';
    }
  }

  /// 복원 결과가 스트림으로 들어올 때까지 기다리는 시간
  static const _restoreWait = Duration(seconds: 4);

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          lastMessage.value = '결제를 기다리는 중이에요…';
          continue;
        case PurchaseStatus.canceled:
          _setBusy(false);
          lastMessage.value = '결제를 취소했어요';
        case PurchaseStatus.error:
          _setBusy(false);
          // 스토어가 주는 영어 오류를 그대로 보여주지 않는다 (애플 지침·회원이 못 알아본다)
          lastMessage.value = '결제하지 못했어요 — 잠시 후 다시 해주세요';
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (p.status == PurchaseStatus.restored) _restoredCount++;
          await _verify(p);
      }
      /* ⚠️ 어떤 갈래로 끝나든 «완료»를 알려야 한다.
         안 알리면 스토어가 미완료 거래로 보고 되돌린다(안드로이드는 3일 뒤 자동 환불). */
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {/* 다음에 스트림으로 다시 들어온다 */}
      }
    }
  }

  /// 영수증을 **서버에** 넘겨 확인받는다. 서버가 `paidUntil` 을 적어 주면 구독이 열린다.
  Future<void> _verify(PurchaseDetails p) async {
    final code = AppState.i.code;
    if (code == null) {
      _setBusy(false);
      lastMessage.value = '모임에 들어간 뒤에 결제해주세요';
      return;
    }
    final ok = await Store.i.verifySubscription(
      code: code,
      productId: p.productID,
      token: p.verificationData.serverVerificationData,
      source: p.verificationData.source, // 'google_play' | 'app_store'
    );
    _setBusy(false);
    lastMessage.value = ok
        ? '이용권이 켜졌어요 — 고맙습니다 🏸'
        /* 돈은 나갔는데 못 켠 경우다. **다시 결제하라고 하면 두 번 결제된다** —
           복원으로 되살리게 안내한다(영수증은 스토어에 남아 있다). */
        : '결제는 됐는데 확인이 늦어지고 있어요 — 잠시 뒤 「구매 복원」을 눌러주세요';
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _busyGuard?.cancel(); // 안 끄면 앱이 꺼진 뒤에도 시계가 돈다
    _busyGuard = null;
    busy.value = false;
    _started = false;
    available = false; // 다시 켤 때 스토어부터 새로 묻는다
  }
}
