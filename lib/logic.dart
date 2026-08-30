import 'config.dart';
import 'state.dart';
import 'store.dart';

/// 일정·출석·회비 계산 — 웹앱(index.html)의 Cal/Wallet 계산부를 그대로 옮긴 것.
/// 여기 규칙이 웹과 어긋나면 같은 모임인데 숫자가 다르게 보이므로 조심해서 고쳐야 한다.
class Logic {
  /// 참석 투표·출석은 「날짜_uid」 키로 적는다 — 반복 모임은 회차마다 따로 세야 하기 때문.
  static String rkey(String date, String uid) => '${date}_$uid';

  /* ── 폰을 바꾼 사람 잇기 ────────────────────────────────────────
     폰을 바꾸면 **번호(uid)가 새로 생긴다.** 옛 자리는 `former[옛번호].movedTo = 새번호` 로 남는다.
     그런데 출석·회비는 그 «번호»를 열쇠로 적혀 있어서, 잇지 않으면 바꾼 순간
     **그동안 쌓은 것이 전부 사라진다.**
     2026-08-23 실측(평회원, 이번 달 네 번 나오고 회비도 낸 사람):
       출석 4 → **0** · 배지 2개 → **0** · 이번 달 순위 → **사라짐** · 낸 회비 → **미납**
     ⚠️ 자료를 «옮기는» 길(`Store.migrateFeePayer`)은 회비만 건드리고, 게다가 서버 규칙이
        회비 기록 수정에 **돈 권한**을 요구해서 **평회원이 바꾸면 통째로 거절된다**(조용히).
        그래서 옮기는 대신 **읽을 때 이어 본다** — 쓰기도 권한도 필요 없고, 이미 바꾼 사람도 되살아난다. */
  static Map? _movedSrc;
  static Map<String, String>? _movedIdx;

  /// 「옛 번호 → 지금 번호」 (여러 번 바꿨으면 사슬 끝까지)
  static Map<String, String> movedMap() {
    /* ⚠️ `AppState.i.former` 는 `.cast<...>()` 라 **부를 때마다 새 객체**다 —
       그걸로 «같은 것인가»를 물으면 언제나 아니라서 표를 매번 새로 만들고,
       이 표를 열쇠로 쓰는 출석·회비 표까지 **캐시가 한 번도 안 맞는다.**
       (2026-08-23: 「출석 셈은 기록이 그대로면 다시 세지 않는다」 시험이 잡아 줬다)
       그래서 «원본 묶음»을 그대로 견준다. */
    final raw = AppState.i.couple?['former'];
    final cached = _movedIdx;
    if (cached != null && identical(_movedSrc, raw)) return cached;
    final former = raw is Map ? raw : const {};
    final one = <String, String>{};
    former.forEach((old, v) {
      final to = (v is Map) ? v['movedTo'] : null;
      if (to is String && to.isNotEmpty && to != old) one['$old'] = to;
    });
    final out = <String, String>{};
    for (final k in one.keys) {
      var cur = one[k]!;
      // 사슬을 따라가되 끝없이 돌지 않게 한계를 둔다 (자료가 고리를 이룰 수도 있다)
      for (var i = 0; i < 20 && one.containsKey(cur); i++) {
        final next = one[cur]!;
        if (next == cur) break;
        cur = next;
      }
      out[k] = cur;
    }
    _movedSrc = raw is Map ? raw : null;
    _movedIdx = out;
    return out;
  }

  /// 그 번호의 «지금» 주인 번호
  static String liveUid(String uid) => movedMap()[uid] ?? uid;

  /// 지금 번호가 예전에 쓰던 번호들
  static List<String> pastUids(String uid) =>
      movedMap().entries.where((e) => e.value == uid).map((e) => e.key).toList();

  /* ❤️ 말풍선에 보여 줄 반응 — **폰을 바꾸기 «전» 번호도 같은 사람**으로 본다.

     출석·회비·참석 투표·읽음은 모두 옛 번호를 이어 주는데 **반응만 빠져 있었다.**
     그래서 폰을 바꾼 회원이 옛날에 누른 좋아요를 다시 누르면
       · 하트가 **둘**로 보이고(한 사람인데)
       · 옛 하트는 «내 것»으로 안 잡혀 **영영 뗄 수 없었다.**
     읽는 쪽에서 고친다 — 옛 기록이 그대로 있어도 바르게 보인다. */
  static String reactEmojis(Object? raw) {
    final m = asMap(raw);
    final seen = <String>{};
    final out = StringBuffer();
    for (final e in m.entries) {
      final v = e.value;
      if (v is! String || v.isEmpty) continue;
      if (!seen.add(liveUid(e.key))) continue; // 같은 사람은 한 번만
      out.write(v);
    }
    return out.toString();
  }

  /// 이 반응 묶음에 «내가» 남긴 것들의 번호 (폰 바꾸기 전 번호까지).
  /// 뗄 때는 **전부** 떼야 옛 하트가 남지 않는다.
  static List<String> myReactKeys(Map<String, dynamic> reacts, String myUid) => [
        for (final k in [myUid, ...pastUids(myUid)])
          if (reacts[k] != null) k
      ];

  /* 👑 방장이 나가면 «누가 다음 방장인가».

     방장이 폰을 잃거나 모임을 떠나면 방이 «주인 없는 채»로 남았다 —
     예전에는 방장이 직접 넘겨주기 전에는 탈퇴도 못 하게 막았다.
     이제 탈퇴하면 **자동으로** 다음 사람에게 넘어간다.

     차례(사장님이 정한 규칙 그대로):
       ① 직책 「회장」 → ② 「총무」 → ③ 「부회장」 → ④ 나머지 회원
       같은 칸에 여럿이면 **먼저 가입한 사람**(joinedAt 이 작은 사람).
     ⚠️ 가입일이 없는 옛 회원은 «맨 뒤»로 본다 — 있는 사람이 먼저다.
     ⚠️ 운영진(role: admin)이라도 직책이 없으면 ④다 — 직책 순서가 우선이다. */
  static String? nextOwnerUid(Map<String, dynamic> members, String leavingUid) {
    int tier(Map m) {
      switch (m['title']) {
        case '회장':
          return 0;
        case '총무':
          return 1;
        case '부회장':
          return 2;
        default:
          return 3;
      }
    }

    final rows = members.entries
        .where((e) =>
            e.key != leavingUid &&
            e.value is Map &&
            ((e.value as Map)['uid'] as String?)?.isNotEmpty == true)
        .map((e) => MapEntry(e.key, (e.value as Map).cast<String, dynamic>()))
        .toList()
      ..sort((a, b) {
        final t = tier(a.value).compareTo(tier(b.value));
        if (t != 0) return t;
        final ja = (a.value['joinedAt'] as num?)?.toInt() ?? 1 << 62;
        final jb = (b.value['joinedAt'] as num?)?.toInt() ?? 1 << 62;
        final j = ja.compareTo(jb);
        if (j != 0) return j;
        return a.key.compareTo(b.key); // 끝까지 같으면 번호로 — 차례가 흔들리지 않게
      });
    return rows.isEmpty ? null : rows.first.key;
  }

  /* 🎂 생년월일을 «숫자만»으로 읽는다 — 6자리(800125) 또는 8자리(19800125).

     왜 필요한가
       가입 화면의 생년월일이 «달력에서 고르기»뿐이었다. 1960~80년대생이 많은데,
       달력으로 수십 년을 거슬러 올라가려면 **수십 번을 눌러야** 했다.
       6자리는 누구나 아는 주민번호 앞자리 그대로라 설명이 필요 없다.

     6자리의 연도는 이렇게 정한다:
       뒤 두 자리가 «올해 두 자리»보다 크면 1900년대, 아니면 2000년대.
       (올해 26 기준: 80→1980 · 05→2005 · 27→1927)
     ⚠️ 1920~1926년생은 6자리로 2020년대로 읽힌다 — 그분들은 8자리나 달력으로.
        (앱의 생년월일 허용 범위가 1920~2020이라 2021+는 어차피 거른다)

     돌려주는 값: 진짜 있는 날짜(1920-01-01~2020-12-31)면 그 날, 아니면 null. */
  static DateTime? parseBirthDigits(String raw) {
    final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    int y, m, day;
    if (d.length == 6) {
      final yy = int.parse(d.substring(0, 2));
      y = yy > DateTime.now().year % 100 ? 1900 + yy : 2000 + yy;
      m = int.parse(d.substring(2, 4));
      day = int.parse(d.substring(4, 6));
    } else if (d.length == 8) {
      y = int.parse(d.substring(0, 4));
      m = int.parse(d.substring(4, 6));
      day = int.parse(d.substring(6, 8));
    } else {
      return null;
    }
    if (y < 1920 || y > 2020) return null;
    final dt = DateTime(y, m, day);
    // DateTime 은 2월 30일을 «3월 2일로 굴려» 만든다 — 되짚어 같아야 진짜 날짜다
    if (dt.year != y || dt.month != m || dt.day != day) return null;
    return dt;
  }

  /// 그 번호가 «나»인지 — 폰을 바꾸기 전 번호도 나다.
  ///
  /// ⚠️ **보여 주는 데만 쓴다.** 지우기 같은 «권한»에 쓰면 안 된다:
  /// 서버는 글에 적힌 번호(`by`)만 보고 판단하므로, 화면에만 단추를 띄우면
  /// 눌러도 거절당하는 **헛단추**가 된다. (권한까지 이어 주려면 서버 규칙을 고쳐야 한다)
  static bool isMe(String? uid, String myUid) {
    if (uid == null || uid.isEmpty) return false;
    return uid == myUid || liveUid(uid) == liveUid(myUid);
  }

  /// 맵이어야 할 자리에 딴 값이 들어 있어도 화면이 죽지 않게.
  /// (백업 복원·손으로 고친 기록·옛 버전에서 온 값이 섞일 수 있다)
  static Map<String, dynamic> asMap(Object? v) =>
      v is Map ? v.cast<String, dynamic>() : const {};

  /// 숫자여야 할 자리의 값을 안전하게 읽는다.
  /// 글자가 들어 있으면 통장 합계가 통째로 멈춘다 — Store.tidy가 못 걸른 값도 여기서 막는다.
  static int asInt(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return num.tryParse(v)?.toInt() ?? 0;
    return 0;
  }

  /// 반복 모임을 회차별 날짜로 펼친다.
  /// (State.by('event')를 그냥 세면 매주 모임이 1회로 계산돼 출석률이 엉망이 된다)
  static List<String> occurrences(
    Map<String, dynamic> e, {
    DateTime? from,
    DateTime? to,
    int limit = 2000, // 매주 모임 기준 38년치 — 옛 모임이 잘려 사라지지 않게 넉넉히
  }) {
    final start = parseYmd(e['date'] as String?);
    final rep = (e['repeat'] as String?) ?? 'none';
    final untilStr = e['until'] as String?;
    final until = untilStr == null || untilStr.length < 10 ? null : parseYmd(untilStr);
    final end = to ?? DateTime.now();
    final out = <String>[];

    if (rep == 'none') {
      if (!start.isAfter(end) && (from == null || !start.isBefore(from))) out.add(ymd(start));
      return out;
    }

    /* ⚠️ 회차는 **언제나 처음 날(start)에서 몇 번째인지로** 센다.
       앞 회차에 한 달씩 더해 가면 날짜가 «영영 밀린다»:
         매달 31일 모임 → 1/31 다음이 2/31 = **3월 3일**(달력이 넘겨 준다) → 그 뒤로 계속 3일.
         2월이 통째로 빠지고, 회원은 「31일 모임」인데 3일에 나오라는 안내를 받는다.
       매년 2월 29일도 같다 → 3월 1일로 밀린 뒤 영영 3월 1일. */
    var n = 0;
    // [from]이 있으면 그 앞의 회차는 세지 않고 건너뛴다.
    // 하나씩 세어 가면 오래된 모임일수록 헛도는 횟수가 늘고, 안전장치에 걸려
    // 「다가오는 모임」에서 아예 사라지는 일이 생긴다.
    if (from != null && from.isAfter(start)) {
      /* ⚠️ 여기 갈래표는 `nthOccurrence` 와 **반드시 같아야** 한다.
         거기서는 모르는 값을 「매주」로 보는데 여기서만 0(건너뛰기 없음)이었다 →
         모르는 값이 오면 처음 회차부터 하나씩 세어 **안전장치(2000번)까지 헛돈다.**
         2026-08-24 실측: 같은 자료로 「다가오는 모임」이 9.8㎳ → **60.7㎳ (6배)**.
         모르는 값은 실제로 온다 — 웹앱·백업 복원·다음 판 앱이 적은 값. */
      n = switch (rep) {
        '2week' => from.difference(start).inDays ~/ 14,
        'month' => (from.year - start.year) * 12 + (from.month - start.month),
        'year' => from.year - start.year,
        _ => from.difference(start).inDays ~/ 7, // 'week' 와 «모르는 값» (nthOccurrence 와 짝)
      };
      if (n < 0) n = 0;
    }
    var guard = 0;
    while (guard++ < limit) {
      final cur = nthOccurrence(start, rep, n);
      n++;
      if (cur.isAfter(end)) break;
      if (until != null && cur.isAfter(until)) break;
      if (from == null || !cur.isBefore(from)) out.add(ymd(cur));
    }
    return out;
  }

  /// 처음 날에서 [n]번째 회차의 날짜.
  ///
  /// 매달·매년은 **그 달에 없는 날이면 그 달의 마지막 날로 당긴다** (31일 → 2월은 28/29일).
  /// 그래야 다음 달에 다시 31일로 돌아온다 — 밀어내면 영영 돌아오지 못한다.
  static DateTime nthOccurrence(DateTime start, String rep, int n) {
    switch (rep) {
      case 'week':
        return DateTime(start.year, start.month, start.day + 7 * n);
      case '2week':
        return DateTime(start.year, start.month, start.day + 14 * n);
      case 'month':
        return _monthsAfter(start, n);
      case 'year':
        return _monthsAfter(start, 12 * n);
      default:
        return DateTime(start.year, start.month, start.day + 7 * n);
    }
  }

  static DateTime _monthsAfter(DateTime start, int months) {
    final total = start.month - 1 + months;
    final y = start.year + (total >= 0 ? total ~/ 12 : (total - 11) ~/ 12);
    final m = total % 12 < 0 ? total % 12 + 12 : total % 12;
    // 「그 달의 0일」 = 앞 달의 마지막 날 → 그 달이 며칠까지인지 알아내는 법
    final last = DateTime(y, m + 2, 0).day;
    return DateTime(y, m + 1, start.day < last ? start.day : last);
  }

  /* 📅 「매달·매년」 모임인데 그 날짜가 **없는 달·해**가 생기는가.

     `nthOccurrence` 는 그런 회차를 «그 달의 마지막 날»로 당긴다(밀어내면 영영 못 돌아온다).
     그건 옳은 셈이지만, **화면이 그 말을 안 하면 방장은 모른다** —
     「매달 31일」로 정해 놓고 회원 화면에는 2월 28일 모임이 뜬다.
     그래서 만들 때 미리 알려 준다. (알림 문구일 뿐 셈은 바꾸지 않는다) */
  static String? clampNote(String rep, DateTime start) {
    if (rep == 'month' && start.day >= 29) {
      return '${start.day}일이 없는 달은 그 달의 «마지막 날»에 모여요 (2월은 28일)';
    }
    if (rep == 'year' && start.month == 2 && start.day == 29) {
      return '2월 29일은 4년에 한 번이라, 그 밖의 해에는 «2월 28일»에 모여요';
    }
    return null;
  }

  /// 이 모임이 그 날짜에 «있는 회차»인지.
  static bool occursOn(Map<String, dynamic> e, String date) {
    if (date.length < 10) return false;
    final d = parseYmd(date);
    return occurrences(e, from: d, to: d).isNotEmpty;
  }

  /// 일정을 고쳤을 때 «세어지지 않게 되는» 출석·참석 기록 수.
  ///
  /// ⚠️ 출석·투표는 「날짜_uid」로 적히고, 목록·배지·순위는 **지금 회차 목록에 있는 날짜만** 센다.
  /// 그래서 날짜뿐 아니라 «반복 주기»나 «종료일»만 바꿔도 기록은 문서에 남아 있는데
  /// **아무 데서도 안 보인다** — 매주 모임을 「반복 없음」으로 바꾸면 3년치 출석이 한 번에 사라진다.
  static int recordsDropped(Map<String, dynamic> before, Map<String, dynamic> after) {
    var n = 0;
    // 같은 날짜를 여러 번 묻지 않게 답을 적어 둔다 (회원 30명이면 같은 날이 30번 나온다)
    final was = <String, bool>{};
    final now = <String, bool>{};
    for (final f in const ['attend', 'rsvp']) {
      asMap(before[f]).forEach((k, _) {
        if (k.length < 12) return;
        final d = k.substring(0, 10);
        if ((was[d] ??= occursOn(before, d)) && !(now[d] ??= occursOn(after, d))) n++;
      });
    }
    return n;
  }

  /* 이미 지난 회차만 (출석 집계용).

     ⏱ **재어 둔다.** 이 셈은 3년치 매주 모임을 통째로 펼치는 일이라 비싼데,
     홈 화면 하나가 «전체 출석»(attendStats)과 «이번 달 순위»(monthRank)로 **두 번** 부른다.
     2026-08-24 실측(일정 50개·3년치·회원 20명): 전체 81㎳ + 이번 달 55㎳ = 136㎳ —
     값싼 폰이면 그 서너 배라 방에 들어갈 때 화면이 눈에 띄게 멎는다.
     열쇠는 «그 모임 물건 + 오늘». 모임을 고치면 물건이 새것이 되고, 날이 바뀌면 오늘이 달라진다. */
  static final _pastCache = <Map<String, dynamic>, List<String>>{};
  static String _pastDay = '';

  static List<String> pastOccurrences(Map<String, dynamic> e) {
    final today = ymd(DateTime.now());
    if (_pastDay != today) {
      _pastDay = today;
      _pastCache.clear();
    }
    final hit = _pastCache[e];
    if (hit != null) return hit;
    final out = occurrences(e).where((d) => d.compareTo(today) <= 0).toList();
    /* 방을 옮기거나 모임이 늘어도 이 표가 끝없이 커지면 안 된다 —
       열쇠가 «물건»이라 옛 모임은 다시 안 찾아지고 남기만 한다. 넉넉히 잡고 넘치면 비운다. */
    if (_pastCache.length > 400) _pastCache.clear();
    _pastCache[e] = out;
    return out;
  }

  /// 다음 «자정»까지 남은 밀리초 — 날이 바뀌는 순간 화면을 깨우려고 쓴다.
  /// 달·해가 넘어가도 달력이 알아서 넘겨 준다(12월 31일 → 1월 1일).
  static int msUntilNextDay(DateTime now) =>
      DateTime(now.year, now.month, now.day + 1).difference(now).inMilliseconds;

  /// 「다가오는 것」을 찾을 때 어디까지 내다볼지.
  ///
  /// ⚠️ 한 번뿐인 모임은 **아무리 멀어도 보여야 한다.** 예전에는 무조건 400일까지만 봐서,
  /// 방장이 1년 반 뒤 날짜로 모임을 만들면 저장은 되는데 **어느 목록에도 안 나왔다**
  /// (지난 목록에도 없다 — 아직 안 지났으니까). 화면에 없으니 고칠 수도 지울 수도 없다.
  /// 반복 모임은 400일이면 다음 회차가 반드시 들어오므로 그대로 둔다.
  static DateTime horizonFor(Map<String, dynamic> e, DateTime now) =>
      ((e['repeat'] as String?) ?? 'none') == 'none'
          ? DateTime(now.year + 20, now.month, now.day)
          : now.add(const Duration(days: 400));

  /* 같은 날 모임이 둘이면 **시각까지 봐야** 차례가 맞는다.
     날짜만 견주면 홈의 「다가오는 모임」이 아침 7시를 두고 **저녁 8시 모임**을 보여주고,
     일정 목록도 만든 차례대로 뒤섞인다. (웹앱의 byDateTime 과 같은 규칙)
     시각이 없는 모임은 «하루 종일»로 보고 그 날의 맨 앞에 둔다. */
  static int byDateTime(String aDate, Object? aTime, String bDate, Object? bTime) {
    final d = aDate.compareTo(bDate);
    if (d != 0) return d;
    final at = aTime is String ? aTime : '';
    final bt = bTime is String ? bTime : '';
    return at.compareTo(bt);
  }

  /* 「다가오는 모임」도 재어 둔다.
     홈은 채팅·회비 무엇이 바뀌어도 다시 그려지는데, 이 셈은 일정마다 회차를 펼쳐 본다.
     2026-08-23 실측(모임 8개·3년치): 한 번에 **20㎳** — 출석·회비는 표를 두는데 여기만 없었다.
     열쇠는 «일정 묶음»과 «오늘» (날이 바뀌면 다가오는 것도 달라진다). */
  static List<Map<String, dynamic>>? _nextSrc;
  static String? _nextDay;
  static ({Map<String, dynamic> event, String date})? _nextVal;
  static bool _nextDone = false;

  /// 다가오는 모임 하나 — 홈에서 보여준다.
  static ({Map<String, dynamic> event, String date})? nextEvent() {
    final events = AppState.i.by('event');
    final today = ymd(DateTime.now());
    if (_nextDone && identical(_nextSrc, events) && _nextDay == today) return _nextVal;

    ({Map<String, dynamic> event, String date})? best;
    final now = DateTime.now();
    for (final e in events) {
      final future = occurrences(
        e,
        from: DateTime(now.year, now.month, now.day),
        to: horizonFor(e, now),
      );
      for (final d in future) {
        if (best == null ||
            byDateTime(d, e['time'], best.date, best.event['time']) < 0) {
          best = (event: e, date: d);
        }
        break; // 이 모임의 가장 가까운 회차 하나만
      }
    }
    _nextSrc = events;
    _nextDay = today;
    _nextVal = best;
    _nextDone = true;
    return best;
  }

  /* 📅 일정 목록 — 모임을 회차로 펼쳐 날짜 순으로 늘어놓는다.
     **반드시 재어 둔다.** 일정 화면은 IndexedStack 안에 «살아 있어»
     다른 탭을 보는 중에도 다시 그려진다 — 곧 **채팅 한 줄만 와도** 다시 펼친다.
     2026-08-23 실측(이 PC): 매주 모임 10개·3년치 → 지난 목록 한 번에 **97ms**
     (회차 1902개를 펼치고 정렬). 값싼 폰에서는 서너 배다.
     출석 세기(_countAttend)·다음 모임(nextEvent)·회비 표(_feeIndex)는 이미 재어 두는데
     여기만 빠져 있었다. 열쇠는 «일정 묶음 + 날 + 지난/다가올». */
  static List<Map<String, dynamic>>? _rowsSrc;
  static String? _rowsDay;
  static bool? _rowsPast;
  static List<({Map<String, dynamic> e, String date})>? _rowsVal;

  static List<({Map<String, dynamic> e, String date})> eventRows(
      {required bool past}) {
    final events = AppState.i.by('event');
    final today = ymd(DateTime.now());
    final cached = _rowsVal;
    if (cached != null &&
        identical(_rowsSrc, events) &&
        _rowsDay == today &&
        _rowsPast == past) {
      return cached;
    }
    final now = DateTime.now();
    final out = <({Map<String, dynamic> e, String date})>[];
    for (final e in events) {
      final list = past
          ? pastOccurrences(e)
          : occurrences(e,
              from: DateTime(now.year, now.month, now.day),
              to: horizonFor(e, now));
      for (final d in list) {
        out.add((e: e, date: d));
      }
    }
    // 같은 날 모임이 둘이면 시각까지 봐야 차례가 맞는다 (지난 목록은 최근 것부터)
    out.sort((a, b) => past
        ? byDateTime(b.date, b.e['time'], a.date, a.e['time'])
        : byDateTime(a.date, a.e['time'], b.date, b.e['time']));
    _rowsSrc = events;
    _rowsDay = today;
    _rowsPast = past;
    _rowsVal = out;
    return out;
  }

  /// [uid] 를 안 주면 «나»로 본다 — 주면 서버 없이도 시험할 수 있다.
  static String? myRsvp(Map<String, dynamic> e, String date, [String? uid]) {
    final map = asMap(e['rsvp']);
    // 폰을 바꾸기 «전» 번호로 찍은 표도 내 것이다 (attended 와 같은 잣대)
    for (final k in markKeys(map, date, uid ?? Store.i.myUid)) {
      final v = map[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  /// 그 회차의 참석·불참 표 수 — **지금 회원만** 센다.
  ///
  /// ⚠️ 예전에는 적힌 표를 모두 셌다. 그러면 두 가지가 더해진다:
  ///   · **탈퇴한 회원**의 옛 표
  ///   · 폰을 바꾼 회원의 **옛 번호** 표 (새 번호로 또 찍으므로 **한 사람이 두 번**)
  /// 2026-08-23 실측: 실제 2명인데 「참석 4」로 보였다.
  /// 방장은 그 숫자로 코트를 잡는다 — 출석 수(`memberList` 로 세는 곳)와 규칙이 달랐던 것이다.
  static int rsvpCount(Map<String, dynamic> e, String date, String want) {
    final map = asMap(e['rsvp']);
    final now = AppState.i.members;
    // 폰을 바꾼 사람은 옛·새 번호로 두 번 찍혀 있을 수 있다 — 사람 단위로 모아 «한 번만» 센다
    final who = <String>{};
    map.forEach((k, v) {
      if (v != want) return;
      // 열쇠는 「YYYY-MM-DD_번호」 — 날짜 길이가 정해져 있어 번호에 밑줄이 있어도 안전하다
      if (k.length < 12 || !k.startsWith('${date}_')) return;
      final uid = liveUid(k.substring(11));
      if (now.containsKey(uid)) who.add(uid);
    });
    return who.length;
  }

  /* 🗝 그 사람이 그 날 남긴 «표»의 열쇠들 — 폰을 바꾸기 «전» 번호까지.

     참석 투표(rsvp)·출석(attend)은 「날짜_번호」로 적힌다. 세는 쪽(`rsvpCount`·`_countAttend`)은
     옛 번호를 이어 «한 사람»으로 세는데, **켜고 끄는 쪽은 새 번호만 건드리고 있었다.**
     그래서 폰을 바꾼 회원은
       · 참석 수에는 들어 있는데 **제 단추는 안 눌린 것처럼** 보이고
       · 눌러서 껐는데 **옛 표가 남아 인원이 안 줄었다**(출석은 취소가 아예 안 됐다).
     끌 때는 **여기 있는 것을 전부** 지워야 유령 표가 안 남는다.
     («지금 번호»를 맨 앞에 둔다 — 내 최신 표가 먼저 잡히게) */
  static List<String> markKeys(
          Map<String, dynamic> map, String date, String uid) =>
      [
        for (final u in [uid, ...pastUids(uid)])
          if (map[rkey(date, u)] != null) rkey(date, u)
      ];

  static bool attended(Map<String, dynamic> e, String date, String uid) {
    final map = asMap(e['attend']);
    if (map[rkey(date, uid)] == true) return true;
    // 폰을 바꾸기 «전» 번호로 찍혀 있을 수 있다
    for (final old in pastUids(uid)) {
      if (map[rkey(date, old)] == true) return true;
    }
    return false;
  }

  /* 📊 대화방 투표 ────────────────────────────────────────────────
     자료 모양은 **웹앱과 글자까지 같아야 한다** — 같은 방을 두 앱이 함께 본다:
       kind:'poll' · poll:{q:질문, opts:[항목…], multi:복수선택, closed:마감}
       votes:{번호:[고른 항목 자리…]}
     ⚠️ 질문은 `text` 에도 담긴다 — 투표를 «모르는» 옛 앱에서 빈 말풍선이 되지 않게
        (음성 메시지가 실제로 그랬다). 그래서 질문이 없으면 `text` 로 되돌려 읽는다. */
  /* 📊 투표 한 건을 읽는다.

     [closed] 는 «지금 닫혀 있는가»다 — 두 가지로 닫힌다:
       · 만든 사람이 손으로 마감(`closed: true`)
       · **기한이 지남**(`until` 이 지금보다 앞) ← 2026-08-30 더함
     기한이 있는 투표는 아무도 안 눌러도 때가 되면 저절로 끝나야 한다.
     사람이 마감하기를 기다리면, 마감을 잊은 투표가 몇 달씩 열린 채 남는다.

     ⚠️ [until] 은 «있으면» 그 시각(밀리초). 없으면 null — 기한 없는 투표다.
     ⚠️ 시각은 «그릴 때마다» 다시 본다 — 화면이 멈춰 있어도 다음 그림에서 닫힌다.
        (그래서 화면 쪽에서 그 시각에 맞춰 한 번 더 그려 줘야 한다) */
  static ({String q, List<String> opts, bool multi, bool closed, int? until})
      poll(Map<String, dynamic> m, {int? now}) {
    final p = asMap(m['poll']);
    final q = p['q'];
    final opts = p['opts'];
    final u = p['until'];
    final until = u is num ? u.toInt() : null;
    final t = now ?? DateTime.now().millisecondsSinceEpoch;
    return (
      q: (q is String && q.isNotEmpty) ? q : ((m['text'] as String?) ?? ''),
      // 글자가 아닌 항목은 뺀다 — 그리는 자리에서 터지면 대화방이 통째로 안 뜬다
      opts: opts is List ? opts.whereType<String>().toList() : const <String>[],
      multi: p['multi'] == true,
      closed: p['closed'] == true || (until != null && t >= until),
      until: until,
    );
  }

  /* ⏳ 기한까지 남은 밀리초 — 지났거나 기한이 없으면 null.
     화면이 «그때» 스스로 다시 그리도록 쓰는 값이다. */
  static int? pollLeftMs(Map<String, dynamic> m, {int? now}) {
    final p = asMap(m['poll']);
    final u = p['until'];
    if (u is! num) return null;
    final left = u.toInt() - (now ?? DateTime.now().millisecondsSinceEpoch);
    return left > 0 ? left : null;
  }

  /// 적힌 표 한 사람 몫을 «항목 자리 목록»으로. 숫자 하나만 적힌 옛 꼴도 받아 준다.
  static List<int> pollPicks(Object? v) {
    if (v is List) return v.whereType<num>().map((n) => n.toInt()).toList();
    if (v is num) return [v.toInt()];
    return const [];
  }

  /* 항목마다 «누가» 골랐나 — **지금 회원**의 표만, 한 사람은 **한 번만**.
     ⚠️ 그냥 세면 ①탈퇴한 회원의 옛 표 ②폰 바꾼 회원의 옛 번호 표가 더해져
        방장이 실제보다 많은 인원으로 코트를 잡는다 (참석 투표에서 실제로 겪은 일). */
  static ({List<List<String>> per, int voters}) pollTally(
      Map<String, dynamic> m,
      {Map<String, dynamic>? members}) {
    final opts = poll(m).opts;
    final votes = asMap(m['votes']);
    final now = members ?? AppState.i.members;
    final per = List.generate(opts.length, (_) => <String>[]);
    // 폰을 바꾼 사람은 옛·새 번호로 두 번 찍혀 있을 수 있다 — 사람 단위로 모은다
    final byPerson = <String, List<int>>{};
    votes.forEach((u, v) {
      final uid = liveUid(u);
      if (!now.containsKey(uid)) return; // 탈퇴한 회원의 표는 안 센다
      // 이미 «지금 번호»로 찍은 표가 있으면 옛 표는 버린다 (적힌 차례와 무관하게)
      if (byPerson.containsKey(uid) && u != uid) return;
      byPerson[uid] = pollPicks(v);
    });
    var voters = 0;
    byPerson.forEach((uid, picks) {
      var any = false;
      for (final i in picks.toSet()) {
        if (i >= 0 && i < per.length) {
          per[i].add(uid);
          any = true;
        }
      }
      if (any) voters++;
    });
    return (per: per, voters: voters);
  }

  /// 내가 고른 항목들 — 폰을 바꾸기 «전» 번호로 찍은 표도 내 표다.
  static List<int> pollMine(Map<String, dynamic> m, String myUid) {
    final votes = asMap(m['votes']);
    for (final u in [myUid, ...pollOldKeys(m, myUid)]) {
      final v = votes[u];
      if (v != null) return pollPicks(v);
    }
    return const [];
  }

  /// 내 옛 번호로 남아 있는 표 자리 — 찍을 때 **함께 지워야** 유령 표가 안 남는다.
  static List<String> pollOldKeys(Map<String, dynamic> m, String myUid) {
    final me = liveUid(myUid);
    return asMap(m['votes'])
        .keys
        .where((u) => u != myUid && liveUid(u) == me)
        .toList();
  }

  /// 항목 하나를 눌렀을 때의 «다음» 표. 하나만 고르는 투표는 갈아치우고, 같은 것을 다시 누르면 취소.
  static List<int> pollNext(List<int> cur, int i, bool multi) {
    if (cur.contains(i)) return cur.where((x) => x != i).toList();
    if (!multi) return [i];
    return [...cur, i]..sort();
  }

  /// 회원별 출석 횟수 — 지난 회차 기준.
  static Map<String, int> attendStats() => _countAttend();

  /// 출석 세기 — [monthPrefix]를 주면 그 달(YYYY-MM)만 센다.
  ///
  /// 회차 하나하나마다 출석표 전체를 훑으면, 매주 모임이 2년 쌓였을 때
  /// 홈 화면을 그릴 때마다 수십만 번을 도느라 앱이 눈에 띄게 느려진다.
  /// 그래서 회차는 한 번만 모아두고(Set) 출석표도 한 번만 훑는다.
  /* 「누가 몇 번 나왔는지」 표 — 기록이 갈릴 때(또는 날이 바뀔 때)만 다시 만든다.
     ⚠️ 안 재두면 홈 화면 한 장을 그릴 때마다 이 셈을 «세 번» 한다
     (내 출석 한 번, 이번 달 순위 두 번). 홈은 채팅에서 누가 글씨만 쳐도 다시 그려지므로,
     실제로 재보니 모임 8개 · 회원 20명 · 3년치에서 **한 번 그리는 데 140ms**가 걸렸다.
     값싼 폰에서는 그보다 훨씬 느려 화면이 눈에 띄게 걸린다. (회비 표 `_feeIndex`와 같은 방식) */
  static List<Map<String, dynamic>>? _attSrc;
  static Map<String, String>? _attMoved;
  static String? _attDay;
  static Map<String, int>? _attAll;
  static Map<String, int>? _attMonth;
  static String? _attMonthKey;

  static Map<String, int> _countAttend({String? monthPrefix}) {
    // 열쇠는 «일정 묶음» — 대화가 와도 일정이 그대로면 다시 안 센다
    final items = AppState.i.by('event');
    final today = ymd(DateTime.now());
    // 기록이 갈렸거나 날이 바뀌면(지난 회차가 늘어난다) 처음부터 다시 센다
    if (!identical(_attSrc, items) ||
        _attDay != today ||
        !identical(_attMoved, movedMap())) {
      _attSrc = items;
      _attDay = today;
      _attMoved = movedMap();
      _attAll = null;
      _attMonth = null;
      _attMonthKey = null;
    }
    if (monthPrefix == null) {
      final c = _attAll;
      if (c != null) return c;
    } else if (_attMonthKey == monthPrefix) {
      final c = _attMonth;
      if (c != null) return c;
    }

    final out = <String, int>{};
    /* 폰을 바꾼 사람은 옛 번호로도 찍혀 있다 — 지금 번호로 이어서 센다.
       단 «같은 날 같은 사람»이 두 번 세어지지 않게 (옛·새 번호가 둘 다 찍힌 날) 표를 둔다. */
    final seen = <String>{};
    for (final e in items) {
      final map = asMap(e['attend']);
      if (map.isEmpty) continue;
      final past = pastOccurrences(e)
          .where((d) => monthPrefix == null || d.startsWith(monthPrefix))
          .toSet();
      if (past.isEmpty) continue;
      map.forEach((k, v) {
        // 키는 「YYYY-MM-DD_uid」 — 날짜 길이가 정해져 있어 uid에 밑줄이 있어도 안전하다
        if (v != true || k.length < 12) return;
        final day = k.substring(0, 10);
        if (!past.contains(day)) return;
        final uid = liveUid(k.substring(11));
        if (!seen.add('${e['id']}|$day|$uid')) return;
        out[uid] = (out[uid] ?? 0) + 1;
      });
    }
    if (monthPrefix == null) {
      _attAll = out;
    } else {
      _attMonth = out;
      _attMonthKey = monthPrefix;
    }
    return out;
  }

  /// 이번 달 출석 순위.
  ///
  /// **지금 회원인 사람만** 세운다. 출석표에는 탈퇴한 사람의 기록도 그대로 남아 있어서,
  /// 안 거르면 홈의 순위 카드에 「지난 회원」이라는 이름으로 유령 줄이 뜬다.
  static List<MapEntry<String, int>> monthRank() {
    final month = ymd(DateTime.now()).substring(0, 7);
    final now = AppState.i.members;
    final list = _countAttend(monthPrefix: month)
        .entries
        .where((e) => now.containsKey(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  /* 「내가 방장 맡기」를 **서버가 받아 줄** 조건 —
     firestore.rules 의 `notSelfPromotingToOwner()` 와 같은 뜻이라야 한다.
     화면이 「방장이 없다」만 보고 단추를 띄우면, 자리가 열려 있지 않은 방에서는
     눌러도 서버가 거절해 **몇 번을 눌러도 안 되는 죽은 단추**가 된다. */
  static bool canClaimOwner(Map<String, dynamic>? couple, String myUid) {
    if (couple == null) return false;
    if (couple.containsKey('ownerReleased')) return true; // 총괄이 자리를 열어 뒀다
    final me = (couple['members'] as Map?)?[myUid];
    return me is Map && me['role'] == 'owner'; // 원래 방장이면 그대로 둘 수 있다
  }

    /* 🗑 이 기록을 «서버가» 지우게 해 주는가 — `firestore.rules` 의 delete 와 같은 뜻이라야 한다.

       allow delete 는 「내가 쓴 것」이거나 「총괄」이거나 「그 방 운영진」일 때만 통과한다.
         · 내가 쓴 것 = by 가 나  또는  uid 가 나
         · 그 방 운영진 = role 이 owner 또는 admin  (**직책은 안 본다**)

     ⚠️ 회비 장부만 이 잣대가 빠져 있었다 — 「총무」 직책이면 «남이 적은» 기록까지 지우기 메뉴가
        보였는데, 그 사람 role 이 평회원이면 서버가 거절한다.
        총무가 바뀌면 새 총무는 옛 총무·방장이 적은 기록을 영영 못 지우면서
        「지우지 못했어요 — 다시 시도해주세요」만 되풀이해 본다(눌러도 안 되는 단추).
     ※ 게시판·사진첩·대화방은 처음부터 이 잣대를 줄 안에 그대로 쓰고 있었다.
     ※ 「돈을 다룰 수 있는가」(isTreasurer)는 «따로» 걸러야 한다 — 규칙도 둘을 함께 요구한다. */
  static bool canDeleteItem(Map<String, dynamic> item, String myUid) {
    if (myUid.isEmpty) return false;
    if (item['by'] == myUid || item['uid'] == myUid) return true;
    // 📸 사진이 든 것은 «방장·회장·총무»만 — 아래 설명 참고
    if (Store.photoIdsOf(item).isNotEmpty) return isPhotoBoss;
    return AppState.i.isAdmin;
  }

  /* 📸 **남이 올린 사진을 지울 수 있는 사람** — 방장, 그리고 «운영진인» 회장·총무.
     사진은 되돌릴 수 없고 보관료도 걸려 있어 운영진 전부가 아니라 여기까지만 좁힌다.
     (사진첩·게시판·대화방 모두 같은 잣대다 — 사진이 든 것이면 어디서든 같다)

     ⚠️ **직책만 보면 안 된다.** 서버 규칙(`isStaffOf`)은 role 이 owner·admin 인지만 보고
        직책은 안 본다. 평회원 「총무」에게 단추를 보여 주면 눌러도 서버가 거절하는
        **죽은 단추**가 된다 — 회비 장부에서 실제로 그랬다.
        그래서 「운영진 권한 **그리고** 그 직책」 둘 다일 때만 참이다. */
  static bool get isPhotoBoss {
    final st = AppState.i;
    if (st.isOwner) return true;
    if (!st.isAdmin) return false; // 서버가 거절할 사람에게는 단추를 안 보인다
    final t = st.me?['title'] as String?;
    return t != null && photoBossTitles.contains(t);
  }

/* 👥 같은 이름 + 같은 아바타면 채팅·출석·순위 어디서도 **누가 누군지 구분이 안 된다.**
     ⚠️ 「맨 앞 한 사람」만 보면 안 된다 — 같은 이름이 여럿일 때 생년월일로 골라 낸 사람은
        아바타가 다르고, 정작 «다른» 동명이인과 겹칠 수 있다.
        (설정의 「내 정보 고치기」는 처음부터 전부 훑었는데, 가입 화면만 한 사람만 봤다)
     사진을 쓰는 아바타는 그 자체로 구분되므로 겹침으로 세지 않는다. */
  static Map<String, dynamic>? avatarClash(
    Iterable<Map<String, dynamic>> people,
    String name,
    String emoji, {
    String? skipUid,
  }) {
    for (final m in people) {
      if (skipUid != null && m['uid'] == skipUid) continue;
      if (Store.normTitle(m['name'] as String?) != Store.normTitle(name)) continue;
      if (m['photo'] != null) continue;
      if (((m['emoji'] as String?) ?? defaultAvatar) != emoji) continue;
      return m;
    }
    return null;
  }

  /// 권한(role)을 내려도 «직책» 때문에 회비를 그대로 다룰 수 있는 사람인지.
  ///
  /// ⚠️ 서버 규칙 `canHandleMoney` 는 role «또는» title 만 맞아도 회비 장부를 열어 준다.
  /// 그래서 「운영진 해제」만 하면 **회비는 그대로 쓸 수 있는데 방장은 뗐다고 믿는다.**
  static bool keepsMoneyByTitle(String? title) =>
      title != null && treasurerTitles.contains(title);

  // ─────────────────────────────── 회비

  /* 💸 지출 갈래 이름 — 웹앱(아이폰 회원)은 «영어 열쇠»로 적고 이 앱은 «한글»로 적는다.
     그대로 두면 「어디에 썼나」에 `court`·`shuttle` 같은 영어가 뜨고, 더 나쁜 것은
     같은 뜻인데 열쇠가 달라 **합계가 두 줄로 갈린다**(셔틀콕 5만 · shuttle 3만).
     읽을 때 한글로 맞춰 주면 옛 기록도 그대로 살아나고 두 앱 합계가 하나로 합쳐진다.
     (웹의 `LEDGER_CATS` 와 짝. 웹에만 있는 「경조사」는 그 이름 그대로 보여 준다) */
  static const _catAlias = {
    'court': '체육관',
    'shuttle': '셔틀콕',
    'gear': '용품',
    'party': '회식',
    'game': '대회',
    'gift': '경조사',
    'etc': '기타',
  };

  /// 갈래가 없으면 «아무 말도 안 한다»(null) — 들어온 돈에는 갈래가 없다.
  static String? catLabel(Object? cat) {
    final s = cat is String ? cat.trim() : '';
    if (s.isEmpty) return null;
    return _catAlias[s] ?? s;
  }

  /// 그 달에 회비를 낸 것으로 볼지 —
  /// 들어온 기록(kind:'in')이 그 달에 있거나, 선납(feeMonths)에 그 달이 들어 있으면 낸 것.
  static bool paidIn(String uid, String month) =>
      _feeIndex()[uid]?.contains(month) ?? false;

  // 「누가 어느 달을 냈는지」 표. 기록이 갈릴 때만 다시 만든다.
  // (회원 30명 × 12달마다 장부 전체를 훑으면 회비 화면이 눈에 띄게 느려진다)
  static List<Map<String, dynamic>>? _feeSrc;
  static Map<String, Set<String>>? _feeIdx;
  static Map<String, String>? _feeMoved;

  static Map<String, Set<String>> _feeIndex() {
    /* ⚠️ 열쇠는 «전체 기록»이 아니라 **회비 기록 묶음**이라야 한다.
       전체로 잡으면 대화 한 건만 와도 표를 통째로 다시 만든다(실측 131.6㎳). */
    final items = AppState.i.by('ledger');
    final cached = _feeIdx;
    // 「옛 번호 잇기」도 답에 섞이므로 그 표가 갈리면 다시 만든다
    if (cached != null && identical(_feeSrc, items) && identical(_feeMoved, movedMap())) {
      return cached;
    }
    _feeMoved = movedMap();
    final idx = <String, Set<String>>{};
    for (final x in items) {
      if (x['kind'] != 'in') continue;
      final raw = x['payer'] as String?;
      if (raw == null || raw.isEmpty) continue;
      // 「회비통장」은 사람이 아니다 — 세면 없는 회원 하나가 표에 생긴다 (웹도 이 값을 뺀다)
      if (raw == Store.walletPayer) continue;
      // 폰을 바꾸기 «전» 번호로 낸 회비도 그 사람 것이다 (옮기기는 평회원이면 서버가 거절한다)
      final payer = liveUid(raw);
      final set = idx.putIfAbsent(payer, () => <String>{});
      final months = (x['feeMonths'] as List?)?.cast<String>();
      if (months != null && months.isNotEmpty) {
        set.addAll(months); // 선납은 적어둔 달들이 곧 낸 달
        continue;
      }
      final d = x['date'] as String?;
      if (d != null && d.length >= 7) set.add(d.substring(0, 7));
    }
    _feeSrc = items;
    _feeIdx = idx;
    return idx;
  }

  /* 달 셈은 **정수로** 한다 — 「YYYY-MM」 하나 만들려고 `DateTime` 을 세우면
     지역 시간대를 찾느라 한 번에 수십 ㎲가 든다.
     2026-08-23 실측: `unpaidMonths` 한 번에 790㎲, 회비 화면은 회원 줄마다 이걸 부르므로
     **회원 50명이면 한 번 그리는 데 39ms** — 회비 탭은 IndexedStack 안에 살아 있어
     채팅 한 줄만 와도 그 값을 치렀다. 정수로 바꾸니 한 번에 20㎲ 아래로 떨어진다.
     (달을 0부터 이어 센 값 = 해*12 + 달-1. 음수 없이 늘 양수라 나눗셈이 안전하다) */
  static int ymOf(DateTime d) => d.year * 12 + d.month - 1;

  /* 「2026-08」 같은 달 이름을 «달 셈»으로 되돌린다 (ymOf 의 반대).
     ⚠️ 모양이 아니면 null 을 준다 — 손으로 고친 백업·옛 자료가 섞일 수 있어
        여기서 걸러 내야 표가 엉뚱한 해로 튀지 않는다. */
  static int? ymOfKey(String? key) {
    if (key == null || key.length < 7) return null;
    final y = int.tryParse(key.substring(0, 4));
    final m = int.tryParse(key.substring(5, 7));
    if (y == null || m == null || m < 1 || m > 12) return null;
    return y * 12 + m - 1;
  }

  static String ymKey(int ym) =>
      '${ym ~/ 12}-${(ym % 12 + 1).toString().padLeft(2, '0')}';

  /* 🧾 「밀린 달」은 **12달까지만** 센다(`unpaidMonths` 의 `maxBack`).
     오래 안 낸 회원이 있으면 그 셈이 «잘린 값»인데, 화면이 그냥 「12달 밀림」이라고 하면
     총무는 **그게 전부인 줄 안다** — 실제로는 3년치일 수도 있다.
     그래서 «창 바로 앞 달»을 한 번만 더 물어보고, 거기도 안 냈으면
     화면이 「12달 **이상** 밀림」이라고 말하게 한다. (셈은 그대로 두고 말만 맞춘다) */
  static const unpaidMaxBack = 12;

  static bool unpaidTruncated(String uid, {int maxBack = unpaidMaxBack}) {
    final fee = asMap(AppState.i.couple?['fee']);
    if (((fee['amount'] as num?)?.toInt() ?? 0) <= 0) return false;
    final joinedAt = (AppState.i.members[uid] as Map?)?['joinedAt'] as num?;
    if (joinedAt == null) return false; // 언제 들어왔는지 모르면 잘렸다고 단정할 수 없다
    final joinedYm = ymOf(DateTime.fromMillisecondsSinceEpoch(joinedAt.toInt()));
    final before = ymOf(DateTime.now()) - maxBack; // 세는 창 «바로 앞» 달
    if (before < joinedYm) return false; // 그 앞은 들어오기 전이라 밀린 것이 없다
    final key = ymKey(before);
    if (feeFree(uid).contains(key)) return false; // 면제한 달이면 잘린 것이 아니다
    return !paidIn(uid, key);
  }

  /* 🙇 «그 달만 면제»해 준 달들 — `members.<uid>.feeFree`.

     ⚠️ 여기(Logic)에 두는 까닭: 밀린 달 셈과 표가 **같은 자리**를 봐야 한다.
        표에만 반영하면 표는 「면」인데 회비 화면은 「3달 밀림」이라 하고,
        회비를 받으려 하면 면제한 달부터 채워진다 — 같은 앱이 세 가지 말을 한다.
     ⚠️ 나간 사람은 `former` 에 적힌다 — 둘 다 본다. */
  static Set<String> feeFree(String uid) {
    final m = AppState.i.members[uid];
    final rec = m is Map ? m : (AppState.i.former[uid] is Map
        ? AppState.i.former[uid] as Map
        : null);
    final v = rec?['feeFree'];
    return v is List ? v.whereType<String>().toSet() : const {};
  }

  /// 아직 안 낸 달들 (모임 시작 달부터 이번 달까지).
  static List<String> unpaidMonths(String uid, {int maxBack = unpaidMaxBack}) {
    final fee = asMap(AppState.i.couple?['fee']);
    final amount = (fee['amount'] as num?)?.toInt() ?? 0;
    if (amount <= 0) return const [];
    final nowYm = ymOf(DateTime.now());
    final joinedAt = (AppState.i.members[uid] as Map?)?['joinedAt'] as num?;
    final joinedYm = joinedAt == null
        ? nowYm
        : ymOf(DateTime.fromMillisecondsSinceEpoch(joinedAt.toInt()));
    final free = feeFree(uid);
    final out = <String>[];
    for (var i = maxBack - 1; i >= 0; i--) {
      final ym = nowYm - i;
      if (ym < joinedYm) continue;
      final key = ymKey(ym);
      if (free.contains(key)) continue; // 면제해 준 달은 «밀린 것»이 아니다
      if (!paidIn(uid, key)) out.add(key);
    }
    return out;
  }

  /// 회비 N달치를 받았을 때 «어느 달들을 메울지» 고른다.
  ///
  /// 이미 낸 달은 **건너뛴다.** 중간 기록을 지웠거나 어느 한 달만 따로 낸 적이 있으면
  /// 안 낸 달이 띄엄띄엄해지는데, 그때 그냥 이어서 세면 이미 낸 달에 또 얹혀
  /// 회원이 낸 돈만큼 미납이 안 줄어든다 (그 달치를 두 번 낸 셈이 된다).
  static List<String> feeMonthsToFill(String uid, int months) {
    if (months <= 0) return const [];
    final unpaid = unpaidMonths(uid);
    final free = feeFree(uid);
    int startYm;
    if (unpaid.isNotEmpty) {
      final p = unpaid.first.split('-');
      startYm = int.parse(p[0]) * 12 + int.parse(p[1]) - 1;
    } else {
      startYm = ymOf(DateTime.now()) + prepaidLeft(uid) + 1;
    }
    final out = <String>[];
    // 넉넉히 앞으로 훑되(빈 달을 찾아), 끝없이 돌지는 않게 한계를 둔다
    for (var i = 0; out.length < months && i < months + 36; i++) {
      final key = ymKey(startYm + i);
      // 면제한 달에 돈을 채우면 «안 받은 돈»이 통장에 더해진다
      if (paidIn(uid, key) || free.contains(key)) continue;
      out.add(key);
    }
    return out;
  }

  /* 🧾 회비 기록이 «어느 달치»인지 — 장부 줄과 알림 문구가 같은 말을 하게 한다.
     ⚠️ 예전에는 장부 줄이 «두 달 이상일 때만» 기간을 보여 줬다.
        그래서 3월에 밀린 1월치를 받으면 줄에는 기록한 날(3월)만 남아,
        나중에 총무가 **어느 달치였는지 알 길이 없었다.**
        (알림 문구는 그때도 보여 줬다 — 남는 기록만 빠져 있었다) */
  static String? feeSpan(Object? months) {
    final m = (months is List) ? months.whereType<String>().toList() : const <String>[];
    if (m.isEmpty) return null;
    return m.length == 1 ? '${m.first}치' : '${m.first}~${m.last}치';
  }

  /// 선납으로 앞으로 몇 달이 채워져 있는지.
  static int prepaidLeft(String uid) {
    final nowYm = ymOf(DateTime.now());
    var n = 0;
    for (var i = 1; i <= 24; i++) {
      if (!paidIn(uid, ymKey(nowYm + i))) break;
      n++;
    }
    return n;
  }

  static int balance() {
    var sum = 0;
    for (final x in AppState.i.by('ledger')) {
      final amt = asInt(x['amount']);
      sum += x['kind'] == 'in' ? amt : -amt;
    }
    return sum;
  }

  // ─────────────────────────────── 배지

  /// 출석 횟수로 받는 배지 — 웹앱과 같은 기준.
  static const badges = <(int, String, String)>[
    (1, '🌱', '첫 출석'),
    (3, '🌿', '세 번째'),
    (5, '🍀', '다섯 번'),
    (10, '⭐', '열 번'),
    (20, '🌟', '스무 번'),
    (30, '🔥', '서른 번'),
    (50, '💎', '오십 번'),
    (70, '👑', '일흔 번'),
    (100, '🏆', '백 번'),
    (150, '🥇', '백오십 번'),
    (200, '🎖', '이백 번'),
  ];

  static List<(int, String, String)> badgesOf(int count) =>
      badges.where((b) => count >= b.$1).toList();

  static (int, String, String)? nextBadge(int count) {
    for (final b in badges) {
      if (count < b.$1) return b;
    }
    return null;
  }

  /// 게시판 차례 — «공지가 먼저», 그 안에서 새 글이 먼저.
  ///
  /// ⚠️ 예전에는 올린 때 하나로만 줄을 세워서, 운영진이 「📌 공지로 올리기」를 켜도
  /// **다음 글 하나만 올라오면 그대로 밀렸다.** 운영진만 켤 수 있는 스위치인데
  /// 글쓴이 이름 옆에 📌 를 그리는 것 말고는 하는 일이 없었다.
  static int byNotice(Map<String, dynamic> a, Map<String, dynamic> b) {
    final an = a['notice'] == true, bn = b['notice'] == true;
    if (an != bn) return an ? -1 : 1;
    return asInt(b['createdAt']).compareTo(asInt(a['createdAt']));
  }

  /* ⏳ 승인 대기 목록 — «신청한 차례»로 세운다(먼저 온 사람이 위).
     ⚠️ 예전에는 서버 묶음이 준 차례 그대로였다. 그건 **번호(uid) 순**이라 사실상 아무렇게나다:
        · 방장은 **누가 먼저 신청했는지 알 수 없고**
        · 새 신청이 올 때마다 줄이 «중간에 끼어들어» 순서가 뒤바뀐다.
        신청한 때(`requestedAt`)는 처음부터 적히고 있었는데 **어디에서도 쓰지 않았다.** */
  static List<Map<String, dynamic>> pendingList() {
    final out = AppState.i.pending.values
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    // 때가 안 적힌 옛 신청은 «가장 오래된 것»으로 본다 (0 이 먼저 온다)
    out.sort((a, b) => asInt(a['requestedAt']).compareTo(asInt(b['requestedAt'])));
    return out;
  }

  /// 신청한 지 얼마나 됐는지 — 오래 기다린 사람이 눈에 띄게.
  /// 「며칠」은 **날짜로** 센다(밤 11시 신청이 새벽 1시에 「어제」가 되도록).
  static String? waitedFor(Object? requestedAt, DateTime now) {
    final ms = asInt(requestedAt);
    if (!Store.isSaneTime(ms)) return null; // 없거나 말이 안 되는 값이면 아무 말 안 한다
    final at = DateTime.fromMillisecondsSinceEpoch(ms);
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(at.year, at.month, at.day))
        .inDays;
    if (days <= 0) return '오늘 신청';
    if (days == 1) return '어제 신청';
    return '$days일째 기다림';
  }

  /// 직책 목록 (프리셋 + 지금 쓰이는 직접 입력 직책).
  static List<String> allTitles() {
    final used = AppState.i.memberList
        .map((m) => m['title'] as String?)
        .whereType<String>()
        .where((t) => t.isNotEmpty && !titlePresets.contains(t));
    return [...titlePresets, ...used.toSet()];
  }
}
