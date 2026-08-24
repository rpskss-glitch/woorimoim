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
    if (!available) return;
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
    busy.value = true;
    try {
      // 정기결제는 buyNonConsumable 로 산다 (소모품이 아니다)
      await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
    } catch (e) {
      busy.value = false;
      lastMessage.value = '결제 창을 열지 못했어요 — 잠시 후 다시 해주세요';
    }
  }

  /* 🔄 구매 복원 — 자동갱신 구독이면 **반드시** 있어야 한다(애플 3.1.1).
     폰을 바꾸거나 앱을 지웠다 깔았을 때 이미 낸 이용권을 되살리는 길이다. */
  Future<void> restore() async {
    if (!available) {
      lastMessage.value = '이 기기에서는 스토어 결제를 쓸 수 없어요';
      return;
    }
    busy.value = true;
    lastMessage.value = '이전 결제를 확인하는 중이에요…';
    try {
      await _iap.restorePurchases();
    } catch (_) {
      lastMessage.value = '복원하지 못했어요 — 스토어 계정을 확인해주세요';
    }
    busy.value = false;
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          lastMessage.value = '결제를 기다리는 중이에요…';
          continue;
        case PurchaseStatus.canceled:
          busy.value = false;
          lastMessage.value = '결제를 취소했어요';
        case PurchaseStatus.error:
          busy.value = false;
          // 스토어가 주는 영어 오류를 그대로 보여주지 않는다 (애플 지침·회원이 못 알아본다)
          lastMessage.value = '결제하지 못했어요 — 잠시 후 다시 해주세요';
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
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
      busy.value = false;
      lastMessage.value = '모임에 들어간 뒤에 결제해주세요';
      return;
    }
    final ok = await Store.i.verifySubscription(
      code: code,
      productId: p.productID,
      token: p.verificationData.serverVerificationData,
      source: p.verificationData.source, // 'google_play' | 'app_store'
    );
    busy.value = false;
    lastMessage.value = ok
        ? '이용권이 켜졌어요 — 고맙습니다 🏸'
        /* 돈은 나갔는데 못 켠 경우다. **다시 결제하라고 하면 두 번 결제된다** —
           복원으로 되살리게 안내한다(영수증은 스토어에 남아 있다). */
        : '결제는 됐는데 확인이 늦어지고 있어요 — 잠시 뒤 「구매 복원」을 눌러주세요';
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
