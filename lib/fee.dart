import 'demo.dart';
import 'state.dart';

/* 💳 모임 이용권 — **모임을 만든 사람(방장)이** 그 모임의 월 이용료를 낸다. 회원은 한 푼도 안 낸다.

   판정은 모임 문서의 두 칸으로 한다:
     · `free: true`   — 이용료 면제. 총괄이 만든 방, 그리고 사장님이 콘솔에서 면제해 준 방.
                        (앞산 배드민턴은 여기 해당 — 평생 무료)
     · `paidUntil`    — 결제가 끝나는 시각(ms). **서버가 영수증을 확인하고 적는다.**
                        앱이 직접 적으면 안 된다 — 폰에서 고쳐 쓰면 그대로 뚫린다.

   ⚠️ 화면에서 막는 것은 «안내»일 뿐이다. 서버 규칙도 같은 두 칸을 보고 막아야 진짜 잠금이다.
   ⚠️ 잠기면 **읽기는 그대로** 된다 — 회원이 쓰던 대화·회비 기록을 못 보게 하면
      돈을 안 낸 벌을 «회원»이 받는 꼴이 된다. 새로 쓰는 것만 막는다. */
class Fee {
  Fee._();

  /// 월 이용료 (원)
  static const won = 48000;
  static const wonText = '48,000원';

  /// 스토어 구독 상품 번호 (안드로이드·아이폰 같은 이름으로 만든다)
  static const productId = 'club_month_48000';

  /// 결제가 끊긴 뒤 봐주는 기간 — 카드 갱신·스토어 지연 때문에 곧바로 잠그면 억울하다
  static const graceDays = 3;

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  /// 그 모임이 지금 쓸 수 있는 상태인가 (면제이거나, 이용권이 살아 있거나)
  static bool ok([Map<String, dynamic>? club]) {
    // 체험 모드는 언제나 열려 있다 — 둘러보는 사람에게 결제를 물을 수 없다
    if (Demo.on) return true;
    final c = club ?? AppState.i.couple;
    if (c == null) return true; // 아직 안 왔다 — 모르는 것을 잠그지 않는다
    if (c['free'] == true) return true;
    final until = c['paidUntil'];
    final ms = until is num ? until.toInt() : 0;
    return ms + graceDays * 86400000 > _now;
  }

  /// 잠겨 있는가 (쓰기를 막아야 하는가)
  static bool get locked => !ok();

  /// 이용권이 끝나는 날 (없으면 null)
  static DateTime? until([Map<String, dynamic>? club]) {
    final c = club ?? AppState.i.couple;
    final v = c?['paidUntil'];
    final ms = v is num ? v.toInt() : 0;
    return ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// 이 사람이 결제할 사람인가 — **방장만** 낸다
  static bool get iPay => AppState.i.isOwner;

  /// 면제된 모임인가 (「이용권」 안내를 아예 안 보여주려는 자리에서 쓴다)
  static bool get exempt =>
      AppState.i.couple?['free'] == true || Demo.on;

  /// 잠겼을 때 회원에게 보여줄 한 줄
  static String get lockedLine => iPay
      ? '이용권이 끝났어요 — 결제하면 바로 다시 쓸 수 있어요'
      : '방장이 이용권을 결제하면 다시 쓸 수 있어요 (읽기는 그대로 돼요)';
}
