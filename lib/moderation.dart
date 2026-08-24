import 'logic.dart';
import 'state.dart';

/* 🛡 회원이 올린 글·사진을 다루는 규칙 — 신고 · 차단 · 걸러내기 · 운영자 연락처.

   스토어가 요구하는 것이다(애플 1.2 사용자 생성 콘텐츠). 넷 중 하나라도 없으면 반려된다:
     ①부적절한 글 걸러내기 ②신고 ③차단 ④운영자 연락처.
   구글도 UGC 정책에서 같은 것을 본다.

   ⚠️ 차단은 **내 자리(members.내번호.blocked)** 에 적는다 — 서버 규칙이 제 자리만 고치게 열어 두었고,
      폰을 바꿔도 따라오며, 남의 차단 목록은 건드릴 수 없다.
   ⚠️ 차단은 **보는 쪽에서** 가린다. 서버에서 지우면 그 사람의 글이 다른 회원에게도 사라진다 —
      차단은 «나만 안 보는 것»이지 «지우는 것»이 아니다. */
class Moderation {
  Moderation._();

  /// 신고 사유 — 스토어가 「무엇을 신고하는지 고를 수 있어야 한다」고 본다
  static const reasons = <String>[
    '욕설·비방',
    '음란물',
    '광고·스팸',
    '사기·거래 유도',
    '개인정보 노출',
    '그 밖의 불쾌한 내용',
  ];

  /// 운영자 연락처 — 신고가 들어오면 여기로도 알린다
  static const contactEmail = 'rpskss@gmail.com';

  /* 🚫 거르는 말 — 심한 욕설만 최소로 둔다.
     ⚠️ 너무 넓게 잡으면 멀쩡한 말이 별표가 된다(「시발점」·「개나리」처럼).
        그래서 **낱말 경계 없이도 확실한 것**만 넣고, 애매한 것은 신고로 처리한다. */
  static const _bad = <String>[
    // ⚠️ 「시발」은 뺐다 — **시발점·시발역**처럼 멀쩡한 말이 별표가 된다(시험이 잡아 줬다).
    //    애매한 것은 걸러내기 대신 «신고»로 처리한다. 멀쩡한 말을 못 쓰게 만드는 쪽이 더 나쁘다.
    '씨발', '씨팔', '개새끼', '병신', '지랄', '좆같', '썅', '니미럴',
    'fuck', 'shit', 'asshole', 'bitch',
  ];

  /// 그 글에 거를 말이 들어 있나
  static bool hasBad(String? text) {
    final t = (text ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (t.isEmpty) return false;
    return _bad.any(t.contains);
  }

  /// 거를 말을 별표로 가린다 (지우지 않는다 — 무슨 말이었는지는 남겨야 신고가 된다)
  static String mask(String? text) {
    var out = text ?? '';
    for (final w in _bad) {
      out = out.replaceAll(
        RegExp(RegExp.escape(w), caseSensitive: false),
        '*' * w.length,
      );
    }
    return out;
  }

  /// 내가 차단한 사람들 (폰 바꾸기 전 번호도 «같은 사람»으로 본다)
  static Set<String> blocked() {
    final me = AppState.i.me;
    final raw = me == null ? null : me['blocked'];
    if (raw is! List) return const {};
    return raw.whereType<String>().map(Logic.liveUid).toSet();
  }

  /// 이 사람의 글을 가려야 하나
  static bool isBlocked(String? uid) {
    if (uid == null || uid.isEmpty) return false;
    final b = blocked();
    if (b.isEmpty) return false;
    return b.contains(Logic.liveUid(uid));
  }

  /// 차단한 사람의 글을 걸러낸 목록
  static List<Map<String, dynamic>> hide(List<Map<String, dynamic>> list) {
    final b = blocked();
    if (b.isEmpty) return list;
    return list.where((x) => !b.contains(Logic.liveUid((x['by'] as String?) ?? ''))).toList();
  }

  /// 차단 목록에 넣거나 뺀 «다음» 목록 (같은 사람이 두 번 들어가지 않게)
  static List<String> nextBlocked(String uid, bool on) {
    final cur = <String>{
      ...((AppState.i.me?['blocked'] is List)
          ? (AppState.i.me!['blocked'] as List).whereType<String>()
          : const <String>[])
    };
    if (on) {
      cur.add(uid);
    } else {
      // 폰 바꾸기 전 번호로 차단해 뒀을 수 있다 — 같은 사람이면 전부 뺀다
      cur.removeWhere((u) => Logic.liveUid(u) == Logic.liveUid(uid));
    }
    return cur.toList();
  }

  /// 나 자신은 차단할 수 없다 (차단해 버리면 내 글이 안 보여 어리둥절해진다)
  static bool canBlock(String? uid, String myUid) =>
      uid != null && uid.isNotEmpty && !Logic.isMe(uid, myUid);
}
