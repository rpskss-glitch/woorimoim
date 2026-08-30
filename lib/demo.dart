import 'dart:convert';
import 'dart:typed_data';

import 'demo_photos.dart';
import 'state.dart';
import 'store.dart';

/* 👀 체험 모드(둘러보기) — 가입·승인 없이 «샘플 모임»으로 앱 전체를 볼 수 있다.

   왜 필요한가
     · 새 회원이 「어떤 앱인지」 먼저 보고 가입을 정할 수 있다.
     · 스토어 심사원이 **승인을 기다리지 않고** 앱을 다 볼 수 있다.
       (가입 신청 → 방장 승인 대기 화면에서 막히면 애플이 2.1「미완성」으로 반려한다 — 실제로 겪은 사유)

   ⚠️ 이 동안에는 **서버에 아무것도 오가지 않는다.** 모든 읽기·쓰기가 이 안(메모리)에서 끝난다.
      쓰기를 막아 버리면 「눌러도 아무 일도 안 나는 앱」으로 보이므로,
      **화면에서는 진짜처럼 되고** 앱을 끄면 사라진다 (웹앱의 체험 모드와 같은 규칙).

   ⚠️ 갈래를 켜고 끄는 곳은 여기 하나뿐이다. `Store` 의 읽기·쓰기 자리마다 맨 위에서 이걸 묻는다 —
      한 자리라도 빠뜨리면 **체험 중에 진짜 서버로 글이 나간다.**
      (`test/demo_test.dart` 가 Store 의 모든 쓰기 자리가 이걸 묻는지 지켜본다) */
class Demo {
  Demo._();

  /// 지금 체험 모드인가
  static bool on = false;

  /// 체험용 방 코드·내 번호 (서버에 있는 값이 아니다)
  static const code = 'DEMO';
  static const uid = 'u_me';

  /// 기기에 남겨 두는 표시 — 앱을 껐다 켜도 체험이 이어지게
  static const key = 'club_demo';

  static Map<String, dynamic> _couple = {};
  static List<Map<String, dynamic>> _items = [];
  static void Function(Map<String, dynamic>?)? _coupleCb;
  static void Function(List<Map<String, dynamic>>)? _itemsCb;
  static int _n = 0;

  static String _id() => 'd${++_n}';
  static int get _now => DateTime.now().millisecondsSinceEpoch;

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  /// 「YYYY-MM」의 지난달
  static String _prevMonth(String ym) {
    final y = int.parse(ym.substring(0, 4)), m = int.parse(ym.substring(5));
    final p = m == 1 ? [y - 1, 12] : [y, m - 1];
    return '${p[0]}-${p[1].toString().padLeft(2, '0')}';
  }

  static String _dayFromNow(int n) {
    final d = DateTime.now();
    return _ymd(DateTime(d.year, d.month, d.day + n));
  }

  /// 체험 시작 — 샘플을 세우고 내 자리(방장)를 만든다.
  ///
  /// 방장으로 두는 까닭: 심사원·구경하는 사람이 **가입 승인·회비 기록·설정까지** 다 볼 수 있어야
  /// 「무엇을 하는 앱인지」가 한 번에 보인다.
  static void start() {
    on = true;
    _n = 0;
    _seed();
    AppState.i.profile = {'code': code, 'slot': uid, 'name': '김민수'};
    AppState.i.setCouple(_couple);
    AppState.i.setItems(_items);
    AppState.i.refresh();
  }

  /// 체험 끝 — 샘플을 통째로 버린다 (기기에도 남기지 않는다)
  static void stop() {
    on = false;
    _couple = {};
    _items = [];
    _coupleCb = null;
    _itemsCb = null;
    AppState.i.profile = null;
    AppState.i.resetRoom();
    // 알려 주지 않으면 화면이 그대로 남는다 — 나가기를 눌러도 아무 일도 안 나는 것처럼 보인다
    AppState.i.refresh();
  }

  /* 바뀐 것을 화면에 알린다.
     ⚠️ 구독을 건 사람이 없을 때도 **AppState 를 직접 갱신**한다 —
        `stopAll()` 뒤(설정에서 방을 옮기는 길목 등)에도 눌러서 한 일이 화면에 남아야 한다.
        구독이 있을 때는 그쪽으로만 보낸다(다듬기가 그 길에 걸려 있다). */
  static void _emitCouple() {
    final c = Map<String, dynamic>.from(_couple);
    final cb = _coupleCb;
    if (cb != null) return cb(c);
    AppState.i.setCouple(Store.tidyCouple(c));
  }

  static void _emitItems() {
    final a = _items.map((e) => Map<String, dynamic>.from(e)).toList();
    final cb = _itemsCb;
    if (cb != null) return cb(a);
    AppState.i.setItems(Store.tidy(a));
  }

  // ── Store 가 부르는 자리들 ────────────────────────────────────────
  static Map<String, dynamic> couple() => Map<String, dynamic>.from(_couple);

  static void subCouple(void Function(Map<String, dynamic>?) cb) {
    _coupleCb = cb;
    _emitCouple();
  }

  static void subItems(void Function(List<Map<String, dynamic>>) cb) {
    _itemsCb = cb;
    _emitItems();
  }

  static void stopAll() {
    _coupleCb = null;
    _itemsCb = null;
  }

  static String addItem(Map<String, dynamic> data, {String? docId}) {
    final id = docId ?? _id();
    _items.add({
      ...data,
      'id': id,
      'coupleId': code,
      'createdAt': data['createdAt'] ?? _now,
      'by': data['by'] ?? uid,
      'uid': uid,
    });
    _emitItems();
    return id;
  }

  static bool updateItem(String id, Map<String, dynamic> patch) {
    final i = _items.indexWhere((x) => x['id'] == id);
    if (i < 0) return false;
    _items[i] = _apply(_items[i], patch);
    _emitItems();
    return true;
  }

  static bool deleteItem(String id) {
    final before = _items.length;
    _items.removeWhere((x) => x['id'] == id);
    if (_items.length == before) return false;
    _emitItems();
    return true;
  }

  static bool applyItem(
      String id, Map<String, dynamic>? Function(Map<String, dynamic> cur) fn) {
    final i = _items.indexWhere((x) => x['id'] == id);
    if (i < 0) return false;
    final patch = fn(Map<String, dynamic>.from(_items[i]));
    if (patch == null) return false;
    _items[i] = _merge(_items[i], patch);
    _emitItems();
    return true;
  }

  static void setCouple(Map<String, dynamic> data) {
    _couple = _merge(_couple, data);
    _emitCouple();
  }

  static void patchCouple(Map<String, dynamic> patch) {
    _couple = _apply(_couple, patch);
    _emitCouple();
  }

  static bool applyCouple(
      Map<String, dynamic>? Function(Map<String, dynamic> cur) fn) {
    final patch = fn(Map<String, dynamic>.from(_couple));
    if (patch == null) return false;
    _couple = _merge(_couple, patch);
    _emitCouple();
    return true;
  }

  /* 체험 중에 고른 사진은 **그림 그 자체**로 들고 있는다(data:).
     서버 보관함에 못 올리므로 번호를 줄 수 없고, 화면은 `ClubPhoto.fromSrc` 가 data: 를 그릴 줄 안다. */
  static String keepPhoto(Uint8List bytes) =>
      'data:image/jpeg;base64,${base64Encode(bytes)}';

  static String? getPhoto(String? id) =>
      (id != null && id.startsWith('data:')) ? id : null;

  /* 「점 경로」 패치 (`votes.u_me` · `members.u_me.name`) — 서버 updateDoc 과 같은 뜻.
     null 은 **지우기**다(서버의 deleteField 와 짝).
     ⚠️ 한 단계만 풀면 안 된다 — 내 이름·아바타를 고치는 길이 `members.번호.name` 처럼
        **두 단계**다. 한 단계만 풀면 「u_me.name」이라는 이름의 칸이 새로 생기고,
        화면에는 아무 일도 안 일어난 것처럼 보인다(시험이 잡아 준 자리). */
  static Map<String, dynamic> _apply(
      Map<String, dynamic> cur, Map<String, dynamic> patch) {
    final out = Map<String, dynamic>.from(cur);
    patch.forEach((k, v) {
      final parts = k.split('.');
      if (parts.length == 1) {
        if (v == null) {
          out.remove(k);
        } else {
          out[k] = v;
        }
        return;
      }
      // 가는 길의 묶음들을 «새로 만들어» 갈아 끼운다 (원본을 그 자리에서 고치지 않게)
      final maps = <Map<String, dynamic>>[out];
      for (var i = 0; i < parts.length - 1; i++) {
        final cur = maps.last[parts[i]];
        maps.add(Map<String, dynamic>.from(
            cur is Map ? cur.cast<String, dynamic>() : <String, dynamic>{}));
      }
      final leaf = maps.last;
      if (v == null) {
        leaf.remove(parts.last);
      } else {
        leaf[parts.last] = v;
      }
      for (var i = maps.length - 1; i > 0; i--) {
        maps[i - 1][parts[i - 1]] = maps[i];
      }
    });
    return out;
  }

  /// 묶음 합치기 (서버 `set(merge:true)` 과 같은 뜻). `Store.del` 은 그 칸을 지운다.
  static Map<String, dynamic> _merge(
      Map<String, dynamic> cur, Map<String, dynamic> patch) {
    final out = Map<String, dynamic>.from(cur);
    patch.forEach((k, v) {
      if (v == Store.del) {
        out.remove(k);
        return;
      }
      if (v is Map && out[k] is Map) {
        out[k] = _merge((out[k] as Map).cast<String, dynamic>(),
            v.cast<String, dynamic>());
        return;
      }
      if (v is Map) {
        // 없던 자리에 «지우기»만 온 것은 버린다 (그 글자가 그대로 저장되지 않게)
        final m = v.cast<String, dynamic>()
          ..removeWhere((_, x) => x == Store.del);
        out[k] = m;
        return;
      }
      out[k] = v;
    });
    return out;
  }

  // ── 샘플 ────────────────────────────────────────────────────────
  static void _seed() {
    final t = _now;
    final today = _dayFromNow(0);
    final next = _dayFromNow(4);
    final last = _dayFromNow(-3);
    final month = today.substring(0, 7);
    String rk(String d, String u) => '${d}_$u';

    Map<String, dynamic> m(String u, String name, String emoji, String role,
            [String? title]) =>
        {
          'uid': u,
          'name': name,
          'emoji': emoji,
          'role': role,
          if (title != null) 'title': title,
          'joinedAt': t - 40 * 86400000,
        };

    _couple = {
      'code': code,
      'title': '앞산 배드민턴',
      'startDate': '2023-03-14',
      'theme': 'sky',
      'emblem': {'kind': 'emoji', 'emoji': '🏸', 'size': 1.2, 'rot': -18.0},
      'fee': {'day': 5, 'amount': 20000},
      'members': {
        uid: m(uid, '김민수', '🧑🏻', 'owner', '회장'),
        'u_yj': m('u_yj', '박영진', '🧔🏻', 'admin', '총무'),
        'u_sh': m('u_sh', '이서현', '👩🏻', 'member'),
        'u_mj': m('u_mj', '정민지', '👩🏻‍🦰', 'member'),
        'u_dh': m('u_dh', '강대현', '👨🏻', 'member', '경기이사'),
        'u_jh': m('u_jh', '최준혁', '🧑🏻‍🦱', 'member'),
      },
      'pending': {
        'u_new': {
          'uid': 'u_new',
          'name': '오하늘',
          'emoji': '🙂',
          'requestedAt': t - 3600000,
        }
      },
      'lastRead': {'u_yj': t, 'u_sh': t - 500000},
      'lastSeen': {'u_yj': t - 3 * 60000},
    };

    Map<String, dynamic> item(Map<String, dynamic> o, String by, int ago) => {
          ...o,
          'id': _id(),
          'coupleId': code,
          'by': by,
          'uid': by,
          'createdAt': t - ago,
        };

    _items = [
      item({'type': 'msg', 'text': '오늘 정기모임 7시! 코트 3번입니다 🏸'}, 'u_yj', 500000),
      item({'type': 'msg', 'text': '네! 셔틀콕 제가 챙겨갈게요'}, 'u_sh', 400000),
      item({'type': 'msg', 'text': '저 오늘 야근이라 30분 늦어요 🙏'}, 'u_jh', 300000),
      item({'type': 'msg', 'text': '천천히 오세요~ 몸 먼저 풀고 있을게요'}, uid, 200000),
      // 📊 투표 — 진행 중인 것과 마감된 복수선택
      item({
        'type': 'msg',
        'kind': 'poll',
        'text': '이번 주 토요일 번개 어때요?',
        'poll': {
          'q': '이번 주 토요일 번개 어때요?',
          'opts': ['오전 9시', '오후 2시', '저녁 7시'],
          'multi': false,
          'closed': false,
        },
        'votes': {
          'u_yj': [0],
          'u_sh': [2],
          'u_mj': [2],
          'u_dh': [1],
        },
      }, 'u_yj', 120000),
      item({
        'type': 'msg',
        'kind': 'poll',
        'text': '단체복 색 골라주세요 (여러 개 가능)',
        'poll': {
          'q': '단체복 색 골라주세요 (여러 개 가능)',
          'opts': ['남색', '흰색', '민트'],
          'multi': true,
          'closed': true,
        },
        'votes': {
          uid: [0, 2],
          'u_yj': [0],
          'u_sh': [0, 1],
          'u_jh': [2],
        },
      }, uid, 100000),
      // 📅 일정 — 매주 반복 모임(참석 투표·출석), 다가오는 대회 연습
      item({
        'type': 'event',
        'title': '정기 모임',
        /* ⚠️ 시작일을 «오늘»로 두면 지난 회차가 하나도 없어 **출석이 0번**으로 보인다
           (반복 모임은 시작일부터 세기 때문이다 — 에뮬레이터에서 실제로 그렇게 나왔다). */
        'date': last,
        'time': '19:00',
        'cat': 'meet',
        'place': '앞산 체육관 3코트',
        'repeat': 'week',
        'memo': '초보 레슨 30분 먼저',
        'rsvp': {
          rk(today, uid): 'yes',
          rk(today, 'u_yj'): 'yes',
          rk(today, 'u_sh'): 'yes',
          rk(today, 'u_mj'): 'maybe',
          rk(today, 'u_jh'): 'no',
        },
        // 지난 회차 출석 — 배지·이달의 순위가 «쓰는 모습»으로 보이게
        'attend': {
          rk(last, uid): true,
          rk(last, 'u_yj'): true,
          rk(last, 'u_sh'): true,
          rk(last, 'u_dh'): true,
        },
      }, 'u_yj', 3 * 86400000),
      item({
        'type': 'event',
        'title': '대회 연습',
        'date': next,
        'time': '10:00',
        'cat': 'game',
        'place': '앞산 체육관 전 코트',
        'rsvp': {rk(next, uid): 'yes', rk(next, 'u_sh'): 'yes'},
      }, uid, 86400000),
      // 📔 게시판
      item({
        'type': 'diary',
        'title': '겨울 체육관 대관 안내',
        'text': '12월부터 2월까지는 3코트에서 5코트로 늘립니다. 회비는 그대로예요!',
        'date': today,
        'tags': ['공지'],
      }, 'u_yj', 86400000),
      item({
        'type': 'diary',
        'title': '초보 레슨 같이 하실 분',
        'text': '정기모임 30분 전에 기초 스텝부터 봐드려요. 라켓 없으셔도 빌려드립니다 🏸',
        'date': last,
        'tags': ['모집'],
      }, 'u_sh', 86400000 + 3600000),
      item({
        'type': 'diary',
        'title': '3월 정기 대회 후기',
        'text': '우리 클럽 복식 2팀이 8강까지 올라갔습니다! 다음엔 더 잘해봐요 💪',
        'date': last,
        'tags': ['공지'],
      }, 'u_yj', 2 * 86400000),
      /* 📸 사진첩 — **비워 두면 안 된다.**
         체험 모드는 스토어 심사원이 보는 화면인데, 사진첩만 「아직 사진이 없어요」면
         「이 기능은 안 만들었나」로 읽혀 2.1(미완성)로 되돌려보낸다.
         ⚠️ 칸 모양은 **진짜로 올릴 때와 똑같이** 맞춘다(`board.dart` 의 올리는 자리):
            photoId(그림 그 자체) · thumb(작은 그림) · date.
            하나라도 다르면 체험에서만 되고 진짜에서는 안 되는 자리가 생긴다.
         ⚠️ 올린 사람을 서로 다르게 둔다 — 한 사람만 올린 것처럼 보이지 않게. */
      item({
        'type': 'photo',
        'photoId': demoPhotoCourt,
        'thumb': demoPhotoCourtThumb,
        'caption': '수요일 정기모임 3코트',
        'date': today,
      }, 'u_yj', 3600000),
      item({
        'type': 'photo',
        'photoId': demoPhotoTeam,
        'thumb': demoPhotoTeamThumb,
        'caption': '3월 정기 대회 8강! 🏆',
        'date': last,
      }, 'u_sh', 2 * 86400000),
      item({
        'type': 'photo',
        'photoId': demoPhotoGear,
        'thumb': demoPhotoGearThumb,
        'caption': '새로 산 셔틀콕',
        'date': last,
      }, uid, 2 * 86400000 + 3600000),
      // 💰 회비·지출
      /* ⚠️ 이월금이 없으면 통장이 «-216,000원»(빨간 글씨)으로 뜬다.
         체험 모드는 심사원이 보는 화면이자 스토어 그림이라, 빚진 모임처럼 보이면 안 된다.
         실제 동호회도 지난달 잔액을 이월해서 시작한다. */
      item({
        'type': 'ledger',
        'kind': 'in',
        'amount': 600000,
        'title': '지난달 이월금',
        'date': last,
      }, 'u_yj', 5 * 86400000),
      item({
        'type': 'ledger',
        'kind': 'in',
        'amount': 40000,
        'title': '회비 2개월치',
        'payer': uid,
        // 지난달까지 낸 것으로 — 안 그러면 첫 화면이 「1달 밀림」으로 뜬다
        'feeMonths': [_prevMonth(month), month],
        'months': 2,
        'date': today,
      }, uid, 86400000),
      item({
        'type': 'ledger',
        'kind': 'in',
        'amount': 20000,
        'title': '${int.parse(month.substring(5))}월 회비',
        'payer': 'u_yj',
        'feeMonths': [month],
        'months': 1,
        'date': today,
      }, 'u_yj', 86400000),
      item({
        'type': 'ledger',
        'kind': 'out',
        'amount': 240000,
        'title': '체육관 대관료',
        'cat': 'court',
        'date': last,
      }, 'u_yj', 3 * 86400000),
      item({
        'type': 'ledger',
        'kind': 'out',
        'amount': 36000,
        'title': '셔틀콕 2통',
        'cat': 'shuttle',
        'date': last,
      }, 'u_yj', 3 * 86400000),
    ];
  }
}
