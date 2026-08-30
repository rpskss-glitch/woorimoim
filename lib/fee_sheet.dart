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
  after,  //   탈퇴한 다음 달부터 — 마찬가지로 «셀 것이 없다»
  exempt, // 면 그 달만 면제해 준 사람 (다치거나, 오래 못 나오거나)
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
  /* 그 사람의 기록 — **지난 회원(former)도 찾는다.**
     ⚠️ `members` 만 보면 탈퇴한 사람은 들어온 때를 모르는 것으로 읽혀,
        표에서 밀린 달이 통째로 어긋난다(가입 전까지 미납으로 찍힌다). */
  static Map? rec(String uid) {
    final m = AppState.i.members[uid];
    if (m is Map) return m;
    final f = AppState.i.former[uid];
    return f is Map ? f : null;
  }

  /* 🙇 **그 달만 면제** — 다치거나, 오래 못 나오거나, 상을 당한 회원.
     달 이름을 그대로 담아 둔다(`members.<uid>.feeFree = ['2026-07', …]`).
     ⚠️ 「회비 0원」으로 바꾸는 방식은 안 된다 — 그 달 «모두»가 안 내게 된다. */
  static Set<String> exemptMonths(String uid) => Logic.feeFree(uid);

  static FeeMark mark(String uid, String month, {int? joinedAt}) {
    final one = rec(uid);
    final at = joinedAt ?? one?['joinedAt'] as num?;
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

    /* 🚪 나간 사람 — **나간 달까지는 내야 한다.** 「다음 달부터」 셈에서 뺀다.
       ⚠️ 나간 달까지 빼 버리면 그 달 회비가 조용히 사라져 잔액이 안 맞는다.
       ⚠️ 그렇다고 나간 뒤까지 미납으로 두면, 표에 「스무 달 밀린 사람」이 영영 남는다. */
    final left = one?['leftAt'] as num?;
    if (left != null && left > 0) {
      final leftYm =
          Logic.ymOf(DateTime.fromMillisecondsSinceEpoch(left.toInt()));
      if (month.compareTo(Logic.ymKey(leftYm)) > 0) return FeeMark.after;
    }

    // 낸 것이 먼저다 — 면제해 준 달에 이미 냈다면 «냈다»고 보여야 맞다
    if (Logic.paidIn(uid, month)) return FeeMark.paid;
    return exemptMonths(uid).contains(month) ? FeeMark.exempt : FeeMark.unpaid;
  }

  /* 📋 표에 실을 줄 —— 지금 회원 + **밀린 것이 남은 지난 회원**.

     ⚠️ 나갔다고 표에서 지우면 안 된다. 총무는 그 사람에게 받을 돈이 있는데
        표에서 사라지면 «받을 것이 없는 셈»이 되어 그대로 묻힌다(사장님 지적).
     ⚠️ 다 낸 지난 회원은 안 싣는다 — 몇 해 쌓이면 표가 지난 회원으로 가득 찬다.
     ⚠️ 기기를 옮긴 사람(`movedTo`)은 «같은 사람»이라 두 줄이 되면 안 된다. */
  static List<Map<String, dynamic>> rowMembers(List<String> months) {
    final rows = [...AppState.i.memberList];
    final have = rows.map((m) => m['uid']).toSet();
    final extra = <Map<String, dynamic>>[];
    AppState.i.former.forEach((key, v) {
      if (v is! Map) return;
      final uid = (v['uid'] is String && (v['uid'] as String).isNotEmpty)
          ? v['uid'] as String
          : key;
      if (have.contains(uid)) return;
      final to = v['movedTo'];
      if (to is String && to.isNotEmpty && to != uid) return; // 폰만 바꾼 사람
      if (!months.any((m) => mark(uid, m) == FeeMark.unpaid)) return;
      extra.add({...v.cast<String, dynamic>(), 'uid': uid, 'left': true});
    });
    // 늦게 나간 사람이 아래로 — 총무가 최근 것부터 찾는다
    extra.sort((a, b) =>
        ((a['leftAt'] as num?) ?? 0).compareTo((b['leftAt'] as num?) ?? 0));
    return [...rows, ...extra];
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
      case FeeMark.exempt:
        return '면';
      case FeeMark.before:
      case FeeMark.after:
        /* 둘 다 «낼 까닭이 없던 달»이라 글자는 같다 — 미납(−)과만 갈리면 된다.
           들어오기 전인지 나간 뒤인지는 칸 색으로 알려 준다. */
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
