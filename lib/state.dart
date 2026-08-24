import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'config.dart';
import 'store.dart';

/// 내 자리가 없어진 «이유» — 회원에게 할 말이 저마다 다르다.
enum SeatGone {
  /// 방장·운영진이 탈퇴 처리했다
  kicked,

  /// 가입 신청이 받아들여지지 않았다 (회원이었던 적이 없다)
  rejected,

  /// 내가 «새 폰»으로 자리를 옮겼다 — 지금 이 폰이 옛 폰이다
  moved,
}

/// 앱이 지금 알고 있는 것 — 웹앱(index.html)의 State를 옮긴 것.
/// 화면들은 이걸 지켜보다가 바뀌면 다시 그린다.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState i = AppState._();

  static const _profileKey = 'club_profile_v1';
  static const _lastMeKey = 'club_lastme';

  /// 내가 속한 모임과 내 자리 {code, slot(=내 uid), name}
  Map<String, dynamic>? profile;

  /// 모임 문서 전체 {title, members:{uid:{...}}, pending:{...}, theme, fee, ...}
  Map<String, dynamic>? couple;

  /// 대화 뺀 기록 + 최근 대화
  List<Map<String, dynamic>> items = [];

  String? get code => profile?['code'] as String?;
  String? get slot => profile?['slot'] as String?;

  Map<String, dynamic> get members =>
      (couple?['members'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get pending =>
      (couple?['pending'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get former =>
      (couple?['former'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic>? get me =>
      slot == null ? null : (members[slot] as Map?)?.cast<String, dynamic>();

  String get role => (me?['role'] as String?) ?? 'member';
  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'owner' || role == 'admin';
  bool get approved => me != null;

  /// 회비를 다루는 사람 — 방장이거나 총무 계열 직책.
  /// 총무가 아무도 없으면 운영진이 대신 맡는다 (모임이 멈추지 않게).
  bool get isTreasurer {
    if (isOwner) return true;
    final t = me?['title'] as String?;
    if (t != null && treasurerTitles.contains(t)) return true;
    final anyTreasurer = memberList.any((m) {
      final mt = m['title'] as String?;
      return mt != null && treasurerTitles.contains(mt);
    });
    return !anyTreasurer && isAdmin;
  }

  /// 회원 목록 — 방장 → 운영진 → 회원, 같은 권한이면 직책 순 → 가입 순.
  List<Map<String, dynamic>> get memberList {
    const rank = {'owner': 0, 'admin': 1, 'member': 2};
    int ti(Map m) {
      final t = m['title'] as String?;
      if (t == null || t.isEmpty) return 99;
      final idx = titlePresets.indexOf(t);
      return idx < 0 ? titlePresets.length : idx;
    }

    final list = members.values
        .whereType<Map>()
        .map((m) => m.cast<String, dynamic>())
        .where((m) => (m['uid'] as String?)?.isNotEmpty == true)
        .toList();
    list.sort((a, b) {
      final r = (rank[a['role']] ?? 2).compareTo(rank[b['role']] ?? 2);
      if (r != 0) return r;
      final t = ti(a).compareTo(ti(b));
      if (t != 0) return t;
      return ((a['joinedAt'] as num?) ?? 0).compareTo((b['joinedAt'] as num?) ?? 0);
    });
    return list;
  }

  /// 종류별로 나눠 둔 기록 — 화면 한 번 그리는 데 수십 번 불리므로 미리 갈라둔다.
  Map<String, List<Map<String, dynamic>>> _byCache = {};
  List<Map<String, dynamic>> by(String type) => _byCache[type] ?? const [];

  /// 두 묶음이 «같은 것들을 같은 차례로» 담고 있는지 (하나하나가 같은 물건인지로 본다)
  static bool _sameList(
      List<Map<String, dynamic>>? a, List<Map<String, dynamic>> b) {
    if (a == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  /* 번호로 한 건 찾기 — 답장 인용이 이걸 쓴다.
     예전에는 말풍선마다 «불러온 대화 전체»를 훑었다. 어차피 아래에서 한 번 도는 김에 표를 만들어 둔다. */
  Map<String, Map<String, dynamic>> _byId = {};
  Map<String, dynamic>? byId(String? id) => id == null ? null : _byId[id];

  void setItems(List<Map<String, dynamic>> arr) {
    items = arr;
    final m = <String, List<Map<String, dynamic>>>{};
    final ids = <String, Map<String, dynamic>>{};
    for (final x in arr) {
      (m[(x['type'] as String?) ?? '?'] ??= []).add(x);
      final id = x['id'];
      if (id is String) ids[id] = x;
    }
    // 대화는 시간 순이라야 화면이 맞는다 (State.by는 원래 정렬을 보장하지 않으니 여기서 맞춰둔다)
    m['msg']?.sort((a, b) =>
        ((a['createdAt'] as num?) ?? 0).compareTo((b['createdAt'] as num?) ?? 0));
    _byId = ids;
    /* ⚠️ 종류별 묶음이 «내용이 같으면» 앞의 것을 그대로 쓴다.
       출석·회비 표는 「그 묶음이 그대로인가」로 다시 만들지를 정하는데,
       매번 새 묶음을 주면 **대화 한 건이 올 때마다 표를 통째로 다시 만든다.**
       2026-08-23 실측(모임 8개·회원 20명·3년치): 대화 하나에 **131.6㎳** —
       표가 그대로면 49㎲다(2700배). 값싼 폰에서는 새 말이 올 때마다 화면이 걸린다.
       대화만 왔을 때는 일정·회비 기록의 «묶음 자체»가 손대지 않은 그대로라 이 검사가 통한다. */
    final prev = _byCache;
    _byCache = {
      for (final e in m.entries)
        e.key: _sameList(prev[e.key], e.value) ? prev[e.key]! : e.value
    };
    notifyListeners();
  }

  /* 서버 값은 «그대로»인데 화면만 다시 그려야 할 때 — 지금은 「날이 바뀌었을 때」다.
     ⚠️ 「다가오는 모임」·「지난 회차」·「이번 달 순위」·「밀린 달」은 모두 «오늘»을 기준으로 센다.
        그런데 자정에는 서버에서 아무것도 안 온다 → **다시 그릴 까닭이 없어 어제 것이 그대로 남는다.**
        (137회차의 「입력 중」과 같은 병 — 시간으로 정해지는 것은 스스로 깨워야 한다) */
  void refresh() => notifyListeners();

  void setCouple(Map<String, dynamic>? c) {
    couple = c;
    notifyListeners();
  }

  /// 입력중·읽음·접속·푸시토큰처럼 계속 바뀌는 값만 갱신한다.
  /// 이걸 쓰면 홈·회비·일정처럼 계산이 무거운 화면은 다시 그리지 않고,
  /// 이 값이 꼭 필요한 채팅 화면만 살짝 갱신된다.
  final live = ValueNotifier<int>(0);

  /// 지금 보고 있는 탭 (0=홈 1=채팅 …). 채팅을 보는 중에는 알림을 띄우지 않으려고 쓴다.
  int currentTab = 0;

  /// 알림을 눌러 들어왔을 때 열어야 할 탭 (0=홈 1=채팅 …).
  /// 화면이 아직 안 떴을 수도 있어 값으로 남겨두고, 탭 화면이 뜨면 집어간다.
  final openTab = ValueNotifier<int?>(null);

  void setCoupleLive(Map<String, dynamic>? c) {
    couple = c;
    live.value++;
  }

  /* 「내 자리가 없어졌다」의 **이유**. 셋은 회원에게 전혀 다른 일인데
     예전에는 한 문장(「모임 이용이 중지됐어요」)으로 뭉뚱그렸다:
       · 폰을 바꿔 옮긴 뒤 «옛 폰»을 열면 → 방장이 자기를 잘랐다고 오해한다
       · 가입 신청이 거절된 사람 → 쓴 적도 없는 「이용이 중지」라는 말을 듣는다
     서버에 이미 갈라 볼 값이 있다: 기기 이전은 `former[uid].movedTo` 를 남기고,
     탈퇴 처리는 `former[uid]` 만 남기며, 신청 거절은 `former` 에 아무것도 안 남긴다. */
  static SeatGone whyGone(Map<String, dynamic>? couple, String uid) {
    final all = couple?['former'];
    final f = all is Map ? all[uid] : null;
    if (f is! Map) return SeatGone.rejected;
    final to = f['movedTo'];
    return to is String && to.isNotEmpty && to != uid ? SeatGone.moved : SeatGone.kicked;
  }

  /// 탈퇴자 이름도 옛 글에 그대로 보이게 — former에 남겨둔 이름을 쓴다.
  String nameOf(String? uid) {
    if (uid == null) return '알 수 없음';
    final m = members[uid] as Map?;
    if (m != null) return (m['name'] as String?) ?? '회원';
    final f = former[uid] as Map?;
    if (f != null) return (f['name'] as String?) ?? '지난 회원';
    return '지난 회원';
  }

  String emojiOf(String? uid) {
    final m = members[uid] as Map?;
    if (m != null) return (m['emoji'] as String?) ?? defaultAvatar;
    final f = former[uid] as Map?;
    return (f?['emoji'] as String?) ?? defaultAvatar;
  }

  String? photoOf(String? uid) => (members[uid] as Map?)?['photo'] as String?;

  // ─────────────────────────────── 기기에 남기는 것

  /* 기기에 남은 «내 자리» 정보를 믿을 수 있는 모양으로 다듬는다.
     ⚠️ 이 값은 앱이 켜질 때 **가장 먼저** 읽히고, `code`·`slot` 은 곧바로 `as String?` 으로 읽힌다.
     글자가 아닌 값이 들어 있으면 그 자리에서 터지는데, 값이 **기기에 남아 있어
     껐다 켜도 계속 터진다** — 회원에게는 빠져나올 길이 없다.
     (서버에서 오는 값은 `Store.tidy`·`tidyCouple` 이 지키는데 이 자리만 비어 있었다)
     둘 중 하나라도 없으면 아예 «없는 것»으로 본다 → 가입 화면으로 가서 다시 시작할 수 있다. */
  static Map<String, dynamic>? tidyProfile(Object? raw) {
    if (raw is! Map) return null;
    String? str(Object? v) =>
        v is String ? v : (v is num || v is bool ? '$v' : null);
    final code = str(raw['code']);
    final slot = str(raw['slot']);
    if (code == null || code.isEmpty || slot == null || slot.isEmpty) return null;
    return {'code': code, 'slot': slot, 'name': str(raw['name']) ?? ''};
  }

  Future<void> loadProfile() async {
    final raw = Store.i.getStr(_profileKey);
    if (raw == null) return;
    try {
      profile = tidyProfile(jsonDecode(raw));
    } catch (_) {
      profile = null;
    }
  }

  Future<void> saveProfile(String code, String slot, String name) async {
    profile = {'code': code, 'slot': slot, 'name': name};
    await Store.i.setStr(_profileKey, jsonEncode(profile));
  }

  /* 방 하나치 «기억»을 통째로 비운다.
     ⚠️ `setItems` 가 세우는 것은 **하나도 빠짐없이** 여기에 있어야 한다.
        `_byId`(번호로 한 건 찾기)가 남아 있으면, 방을 비운 뒤에도 옛 방의 기록이
        번호로 그대로 나온다 — 답장 인용이 이걸 쓰므로 «없어진 모임의 대화»가
        인용으로 뜰 수 있다.
     (서버를 안 건드리므로 시험이 이 자리만 따로 부를 수 있다 —
      `clearProfile` 은 기기에 적힌 것도 지우느라 Firebase 가 필요하다.
      `test/room_reset_test.dart` 가 「세우는 자리 = 비우는 자리」 짝을 지킨다) */
  void resetRoom() {
    couple = null;
    items = [];
    _byCache = {};
    _byId = {};
    /* 「채팅 탭으로 가라」는 신호도 «그 방의 것»이다.
       ⚠️ 안 지우면 이렇게 된다: 모임을 나간 뒤 트레이에 남아 있던 옛 알림을 누르면
          신호가 1로 서는데 그때는 아무도 안 듣는다(본 화면이 없다) → 값이 그대로 남고,
          **나중에 «다른 모임»에 들어가는 순간 뜬금없이 채팅 탭이 열린다.**
       (나간 모임의 알림 자체는 134회차에 그치게 했지만, 이미 온 알림은 트레이에 남아 있다) */
    openTab.value = null;
  }

  Future<void> clearProfile() async {
    profile = null;
    resetRoom();
    await Store.i.remove(_profileKey);
    /* 「어디까지 읽었는지」도 함께 지운다.
       이 값은 모임과 상관없이 기기에 하나뿐이라, 안 지우면 **다음 모임에 그대로 따라간다.**
       나가기·탈퇴·방 없어짐 뒤에 다른 모임에 들어가면, 그 모임의 옛 대화가
       전부 「이미 읽음」으로 잡혀 안읽음 숫자가 0으로 나온다. */
    await Store.i.remove('club_seenchat');
    await Store.i.remove('club_seendiary');
    notifyListeners();
  }

  /// 마지막으로 쓰던 내 이름·아바타·생년월일 — 탈퇴·기기변경 뒤 다시 적지 않게.
  Map<String, dynamic> lastMe() {
    try {
      return (jsonDecode(Store.i.getStr(_lastMeKey) ?? '{}') as Map)
          .cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  /* ⚠️ 여기에 **방장 코드를 넣으면 안 된다.**
     예전에는 모임 코드를 적어 두고 가입 화면에 그대로 채웠는데, 그 코드는 «방장 코드»다
     (빈 방에 그 코드로 처음 들어오는 사람이 방장이 된다 — 그래서 총괄이 방장 맡을 분에게만 보낸다).
     탈퇴·기기변경 뒤 가입 화면을 열면 그 코드가 회원 눈앞에 그대로 떴다.
     게다가 칸 이름은 「모임 이름」인데 알아볼 수 없는 글자가 채워져 있어 헷갈리기도 했다.
     → 이제 **모임 이름**만 적어 둔다. 옛 'code' 값은 다음 저장 때 사라진다. */
  Future<void> saveLastMe({String? name, String? emoji, String? club, String? birth}) async {
    final prev = lastMe();
    await Store.i.setStr(
      _lastMeKey,
      jsonEncode({
        'name': name ?? prev['name'],
        'emoji': emoji ?? prev['emoji'],
        'club': club ?? prev['club'],
        'birth': birth ?? prev['birth'],
      }),
    );
  }

  // 읽음 표시용 — 어디까지 봤는지 (이 기기 기준)
  int get lastSeenChat => Store.i.getInt('club_seenchat');
  set lastSeenChat(int v) => Store.i.setInt('club_seenchat', v);
  int get lastSeenDiary => Store.i.getInt('club_seendiary');
  set lastSeenDiary(int v) => Store.i.setInt('club_seendiary', v);
}
