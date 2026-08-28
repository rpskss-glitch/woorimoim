import 'logic.dart';
import 'state.dart';
import 'store.dart';

/* 💵 회비 «받은 것»을 적는 한 가지 길.

   ⚠️ 한 사람씩 받을 때(회비 화면)와 여러 사람을 한 번에 받을 때가 **같은 길**을 써야 한다.
      길이 둘로 갈리면 한쪽만 고쳐져서, 어느 날부터 「한 번에 받기」로 적은 회비만
      달이 어긋나거나 두 번 적히는 일이 생긴다(총무는 한참 뒤에야 알아챈다).

   ⚠️ 문서 이름을 `Store.feeDocId` 로 **못 박는 것이 유일한 막이**다 —
      총무 둘이 거의 동시에 눌러도 같은 달치가 두 번 적히지 않는다. 지우면 안 된다. */
class FeeBook {
  /// 한 사람에게서 `months` 달치를 받았다고 적는다.
  ///
  /// 돌려주는 값은 «무슨 일이 있었는지»다 — 화면은 이걸 그대로 사람 말로 옮긴다.
  /// 한 번에 받을 수 있는 달 수의 한계 — 손이 미끄러져 「120개월」을 적는 것을 막는다.
  /// (10년치를 정말 받는 모임은 없다. 넘치면 장부가 통째로 어긋난다)
  static const maxMonths = 36;

  static Future<FeeReceipt> receive({
    required String uid,
    required String name,
    required int months,
  }) async {
    /* 🔒 권한은 **여기서** 막는다 — 화면에서만 막으면 다른 화면이 이 함수를 부를 때
       조용히 뚫린다. 회비 기록은 회장·총무(방장 포함)만 남길 수 있다.
       (서버 규칙도 같은 잣대를 쓰므로, 평회원이 부르면 어차피 거절당한다 —
        그때 「기록하지 못했어요」라고만 하면 왜 안 되는지 알 수 없다) */
    if (!AppState.i.isTreasurer) {
      return FeeReceipt.fail(name, '회비 기록은 회장·총무만 할 수 있어요');
    }
    if (months <= 0) return FeeReceipt.fail(name, '개월 수를 1 이상으로 적어주세요');
    if (months > maxMonths) {
      return FeeReceipt.fail(name, '한 번에 $maxMonths개월까지만 받을 수 있어요');
    }

    final code = AppState.i.code;
    if (code == null) return FeeReceipt.fail(name, '모임을 찾지 못했어요');

    final amount = (AppState.i.couple?['fee'] as Map?)?['amount'];
    final won = (amount as num?)?.toInt() ?? 0;
    if (won <= 0) return FeeReceipt.fail(name, '월 회비 금액을 먼저 정해주세요');

    // 이미 낸 달은 건너뛰고 «메울 달»만 고른다
    final feeMonths = Logic.feeMonthsToFill(uid, months);
    if (feeMonths.isEmpty) return FeeReceipt.skip(name, '이미 앞으로까지 다 채워져 있어요');

    /* 💵 적는 돈은 «실제로 메운 달 수»로 센다.
       ⚠️ 요청한 달수를 그대로 곱하면 안 된다 — `feeMonthsToFill` 은 빈 달을 찾다가
          한계에 걸리면 **요청보다 적게** 돌려줄 수 있다. 그때 요청한 수로 곱하면
          «받지도 않은 달»의 돈이 통장에 더해져 잔액이 영영 안 맞는다. */
    final filled = feeMonths.length;
    final total = won * filled;

    final id = await Store.i.addItem(
      code,
      {
        'type': 'ledger',
        'kind': 'in',
        'title': filled == 1 ? '$name 회비' : '$name 회비 $filled개월',
        'amount': total,
        'payer': uid,
        'months': filled,
        'feeMonths': feeMonths,
        'date': ymd(DateTime.now()),
      },
      docId: Store.feeDocId(code, uid, feeMonths.first),
    );
    if (id == null) return FeeReceipt.fail(name, '기록하지 못했어요');
    return FeeReceipt.ok(name, total, feeMonths);
  }

  /// 여러 사람에게서 «같은 달수»를 한 번에 받았다고 적는다.
  ///
  /// ⚠️ 한 사람이 실패해도 **나머지는 계속 적는다.** 중간에 멈추면 총무는
  ///    어디까지 적혔는지 모른 채 다시 눌러야 하고, 그러면 앞사람 것이 두 번 적힌다
  ///    (문서 이름이 막아 주긴 하지만, 총무가 그것을 알 길이 없어 불안해진다).
  static Future<List<FeeReceipt>> receiveMany({
    required List<Map<String, dynamic>> members,
    required int months,
  }) async {
    final out = <FeeReceipt>[];
    for (final m in members) {
      final uid = m['uid'] as String?;
      if (uid == null) continue;
      out.add(await receive(
        uid: uid,
        name: (m['name'] as String?) ?? '회원',
        months: months,
      ));
    }
    return out;
  }
}

/// 회비 한 건을 적은 결과 — 「됐다·건너뛰었다·안 됐다」 셋뿐이다.
class FeeReceipt {
  final String name;
  final bool done;
  final bool skipped;
  final int won;
  final List<String> months;
  final String? why;

  const FeeReceipt._(this.name, this.done, this.skipped, this.won, this.months, this.why);

  factory FeeReceipt.ok(String name, int won, List<String> months) =>
      FeeReceipt._(name, true, false, won, months, null);
  factory FeeReceipt.skip(String name, String why) =>
      FeeReceipt._(name, false, true, 0, const [], why);
  factory FeeReceipt.fail(String name, String why) =>
      FeeReceipt._(name, false, false, 0, const [], why);
}
