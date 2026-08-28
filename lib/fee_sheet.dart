import 'logic.dart';
import 'state.dart';

/* 📋 「회비 납부 현황표」와 「지출 표」의 **셈**만 담는다 (그리는 일은 화면이 한다).

   총무가 종이에 그리던 그 표다 — 세로는 회원, 가로는 달, 칸은 ○(냈다)/빈칸(안 냈다).
   화면과 떼어 놓는 까닭: 이 셈이 틀리면 회원에게 «안 낸 사람»으로 잘못 알려지는데,
   위젯 안에 섞여 있으면 시험으로 잡을 수가 없다. */

/// 표의 칸 하나가 뜻하는 것.
enum FeeMark {
  paid,   // ○ 냈다
  unpaid, //   안 냈다
  before, // 가입 전 — 안 낸 게 아니라 «셀 것이 없다»
  joined, // 가입한 달
}

class FeeSheet {
  /// 표에 쓸 달 목록 — 뒤에서부터 `months` 개, 「YYYY-MM」.
  static List<String> monthKeys(int months, {DateTime? now}) {
    final end = Logic.ymOf(now ?? DateTime.now());
    return [for (var i = months - 1; i >= 0; i--) Logic.ymKey(end - i)];
  }

  /// 그 사람이 그 달에 어땠는지.
  ///
  /// ⚠️ 가입 «전»을 미납으로 그리면 안 된다 — 새로 들어온 회원이 표에서
  ///    갑자기 「6달 밀린 사람」으로 보인다(실제로 종이 표에서 늘 나던 실수다).
  static FeeMark mark(String uid, String month, {int? joinedAt}) {
    final at = joinedAt ?? (AppState.i.members[uid] as Map?)?['joinedAt'] as num?;
    if (at != null) {
      final joined = Logic.ymKey(
          Logic.ymOf(DateTime.fromMillisecondsSinceEpoch(at.toInt())));
      if (month.compareTo(joined) < 0) return FeeMark.before;
      if (month == joined && !Logic.paidIn(uid, month)) return FeeMark.joined;
    }
    return Logic.paidIn(uid, month) ? FeeMark.paid : FeeMark.unpaid;
  }

  /// 칸에 찍을 글자 — 사진 속 표와 같게 ○ / 빈칸 / 「가입」.
  static String cell(FeeMark m) {
    switch (m) {
      case FeeMark.paid:
        return '○';
      case FeeMark.joined:
        return '가입';
      case FeeMark.before:
      case FeeMark.unpaid:
        return '';
    }
  }

  /// 한 달에 «몇 명이 냈는지» — 표 아래 합계 줄에 쓴다.
  static int paidCount(List<Map<String, dynamic>> members, String month) {
    var n = 0;
    for (final m in members) {
      if (mark(m['uid'] as String, month) == FeeMark.paid) n++;
    }
    return n;
  }

  /* 💸 지출 표 — 세로는 갈래(체육관·셔틀콕…), 가로는 달, 칸은 그 달 그 갈래로 나간 돈.

     ⚠️ 갈래가 없는 지출도 «기타»로 반드시 넣는다. 빼 버리면 표의 합계가
        통장 잔액과 안 맞아, 총무가 어디서 틀렸는지 찾느라 장부를 통째로 뒤지게 된다. */
  static Map<String, Map<String, int>> outByCat(List<String> months) {
    final want = months.toSet();
    final out = <String, Map<String, int>>{};
    for (final x in AppState.i.by('ledger')) {
      if (x['kind'] != 'out') continue;
      final d = x['date'] as String?;
      if (d == null || d.length < 7) continue;
      final ym = d.substring(0, 7);
      if (!want.contains(ym)) continue;
      final cat = Logic.catLabel(x['cat']) ?? '기타';
      final amt = (x['amount'] as num?)?.toInt() ?? 0;
      (out[cat] ??= {})[ym] = (out[cat]?[ym] ?? 0) + amt;
    }
    return out;
  }

  /// 그 달에 들어온 돈 (회비를 포함한 모든 수입).
  static Map<String, int> inByMonth(List<String> months) {
    final want = months.toSet();
    final out = {for (final m in months) m: 0};
    for (final x in AppState.i.by('ledger')) {
      if (x['kind'] != 'in') continue;
      final d = x['date'] as String?;
      if (d == null || d.length < 7) continue;
      final ym = d.substring(0, 7);
      if (!want.contains(ym)) continue;
      out[ym] = (out[ym] ?? 0) + ((x['amount'] as num?)?.toInt() ?? 0);
    }
    return out;
  }

  /// 「2026-07」 → 「7월」 (표 머리글은 짧아야 한 화면에 들어간다)
  static String monthLabel(String ym) {
    final p = ym.split('-');
    return p.length == 2 ? '${int.parse(p[1])}월' : ym;
  }
}
