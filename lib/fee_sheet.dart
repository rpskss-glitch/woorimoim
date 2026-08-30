import 'logic.dart';
import 'state.dart';

/* 📋 「회비 납부 현황표」와 「지출 표」의 **셈**만 담는다 (그리는 일은 화면이 한다).

   총무가 종이에 그리던 그 표다 — 세로는 회원, 가로는 달, 칸은 ○(냈다)/빈칸(안 냈다).
   화면과 떼어 놓는 까닭: 이 셈이 틀리면 회원에게 «안 낸 사람»으로 잘못 알려지는데,
   위젯 안에 섞여 있으면 시험으로 잡을 수가 없다. */

/// 표의 칸 하나가 뜻하는 것.
enum FeeMark {
  paid,   // ○ 냈다
  unpaid, // − 안 냈다 («셈에 든 달인데» 안 낸 것)
  before, //   가입 전 — 안 낸 게 아니라 «셀 것이 없다»
}

class FeeSheet {
  /// 표에 쓸 달 목록 — 뒤에서부터 `months` 개, 「YYYY-MM」.
  static List<String> monthKeys(int months, {DateTime? now}) {
    final end = Logic.ymOf(now ?? DateTime.now());
    return [for (var i = months - 1; i >= 0; i--) Logic.ymKey(end - i)];
  }

  /* 📅 «고른 기간»의 달 목록 — 시작 달부터 끝 달까지.

     총무가 「작년 3월부터 8월까지」처럼 «지난 어느 때»를 봐야 할 일이 있다
     (결산·감사 때). 「최근 N개월」만으로는 그 자리를 못 본다.

     ⚠️ 거꾸로 골라도(끝이 시작보다 앞) 빈 표를 주지 않고 **뒤집어서** 돌려준다 —
        고른 사람은 실수했는지 모르고 「자료가 없다」고 오해한다.
     ⚠️ 너무 넓게 고르면 표가 수백 칸이 되어 화면이 멈칫한다 — 120달로 끊는다. */
  static List<String> monthRange(String fromYm, String toYm) {
    var a = Logic.ymOfKey(fromYm), b = Logic.ymOfKey(toYm);
    if (a == null || b == null) return monthKeys(6);
    if (b < a) { final t = a; a = b; b = t; }
    final n = (b - a + 1).clamp(1, 120);
    return [for (var i = 0; i < n; i++) Logic.ymKey(a + i)];
  }

  /// 그 사람이 그 달에 어땠는지.
  ///
  /// ⚠️ 가입 «전»을 미납으로 그리면 안 된다 — 새로 들어온 회원이 표에서
  ///    갑자기 「6달 밀린 사람」으로 보인다(실제로 종이 표에서 늘 나던 실수다).
  ///
  /// ⚠️ 반대로 **가입한 달을 미납에서 빼도 안 된다.** 2026-08-29 화면에서 잡은 버그:
  ///    가입한 달에 「가입」이라고만 찍으니, 그 달 회비를 안 낸 사람이 표에서
  ///    «안 낸 것»으로 안 보였다. 현황 화면은 같은 사람을 「2달 밀림」이라 하는데
  ///    표는 한 달만 밀린 것처럼 보여, **같은 앱의 두 화면이 서로 다른 말을 했다.**
  ///    가입한 달도 내야 하는 달이다 — 그래서 「가입」 표시를 없앴다.
  ///    언제 들어왔는지는 «처음 표시가 나오는 달»로 그대로 읽힌다.
  static FeeMark mark(String uid, String month, {int? joinedAt}) {
    final at = joinedAt ?? (AppState.i.members[uid] as Map?)?['joinedAt'] as num?;
    /* ⚠️ 들어온 때를 **모를 때**도 현황 화면과 «같은 말»을 해야 한다.

       모를 수 있다: 옛 판이 안 적었거나, 백업을 손으로 고쳤거나,
       적힌 값이 말이 안 되는 때라 다듬기가 뺐거나(폰 시계가 틀린 채로 가입).
       현황 화면(`Logic.unpaidMonths`)은 그때 «이번 달부터»만 센다.
       여기서만 «옛 달까지 다 안 낸 것»으로 그리면, 새로 든 회원이
       표에서 「열두 달 밀린 사람」이 되어 대화방에 그대로 올라간다.
       (2026-08-29: 회비 표와 현황이 다른 말을 하던 자리가 또 나왔다) */
    final joinedYm = at != null
        ? Logic.ymOf(DateTime.fromMillisecondsSinceEpoch(at.toInt()))
        : Logic.ymOf(DateTime.now());
    if (month.compareTo(Logic.ymKey(joinedYm)) < 0) return FeeMark.before;
    return Logic.paidIn(uid, month) ? FeeMark.paid : FeeMark.unpaid;
  }

  /* 칸에 찍을 글자 — 낸 달은 ○, 안 낸 달은 −, 가입 전은 빈칸.

     ⚠️ 미납을 «빈칸»으로 두면 안 된다 — 가입 전 칸과 글자가 똑같아져서
        표만 보고는 「아직 안 들어온 사람」인지 「안 낸 사람」인지 가릴 수가 없다.
        이 표는 대화방에 그림으로 올라간다. 색으로만 갈라 놓으면 흑백으로 인쇄하거나
        색을 잘 못 가리는 사람에게는 그 구별이 통째로 사라진다 — 그래서 «글자»로 가른다. */
  static String cell(FeeMark m) {
    switch (m) {
      case FeeMark.paid:
        return '○';
      case FeeMark.unpaid:
        return '−'; // 사이시옷 아닌 «빼기표»(U+2212) — 하이픈보다 굵어 표에서 잘 보인다
      case FeeMark.before:
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
