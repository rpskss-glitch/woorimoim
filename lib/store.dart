import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'demo.dart';
import 'fee.dart';

/// 서버 저장소 — 웹앱(index.html)의 Store를 그대로 옮긴 것.
///
/// 경로 구조 (웹앱과 동일해야 데이터가 이어진다):
///   artifacts/{appId}/public/data/couples/{code}   모임 문서
///   artifacts/{appId}/public/data/items/{id}       대화 뺀 모든 기록 (coupleId로 구분)
///   artifacts/{appId}/public/data/msgs/{id}        대화 (최근 것만 구독)
///   artifacts/{appId}/public/data/photos/{id}      Storage를 못 쓸 때의 사진 원본
class Store {
  Store._();
  static final Store i = Store._();

  /* ⚠️ 이 셋을 «필드»로 두면 안 된다 — `Store.i` 를 만지는 **그 순간** 파이어베이스를 붙잡는다.
     그러면 체험 모드(서버 없이 둘러보기)에서도 파이어베이스가 서 있어야 하고,
     화면 하나를 시험으로 띄우려 해도 「No Firebase App」으로 그 자리에서 터진다.
     (2026-08-29: 화면의 단추를 눌러 보는 시험을 짜다 걸렸다 — 아홉 화면 중 여덟이 못 떴다)
     쓸 때만 잡으면, 체험 모드는 `Demo.on` 검사에서 먼저 빠져나가므로 아예 안 부른다.
     `instance` 는 이미 만들어 둔 하나를 돌려주므로 매번 불러도 값이 안 든다. */
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseStorage get _st => FirebaseStorage.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  SharedPreferences? _prefs;

  /// 맵에서 키 하나를 지우라는 표시. 트랜잭션 안에서 쓰면 서버에서 FieldValue.delete()로 바뀐다.
  static const del = ' __DELETE__';

  static const msgWindow = 200; // 실시간으로 들고 있는 최근 대화 수

  /// 내 번호. 체험 모드에서는 로그인이 없으므로 «샘플 회원」의 번호를 쓴다
  /// (안 그러면 내 말·내 표가 하나도 내 것으로 안 잡혀 앱이 통째로 남의 것처럼 보인다).
  String get myUid {
    if (Demo.on) return Demo.uid;
    /* ⚠️ 파이어베이스가 안 서 있으면 이 자리에서 **터진다.**
       그러면 「내 것인가」를 묻는 화면들이 통째로 안 뜬다 — 대화방·회비·게시판 전부.
       내 번호를 모르는 것은 «고장»이 아니라 «아직 로그인 전»이다. 빈 값으로 돌려준다. */
    try {
      return _auth.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 앱 시작 준비. **로그인에 실패해도 예외를 밖으로 던지지 않는다.**
  /// (던지면 runApp까지 못 가서 앱이 흰 화면으로 죽는다 — 인터넷 없이 처음 켜면 실제로 그랬다)
  /// 돌려주는 값: 서버에 붙을 준비가 됐는지.
  Future<bool> init() async {
    _prefs = await SharedPreferences.getInstance();
    // 오프라인 캐시 — 앱을 다시 열 때 서버를 덜 부르니 읽기 요금이 줄어든다
    try {
      _db.settings = const Settings(
          persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
    } catch (_) {/* 이미 한 번 켜진 뒤면 다시 못 바꾼다 — 그대로 쓰면 된다 */}
    if (_auth.currentUser != null) return true;
    try {
      await _auth.signInAnonymously();
      return true;
    } catch (e) {
      _err(e, '첫 연결');
      return false;
    }
  }

  /// 인터넷이 돌아왔을 때 다시 시도한다.
  Future<bool> retryInit() => init();

  /* 🔗 저장 결과 매듭짓기.
     Firestore의 쓰기는 **서버가 받았다고 알려줄 때까지** 끝나지 않는다.
     인터넷이 없거나 신호가 약하면(체육관 지하 같은 곳) 그 기다림이 **영영 안 끝난다** →
     저장 창이 안 닫히고 「저장 중…」인 채로 멈춘다. 회원은 안 된 줄 알고 창을 닫았다가
     다시 눌러 **같은 기록이 두 번** 들어간다 (회비 장부면 금액이 어긋난다).
     ⚠️ 기다리지 않고 넘어가도 **자료는 안 잃는다** — 기기에 쌓아 뒀다가 연결되면 스스로 보낸다.
     그래서 「보냈다」가 아니라 「맡겼다」로 보고 화면을 진행시킨다. */
  static const _settleWait = Duration(seconds: 6);

  // Firebase 없이도 시험할 수 있게 static — 이 함수는 «기다리는 규칙»만 다룬다
  /* ⚠️ **약속을 «만드는 일»까지 이 안에서 한다.**
     예전에는 이미 만들어진 약속을 받았다 — `settle(ref.set(item), '저장')`.
     그런데 Firestore 는 값이 잘못돼 있으면 «거절»이 아니라 **그 줄에서 곧바로 터진다.**
     인자가 먼저 계산되므로 그 터짐이 이 그물 «밖»으로 새어,
       · 여기 들어오지도 못하고(횟수 0)
       · 방금 올린 사진 원본을 치우는 일도 안 하고(**매달 보관료**)
       · `if (!await …)` 같은 결과 확인 그물도 그대로 지나갔다.
     (데이트장부 702회차에 실측된 것 — 이 앱도 같은 모양이었다)
     그래서 «부르는 함수»를 받아 **만드는 것부터** 감싼다. */
  static Future<bool> settle(Future<void> Function() make, String what) async {
    var failed = false;
    final Future<void> p;
    try {
      p = make();
    } catch (e) {
      _err(e, what); // 만들다 터졌다 — «안 됐다»고 정직하게 돌려준다
      return false;
    }
    final done = p.then<Object?>((_) => null, onError: (Object e) => e);
    final r = await Future.any([
      done,
      Future<Object?>.delayed(_settleWait, () => 'wait'),
    ]);
    if (r == 'wait') {
      // 늦게라도 거절되면 그때 자국을 남긴다 (안 잡으면 「처리 안 된 오류」로 시끄럽다).
      // 일부러 기다리지 않는다 — 여기서 기다리면 6초 매듭이 뜻이 없어진다
      unawaited(done.then((e) {
        if (e != null) _err(e, what);
      }));
      return true;                     // 맡겼다 — 화면은 진행시킨다
    }
    if (r != null) { failed = true; _err(r, what); }
    return !failed;
  }

  /* 위 [settle]과 같은 규칙인데 **거절은 그대로 던진다.**
     화면들이 `try { await ... } catch { toast('저장 못했어요') }` 로 실패를 잡고 있어서,
     여기서 조용히 false 로 바꾸면 **실패가 아무 말 없이 지나간다** (더 나쁘다).
     · 6초 안에 거절 → 그대로 던짐 (지금처럼 catch 에 걸린다)
     · 6초 넘게 답 없음 → 조용히 끝냄 (기기에 쌓였다가 연결되면 스스로 간다) */
  static Future<void> settleVoid(Future<void> Function() make, String what) async {
    // 만드는 것부터 감싼다 — 위 `settle` 과 같은 까닭
    final Future<void> p;
    try {
      p = make();
    } catch (e) {
      _err(e, what);
      rethrow; // 이 자리는 «진짜 오류»를 던져 주기로 되어 있다
    }
    final done = p.then<Object?>((_) => null, onError: (Object e) => e);
    final r = await Future.any([
      done,
      Future<Object?>.delayed(_settleWait, () => 'wait'),
    ]);
    if (r == 'wait') {
      // 위와 같다 — 일부러 안 기다린다
      unawaited(done.then((e) {
        if (e != null) _err(e, what);
      }));
      return;
    }
    if (r != null) throw r;
  }

  CollectionReference<Map<String, dynamic>> col(String name) =>
      _db.collection('artifacts').doc(Cfg.appId).collection('public').doc('data').collection(name);

  DocumentReference<Map<String, dynamic>> docRef(String name, String id) => col(name).doc(id);

  /// 대화만 msgs로 따로 둔다 — items와 같이 두면 앱을 켤 때마다 전부 다시 읽는다(그만큼 요금).
  String colOf(String? type) => type == 'msg' ? 'msgs' : 'items';

  // ─────────────────────────────── 모임 문서

  /* 서버에서 온 모임 문서 한 건을 «앱이 믿을 수 있는 모양»으로 만든다.
     ⚠️ `getCouple` 은 이걸 거치는데 «이름으로 찾기»만 날것을 그대로 돌려주고 있었다.
        그 값을 **가입 화면**이 읽는다: `(x['members'] as Map?)` — 회원 목록이 글자·배열이면
        그 자리에서 터져 **가입 화면이 통째로 안 뜬다.** 들어오는 길은 하나로 모은다. */
  static Map<String, dynamic>? fromDoc(Map<String, dynamic>? data, String code) =>
      data == null ? null : tidyCouple({...data, 'code': code});

  Future<Map<String, dynamic>?> getCouple(String code) async {
    if (Demo.on) return tidyCouple(Demo.couple());
    final s = await docRef('couples', code).get();
    if (!s.exists) return null;
    return fromDoc(s.data(), code); // 들어오는 길은 한 곳으로
  }

  /* [sure] 는 «끝난 것을 확인해야만» 넘어가는 자리에 쓴다 — 못 끝내면 던진다.
     보통 저장은 「맡겼다」(6초 뒤 조용히 넘김)로 충분하다: 기기에 쌓였다가 연결되면 간다.
     그런데 **새 방 만들기**는 다르다. 총괄이 그 코드를 방장에게 «말이나 문자로» 전하기 때문에,
     실제로는 안 들어갔는데 「만들었어요」가 뜨면 **방장이 그 코드로 못 들어온다.**
     (120회차의 「방 지우기」와 같은 갈래 — 다음 걸음이 앞 걸음의 «확인»에 기대는 자리) */
  Future<void> setCouple(String code, Map<String, dynamic> data,
          {bool sure = false}) =>
      Demo.on
      ? Future.sync(() => Demo.setCouple(data))
      : sure
          ? mustSettle(
              () => docRef('couples', code).set(data, SetOptions(merge: true)),
              '모임 저장')
          : settleVoid(
              () => docRef('couples', code).set(data, SetOptions(merge: true)),
              '모임 저장');

  /* 🚩 신고 — 그 방 운영진이 볼 수 있게 기록으로 남긴다.
     ⚠️ 신고한 사람이 누구인지도 남긴다(장난 신고를 가려내려면 필요하다).
        대신 신고 «내용»은 그 방 운영진만 보게 화면에서 가린다. */
  Future<bool> reportContent(String code, {
    required String targetId,
    required String targetBy,
    required String reason,
    String? snippet,
  }) async {
    final id = await addItem(code, {
      'type': 'report',
      'targetId': targetId,
      'targetBy': targetBy,
      'reason': reason,
      'text': (snippet ?? '').length > 200 ? snippet!.substring(0, 200) : (snippet ?? ''),
      'done': false,
    });
    return id != null;
  }

  /// 🚫 차단 — **내 자리에만** 적는다(남의 글을 지우는 것이 아니라 내가 안 보는 것)
  Future<bool> setBlocked(String code, List<String> list) async {
    try {
      await patchCouple(code, {'members.$myUid.blocked': list}, sure: true);
      return true;
    } catch (e) {
      _err(e, '차단');
      return false;
    }
  }

  /* 🗑 내 자료 지우기 — 스토어가 요구하는 «앱 안에서의 계정 삭제»(애플 5.1.1(v)).
     지우는 것: 회원 자리(이름·생년월일·아바타), 알림 토큰, 읽음·접속 표시, 이 기기의 프로필.
     남는 것: 이미 쓴 대화·글·사진 — 모임의 «함께 쓴 기록»이라 지우면 남의 대화가 구멍이 난다.
              대신 이름은 `former` 에만 남아 「탈퇴한 회원」으로 보인다. 그것까지 지우려면
              운영자에게 요청하면 된다(개인정보 처리방침에 그렇게 적어 두었다). */
  Future<bool> deleteMyData(String code) async {
    final uid = myUid;
    try {
      final c = await getCouple(code);
      final me = (c?['members'] as Map?)?[uid];
      final name = (me is Map ? me['name'] : null) as String?;
      final emoji = (me is Map ? me['emoji'] : null) as String?;
      await patchCouple(code, {
        'members.$uid': null,
        'push.$uid': null,
        'lastRead.$uid': null,
        'lastSeen.$uid': null,
        'typing.$uid': null,
        // 옛 글에 이름이 보이도록 이름·아바타만 남긴다 (지우면 「알 수 없는 사람」이 된다)
        'former.$uid': {
          'uid': uid,
          if (name != null) 'name': name,
          if (emoji != null) 'emoji': emoji,
          'leftAt': DateTime.now().millisecondsSinceEpoch,
        },
      }, sure: true);
      return true;
    } catch (e) {
      _err(e, '내 자료 지우기');
      return false;
    }
  }

  /* 💳 영수증을 **서버에** 넘겨 확인받는다 — 서버만이 `paidUntil` 을 적을 수 있다.
     ⚠️ 앱이 직접 적으면 폰에서 고쳐 쓰거나 가짜 영수증으로 그대로 뚫린다.
     ⚠️ 실패해도 «다시 결제하라»고 하면 안 된다(두 번 결제된다) — 부르는 쪽이 「구매 복원」으로 안내한다. */
  Future<bool> verifySubscription({
    required String code,
    required String productId,
    required String token,
    required String source,
  }) async {
    if (Demo.on) return false;
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('verifySubApsan');
      final r = await fn.call<Map<String, dynamic>>({
        'code': code,
        'productId': productId,
        'token': token,
        'source': source,
      });
      return r.data['ok'] == true;
    } catch (e) {
      _err(e, '이용권 확인');
      return false;
    }
  }

  /* ➕ 새 모임 만들기 — 아무도 안 쓰는 6자리 코드를 찾아 준다.
     ⚠️ 이미 있는 코드에 덮어쓰면 **남의 모임이 통째로 날아간다.** 그래서 «없는 것»을 확인하고 돌려준다. */
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 헷갈리는 I·O·0·1 은 뺀다
  Future<String?> freeCode() async {
    for (var i = 0; i < 6; i++) {
      final b = StringBuffer();
      for (var k = 0; k < 6; k++) {
        b.write(_codeChars[(DateTime.now().microsecondsSinceEpoch + k * 7919 + i * 104729) %
            _codeChars.length]);
      }
      final code = b.toString();
      if (code == 'META') continue;
      if (await getCouple(code) == null) return code;
    }
    return null;
  }

  /// 새 모임 문서를 만든다 (만든 사람이 방장). 이미 있으면 **덮어쓰지 않고** 실패로 돌려준다.
  Future<bool> createClub(String code, Map<String, dynamic> data) async {
    if (Demo.on) return false; // 체험 중에는 진짜 모임을 만들지 않는다
    try {
      return await settle(() => docRef('couples', code).set(data), '모임 만들기');
    } catch (e) {
      _err(e, '모임 만들기');
      return false;
    }
  }

  /// 모임 이름 저장 — 「찾기용 이름」(띄어쓰기·대소문자 없앤 것)도 같이 적어 둔다.
  ///
  /// 이게 없으면 이름으로 찾을 때 총괄 목록(META)을 뒤져야 하는데,
  /// **방장은 총괄 목록을 고칠 권한이 없어** 이름을 바꿔도 목록에는 옛 이름이 남는다.
  /// 그러면 띄어쓰기가 다른 회원이 새 이름으로는 영영 못 찾는다.
  Future<void> setClubTitle(String code, String title,
          [Map<String, dynamic>? more, bool sure = false]) =>
      setCouple(code, {'title': title, 'titleKey': normTitle(title), ...?more},
          sure: sure);

  /// 맵에서 키를 지울 때 — set(merge)로는 삭제가 안 돼서 점 경로 + FieldValue.delete()를 쓴다.
  /// patch 예: {'pending.abc123': null, 'members.abc123': {...}}  (null = 그 키 삭제)
  Future<void> patchCouple(String code, Map<String, dynamic> patch,
      {bool sure = false}) async {
    if (Demo.on) return Demo.patchCouple(patch);
    final p = <String, Object?>{};
    patch.forEach((k, v) => p[k] = v ?? FieldValue.delete());
    final ref = docRef('couples', code);
    Future<void> put() =>
        sure
            ? mustSettle(() => ref.update(p), '고치기')
            : settleVoid(() => ref.update(p), '고치기');
    try {
      await put();
    } on FirebaseException catch (e) {
      // 문서가 아직 없으면(예: META 첫 기록) 만들고 다시
      if (e.code == 'not-found') {
        await settleVoid(() => ref.set({}, SetOptions(merge: true)), '만들기');
        await put();
      } else {
        rethrow;
      }
    }
  }

  /// 내 회원 칸을 고칠 때 — **바꾸는 항목만** 점 경로로 쓴다.
  /// 칸을 통째로 쓰면({'members.<내 번호>': {...화면에 담아둔 것}}) 내가 «전에 본 모습»이
  /// 서버에 그대로 덮인다. 그 사이 방장이 내 직책·권한을 바꿨다면
  /// 그게 사라지거나(방장 자리가 비어 규칙이 열려 있을 때), 규칙에 막혀
  /// **이름 저장이 까닭 없이 실패한다.** 항목별로 쓰면 서로 부딪히지 않는다.
  static Map<String, dynamic> memberPatch(
          String uid, Map<String, dynamic> fields) =>
      {for (final e in fields.entries) 'members.$uid.${e.key}': e.value};

  /// 여럿이 동시에 고쳐도 서로 덮어쓰지 않게 — 읽고→고치고→쓰기를 한 덩어리로 처리한다.
  /// [fn]이 null을 돌려주면 아무것도 쓰지 않는다 (예: 이미 다른 기기가 먼저 처리함).
  ///
  /// [createIfMissing] 은 «없으면 새로 만들지» — 기본은 **안 만든다.**
  /* ⚠️ 이게 없을 때, 총괄이 방을 지운 «그 순간» 회원이 「내가 방장 맡기」를 누르거나
     총괄이 「방장 자리 열기」를 누르면, 없는 문서에 그대로 써서 **지운 방이 되살아났다.**
     되살아난 방은 총괄 목록(META)에는 없어서 콘솔에 안 보이고 —— 지울 수도 없다.
     (기록은 이미 다 지워졌으니 텅 빈 방이 영영 남는다)
     `mutateItem` 은 처음부터 `!s.exists` 면 안 쓴다 — 여기만 빠져 있었다.
     만들어야 하는 자리는 총괄 등록 문서(META) 하나뿐이라 그때만 켜서 쓴다. */
  Future<bool> mutateCouple(
    String code,
    Map<String, dynamic>? Function(Map<String, dynamic> cur) fn, {
    bool createIfMissing = false,
  }) async {
    if (Demo.on) return Demo.applyCouple(fn);
    final ref = docRef('couples', code);
    var wrote = false;
    await _db.runTransaction((tx) async {
      /* ⚠️ 트랜잭션 덩어리는 부딪히면 **처음부터 다시 돈다.**
         밖에 둔 표시를 맨 위에서 되돌리지 않으면 앞선 시도의 결과가 남아
         «아무것도 안 썼는데 됐다»고 돌려주게 된다. */
      wrote = false;
      final s = await tx.get(ref);
      if (!s.exists && !createIfMissing) return; // 지운 방을 되살리지 않는다
      final patch = fn(s.exists ? s.data()! : {});
      if (patch == null) return;
      tx.set(ref, _withDelete(patch), SetOptions(merge: true));
      wrote = true;
    });
    return wrote;
  }

  /// del 표시를 Firestore의 삭제 명령으로 바꾼다 (중첩 맵 안까지).
  Map<String, dynamic> _withDelete(Map<String, dynamic> patch) {
    Object? walk(Object? v) {
      if (v == del) return FieldValue.delete();
      if (v is Map<String, dynamic>) {
        return v.map((k, x) => MapEntry(k, walk(x)));
      }
      return v;
    }

    return patch.map((k, v) => MapEntry(k, walk(v)));
  }

  /* **끝난 것을 확인해야만** 다음으로 갈 수 있는 자리에 쓴다.
     [settle]은 6초가 지나면 「맡겼다」로 보고 참을 돌려준다 — 대부분은 그게 맞다.
     그런데 방 지우기는 «기록을 다 지운 뒤»에 방 문서를 지우는데, 방 문서가 먼저 없어지면
     규칙상 아무도 남은 기록에 손댈 수 없어 **영영 남는다**. 그러니 여기서는
     「맡겼다」로 넘어가면 안 되고, 못 끝냈으면 **던져서 멈춰야** 한다. */
  static Future<void> mustSettle(Future<void> Function() make, String what,
      {Duration wait = _settleWait}) async {
    // 만드는 것부터 감싼다 — 위 `settle` 과 같은 까닭
    final Future<void> p;
    try {
      p = make();
    } catch (e) {
      _err(e, what);
      rethrow;
    }
    final done = p.then<Object?>((_) => null, onError: (Object e) => e);
    final r = await Future.any([
      done,
      Future<Object?>.delayed(wait, () => 'wait'),
    ]);
    if (r == 'wait') {
      // 늦게 온 거절도 받아 둔다 (안 잡으면 「처리 안 된 오류」로 시끄럽다)
      unawaited(done.then((e) {
        if (e != null) _err(e, what);
      }));
      throw StateError('$what: 서버가 답이 없어 멈췄어요');
    }
    if (r != null) throw r;
  }

  /// 방 문서 지우기 — 날것으로 부르면 신호가 끊겼을 때 화면이 영영 안 끝난다.
  Future<void> deleteCouple(String code) =>
      settleVoid(() => docRef('couples', code).delete(), '방 지우기');

  /// 모임 이름은 대소문자·띄어쓰기를 무시하고 견준다 — 회원이 이름만 듣고 찾아오기 때문.
  static String normTitle(String? s) =>
      (s ?? '').replaceAll(RegExp(r'\s+'), '').toLowerCase();

  /* 🏸 **이 앱이 보는 방을 전부** 돌려준다 — 「방이 하나뿐인가」를 판단하는 데 쓴다.
     방이 하나뿐이면 가입 화면에서 모임 이름을 물어볼 까닭이 없다.
     ⚠️ 못 읽었을 때 **빈 목록을 돌려주면 안 된다.** 그러면 「방이 없다」로 잘못 읽어
        칸을 숨긴 채 아무 데도 못 들어가게 된다 — 못 읽었으면 null 이다. */
  Future<List<Map<String, dynamic>>?> allClubs() async {
    if (Demo.on) return null; // 체험 중에는 서버 목록을 묻지 않는다
    try {
      final s = await col('couples').get();
      final out = <Map<String, dynamic>>[];
      for (final d in s.docs) {
        if (d.data()['isMeta'] == true) continue;
        final c = fromDoc(d.data(), d.id);
        if (c != null) out.add(c);
      }
      return out;
    } catch (e) {
      _err(e, '모임 목록');
      return null; // 못 읽었다 — «없다»와 구분한다
    }
  }

  /// 🔎 모임을 "이름"으로 찾는다. 서버 조회로 못 찾으면 총괄 목록(META)에서 띄어쓰기 무시로 다시 찾는다.
  Future<List<Map<String, dynamic>>> findClubByTitle(String name) async {
    final out = <String, Map<String, dynamic>>{};
    try {
      // 「찾기용 이름」으로 찾으면 띄어쓰기·대소문자가 달라도 한 번에 걸린다
      var s = await col('couples').where('titleKey', isEqualTo: normTitle(name)).get();
      if (s.docs.isEmpty) {
        // 찾기용 이름이 아직 없는 옛 모임 — 적힌 이름 그대로 다시 찾아본다
        s = await col('couples').where('title', isEqualTo: name.trim()).get();
      }
      for (final d in s.docs) {
        if (d.data()['isMeta'] == true) continue;
        // ⚠️ 날것을 그대로 넘기면 가입 화면이 그 값을 읽다가 터진다 — 여기서 한 번 다듬는다
        final c = fromDoc(d.data(), d.id);
        if (c != null) out[d.id] = c;
      }
    } catch (e) {
      // 조용히 넘어가면 회원에게는 「그 이름의 모임을 찾지 못했어요」로만 보여서
      // 권한·색인 문제인지 정말 없는 것인지 알 길이 없다 → 자국은 남긴다
      _err(e, '이름으로 모임 찾기');
    }
    if (out.isNotEmpty) return out.values.toList();

    final meta = await getCouple('META');
    final clubs = (meta?['clubs'] as Map?)?.cast<String, dynamic>() ?? {};
    final want = normTitle(name);
    for (final e in clubs.entries) {
      final t = (e.value as Map?)?['title'];
      if (normTitle(t as String?) != want) continue;
      final c = await getCouple(e.key);
      if (c != null && c['isMeta'] != true) out[e.key] = c;
    }
    return out.values.toList();
  }

  /// 💰 기기를 바꿔 이어받을 때 — 회비 납부 기록의 payer를 새 uid로 옮긴다.
  /// (안 옮기면 새 폰에서 이번 달 회비가 미납으로 보인다)
  Future<int> migrateFeePayer(String code, String from, String to) async {
    var n = 0;
    try {
      final s = await col('items')
          .where('coupleId', isEqualTo: code)
          .where('kind', isEqualTo: 'in')
          .where('payer', isEqualTo: from)
          .get();
      var failed = 0;
      for (final d in s.docs) {
        try {
          await d.reference.update({'payer': to});
          n++;
        } catch (_) {
          failed++; // 한 건씩 조용히 넘기면 그 달만 «미납»으로 남는데 아무도 모른다
        }
      }
      if (failed > 0) {
        _err('회비 기록 $failed건은 새 기기로 못 옮겼어요 — 그 달은 미납으로 보입니다',
            '회비 주인 옮기기');
      }
    } catch (e) {
      // 조용히 넘기면 새 폰에서 이번 달 회비가 «미납»으로 보이는데 아무도 이유를 모른다
      _err(e, '회비 주인 옮기기');
    }
    return n;
  }

  // ─────────────────────────────── 구독

  StreamSubscription? _coupleSub;
  StreamSubscription? _itemsSub, _msgsSub;

  /// 같은 종류를 두 번 걸면 읽기 요금이 그대로 두 배가 된다 — 다시 걸 때 앞의 것을 반드시 끊는다.
  void stopAll() {
    if (Demo.on) return Demo.stopAll();
    _coupleSub?.cancel();
    _itemsSub?.cancel();
    _msgsSub?.cancel();
    _coupleSub = _itemsSub = _msgsSub = null;
    _itemsCb = null;
    _core = [];
    _recent = [];
    _older = [];
    _curRecent = _curOlder = null;
    /* 「더 보기」 상태도 반드시 같이 지운다 — 안 지우면 옛 방의 값이 남아,
       대화가 몇 건 없는 방에 들어가도 첫 스냅샷이 오기 전까지 단추가 떠 있다.
       눌러 봐야 커서가 비어 있어 아무것도 안 나온다(헛걸음). */
    _hasMore = false;
    _noMoreOlder = false;
  }

  void subCouple(String code, void Function(Map<String, dynamic>?) cb) {
    if (Demo.on) return Demo.subCouple((c) => cb(tidyCouple(c)));
    _coupleSub?.cancel();
    // 들어오는 길목에서 한 번만 정리한다 — 받는 쪽마다 챙기면 언젠가 한 곳을 빠뜨린다
    _coupleSub = docRef('couples', code).snapshots().listen(
      (s) => cb(tidyCouple(s.exists ? {...s.data()!, 'code': code} : null)),
      onError: (e) => _err(e),
    );
  }

  List<Map<String, dynamic>> _core = [];
  List<Map<String, dynamic>> _recent = [];
  List<Map<String, dynamic>> _older = [];
  DocumentSnapshot? _curRecent, _curOlder; // 「더 보기」용 문서 커서
  bool _hasMore = false;
  /// 옛 대화를 끝까지 불러왔는지. 새 대화가 와서 창이 다시 차더라도
  /// 「더 보기」 단추가 되살아나지 않게 따로 기억한다(눌러도 아무것도 안 나오면 헛걸음이다).
  bool _noMoreOlder = false;

  /// 화면에 기록을 알려줄 통로 — 「더 보기」로 옛 대화를 받았을 때도 이걸로 알린다.
  void Function(List<Map<String, dynamic>>)? _itemsCb;

  void subItems(String code, void Function(List<Map<String, dynamic>>) cb) {
    if (Demo.on) return Demo.subItems((a) => cb(tidy(a)));
    _itemsSub?.cancel();
    _msgsSub?.cancel();
    _itemsCb = cb;
    _core = [];
    _recent = [];
    _older = [];
    _curRecent = _curOlder = null;
    _hasMore = false;
    _noMoreOlder = false;

    void emit() => _emit();

    // ① 대화 말고 나머지 — 개수가 많지 않고 앱 곳곳에서 필요해서 전부 듣는다
    _itemsSub = col('items').where('coupleId', isEqualTo: code).snapshots().listen((s) {
      _core = tidy(s.docs.map((d) => {...d.data(), 'id': d.id}).toList());
      emit();
    }, onError: (e) => _err(e));

    // ② 대화는 최근 것만
    _msgsSub = col('msgs')
        .where('coupleId', isEqualTo: code)
        .orderBy('createdAt', descending: true)
        .limit(msgWindow)
        .snapshots()
        .listen((s) {
      _curRecent = s.docs.isEmpty ? null : s.docs.last; // desc라 마지막 = 창에서 가장 오래된 것
      final next =
          tidy(s.docs.map((d) => {...d.data(), 'id': d.id}).toList().reversed.toList());
      /* ⚠️ 「이전 대화 더 보기」를 한 뒤에는 **창 밖으로 밀려난 대화를 붙들어야 한다.**
         새 대화가 하나 오면 창(최근 200개)에서 가장 오래된 것이 하나 밀려나는데,
         그건 「더 보기」로 가져온 묶음보다 «새것»이라 그 묶음에도 없다 →
         화면 중간에서 대화가 **소리 없이 사라진다.** (새 대화가 올 때마다 하나씩)
         지운 대화까지 되살리지 않도록, **새 창의 가장 오래된 것보다 더 오래된 것**만 옮긴다. */
      if (_older.isNotEmpty) {
        final fell = fellOutOfWindow(_recent, next);
        if (fell.isNotEmpty) _older = [..._older, ...fell];
      }
      _recent = next;
      _hasMore = s.docs.length >= msgWindow;
      emit();
    }, onError: (e) => _err(e, 'msgs'));
  }

  /// 창(최근 200개) 밖으로 «밀려난» 대화만 골라낸다 — 지운 대화는 빼고.
  ///
  /// 가려내는 법: 밀려난 것은 반드시 **새 창의 가장 오래된 것보다 더 오래된 것**이다.
  /// 중간에서 지워진 대화는 그보다 새것이라 걸러진다.
  /// (둘 다 스냅샷에서는 「없어짐」으로 똑같이 보이기 때문에 시각으로 가른다)
  static List<Map<String, dynamic>> fellOutOfWindow(
    List<Map<String, dynamic>> prev,
    List<Map<String, dynamic>> next,
  ) {
    if (prev.isEmpty || next.isEmpty) return const [];
    final keep = next.map((m) => m['id']).toSet();
    final edge = (next.first['createdAt'] as num?)?.toInt() ?? 0;
    return prev
        .where((m) =>
            !keep.contains(m['id']) &&
            ((m['createdAt'] as num?)?.toInt() ?? 0) < edge)
        .toList();
  }

  /// 지금 들고 있는 기록을 화면에 알린다 (같은 id는 한 번만).
  /* ⚠️ 여기서 `tidy` 를 부르면 안 된다 — **이미 다듬어 둔 것을 매번 또 다듬는다.**
     이 자리는 대화 한 건이 올 때마다 도는데, 그때 기록 «전부»(사진·회비·일정까지)를
     다시 훑게 된다. 2026-08-24 실측(기록 950건, 사진 300장에 작은 그림 포함):
     대화 한 건에 **7.2㎳** — 값싼 폰이면 서너 배라 한 프레임(16.7㎳)을 넘겨 말이 올 때마다 끊긴다.
     다듬기는 **제자리에서** 고치므로 «만드는 곳에서 한 번»이면 된다
     (`_core`·`_recent`·`_older` 세 곳 + 옛 대화 한 건 맞추기). */
  void _emit() {
    final cb = _itemsCb;
    if (cb == null) return;
    final seen = <String>{};
    final all = <Map<String, dynamic>>[];
    for (final x in [..._core, ..._older, ..._recent]) {
      if (seen.add(x['id'] as String)) all.add(x);
    }
    cb(all);
  }

  bool hasOlder() => !Demo.on && _hasMore && !_noMoreOlder;

  /// ↑ 이전 대화 더 보기 — 실제로 위로 올릴 때만 가져온다 (평소엔 요금이 안 나가게).
  /// 값(시각) 커서는 같은 밀리초에 온 대화를 건너뛰므로 문서 커서로 이어붙인다.
  Future<int> loadOlder(String code, {int n = 200}) async {
    if (Demo.on) return 0;
    final cur = _curOlder ?? _curRecent;
    if (cur == null) return 0;
    final s = await col('msgs')
        .where('coupleId', isEqualTo: code)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(cur)
        .limit(n)
        .get();
    _hasMore = s.docs.length >= n;
    if (s.docs.length < n) _noMoreOlder = true;   // 이번에 끝까지 긁었다
    if (s.docs.isEmpty) return 0;
    _curOlder = s.docs.last;
    _older = [
      ...tidy(s.docs.map((d) => {...d.data(), 'id': d.id}).toList().reversed.toList()),
      ..._older,
    ];
    // 불러오기만 하고 알리지 않으면 화면에는 그대로 안 나온다 (실제로 「더 보기」가 먹통이었다)
    _emit();
    return s.docs.length;
  }

  List<Map<String, dynamic>> get older => _older;
  List<Map<String, dynamic>> get recent => _recent;

  /* ⚠️ 「↑ 이전 대화 더 보기」로 펼친 옛 대화는 **실시간 창(최근 200개) 밖**이다.
     그래서 그 대화를 지우거나 반응을 남겨도 화면이 **하나도 안 바뀐다** —
     내가 지운 대화가 내 화면에 그대로 남아 「안 지워졌나」 하고 다시 누르고,
     반응은 눌러도 하트가 안 붙어 계속 눌러 서버에서 켰다 껐다만 한다.
     그 «한 건»만 서버와 다시 맞춘다 (읽기 1번 — 회원이 실제로 손댔을 때만 나간다). */
  static List<Map<String, dynamic>> applyToOlder(
    List<Map<String, dynamic>> older,
    String id,
    Map<String, dynamic>? fresh,
  ) {
    if (fresh == null) return older.where((m) => m['id'] != id).toList();
    return older.map((m) => m['id'] == id ? fresh : m).toList();
  }

  Future<void> syncOlder(String id, String? type, {bool removed = false}) async {
    if (Demo.on) return; // 체험에는 «창 밖 대화»가 없다
    if (!_older.any((m) => m['id'] == id)) return; // 창 안이면 구독이 알아서 고쳐 준다
    if (removed) {
      _older = applyToOlder(_older, id, null);
      return _emit();
    }
    try {
      final s = await docRef(colOf(type), id).get();
      _older = applyToOlder(_older, id,
          s.exists ? tidy([{...s.data()!, 'id': id}]).first : null);
    } catch (e) {
      return _err(e, '옛 대화 맞추기');
    }
    _emit();
  }

  // ─────────────────────────────── 기록 (items / msgs)

  static const _dateTypes = {'diary', 'photo', 'event', 'ledger', 'dday'};
  static const _numFields = {
    'ledger': ['amount', 'months']
  };

  /* ⚠️ 아래 세 가지는 「기록 하나가 망가지면 **화면이 통째로 안 뜨는**」 것을 막는다.
     Dart는 `x['text'] as String?` 처럼 읽는데, 거기에 배열이 들어 있으면 그 자리에서 터진다.
     그 자리가 화면 그리기 한복판이라 **대화 한 건 때문에 아무 화면도 안 뜬다.**
     들어오는 길(백업 복원·옛 버전 앱·손으로 고친 백업)이 있으므로 들어올 때 고쳐 둔다.
     2026-08-22 실측: 글이 배열·제목이 숫자·사진번호가 글자·모임 이름이 숫자·월 회비가 배열·
     회원 목록이 글자 → **여섯 가지 모두 TypeError** 로 터졌다. */
  static const _strFields = {
    'text', 'title', 'memo', 'place', 'date', 'until', 'cat', 'kind',
    'by', 'emoji', 'time', 'name', 'uid', 'photoId', 'payer', 'replyTo', 'repeat', 'birth', 'body',
    'thumb',
  };
  /* 기록에서 «한 줄 자리»에 그대로 그려지는 칸 — 길면 화면 밖으로 나간다.
     2026-08-23 실측: 모르는 `repeat` 값(2000자)이 일정 카드 윗줄의 딱지로 그려져
     **21,458픽셀** 오른쪽으로 넘쳤다(`_repeatLabels[rep] ?? rep` — 모르면 그대로 쓴다).
     ⚠️ `text`·`memo`·`body` 는 «여러 줄이 당연한» 글이라 여기 넣으면 안 된다(알아서 줄바꿈된다).
     ⚠️ `by`·`uid`·`payer`·`replyTo`·`photoId` 는 **번호**라 자르면 그 기록을 못 찾는다. */
  static const _itemOneLine = {'date', 'until', 'time', 'repeat', 'kind', 'cat'};

  /* 💰 「회비통장」을 가리키는 «사람 자리» 값 — 회원 번호가 아니다.
     웹과 **글자 하나까지 같아야** 한다: 웹은 이 값을 보고 「회비통장」이라 쓰고,
     회비 셈에서 이 값을 «사람이 낸 것»으로 세지 않는다(`payer !== 'wallet'`).
     (시험이 웹 파일에서 이 말을 찾아 대조한다) */
  /* 🖼 «작은 그림»(썸네일) — 기록 안에 base64 로 같이 넣는다.
     ⚠️ 이게 없으면 안 되는 이유: 같은 자료를 보는 웹은 사진을 그릴 때
        `<img src="${p.thumb}">` 로 **이 칸만** 쓴다 — 원본으로 되돌아가는 길이 없다.
        (홈의 「오늘의 사진」·모임 사진첩 띠·게시판 사진·대화방 말풍선 전부)
        비워 두면 앱에서 올린 사진이 웹에서 **깨진 그림**으로 보인다.
     크기·품질은 웹과 같게 맞춘다(220px, JPEG). 한 장에 대략 10~20KB —
     원본(보관함)은 그대로 두고 «미리보기»만 문서에 넣는 것이다.
     ⚠️ 그림 풀기는 무거우니 **딴 일꾼(compute)** 에게 시킨다 — 안 그러면 화면이 멎는다.
     못 만들면 `null` 을 돌려준다 — 그때는 예전처럼 이 칸 없이 올린다(올리기를 막지 않는다). */
  static const thumbMax = 220;

  static Future<String?> makeThumb(Uint8List bytes) async {
    try {
      return await compute(_thumbJob, bytes);
    } catch (_) {
      return null; // 그림을 못 읽어도 사진 올리기는 그대로 된다
    }
  }

  static String? _thumbJob(Uint8List bytes) {
    final src = img.decodeImage(bytes);
    if (src == null) return null;
    final small = src.width >= src.height
        ? img.copyResize(src, width: thumbMax)
        : img.copyResize(src, height: thumbMax);
    return 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(small, quality: 62))}';
  }

  static const walletPayer = 'wallet';

  static const _arrFields = {'photoIds', 'feeMonths'};
  /* 날짜는 **글자 그대로 견준다**(`a['date'].compareTo(b['date'])`, `d >= 오늘`).
     그래서 0을 안 채우면 차례가 뒤집힌다 — `'2026-8-5' >= '2026-08-21'` 이 **참**이 된다.
     게다가 이 앱은 «열 글자»가 아니면 날짜로 안 보기 때문에 더 나쁘다:
       · 화면에는 「날짜 없음」이라고 뜨고
       · `parseYmd` 는 **오늘 날짜를 돌려줘** 반복 모임이 엉뚱한 날로 잡힌다
     앱이 만드는 날짜는 늘 0을 채우지만, **백업을 손으로 고쳤거나 옛 자료**면 이럴 수 있다. */
  static const _dateFields = {'date', 'until'};

  static String fixDate(String v) {
    final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(v);
    if (m == null) return v; // 알 수 없는 글자는 그대로 둔다 (화면이 그대로 보여준다)
    final mo = int.parse(m[2]!), d = int.parse(m[3]!);
    // 있을 수 없는 달·날은 **고치지 않는다** — 0을 채우면 조용히 «딴 날»로 넘어가 버린다
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return v;
    return '${m[1]}-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
  }
  /* 묶음(맵)이어야 하는 칸. `x['reacts'] as Map?` 에 배열이 들어 있으면 **채팅 화면이 통째로 안 뜬다**
     (2026-08-22 실측: 반응이 배열인 대화 한 건에 TypeError).
     참석 투표·출석은 `Logic.asMap` 이 막아 주지만, 문 앞에서 한 번 더 고쳐 두면 새로 읽는 곳도 안전하다. */
  static const _mapFields = {'reacts', 'rsvp', 'attend', 'votes'};
  /// 돈이 될 수 없는 값(음수·소수·너무 큰 수)은 0으로.
  /// 백업에서 **음수 회비**가 들어오면 통장 합계가 통째로 뒤집힌다 (실측: -50만원 한 건에 합계가 마이너스).
  static const _moneyFields = {
    'ledger': ['amount']
  };
  /* ⚠️ 속묶음이 `Map<String,String>` 처럼 «좁은 종류»면 숫자를 넣는 순간 터진다 —
     **고치는 함수가 스스로 터지면** 아무것도 못 막는다.
     그래서 손대기 전에 «아무 값이나 담을 수 있는 묶음»으로 바꿔 둔다. */
  /// ⚠️ `v is Map<String, dynamic>` 로 걸러내면 **안 된다.**
  /// Dart에서는 `Map<String,String>` 도 그 검사를 통과하는데(공변성),
  /// 정작 숫자를 넣으면 그 자리에서 터진다. 그래서 «언제나» 넓은 묶음으로 옮겨 담는다.
  static Map<String, dynamic>? _open(Map parent, String key) {
    final v = parent[key];
    if (v is! Map) return null;
    final wide = Map<String, dynamic>.from(v);
    parent[key] = wide;
    return wide;
  }

  /// 숫자여야 하는 칸을 숫자로 (아니면 지운다 — 부르는 쪽이 기본값을 쓴다)
  /* 「때」로 쓸 수 있는 수인지.
     ⚠️ Dart 의 DateTime 은 받아 줄 수 있는 범위가 있다(약 ±8,640,000,000,000,000 밀리초).
        그 밖의 수를 주면 **RangeError 로 그 자리에서 터진다** — 그 자리가 화면 그리기 한복판이라
        홈·회비·채팅이 통째로 안 뜬다. 더 나쁜 것은 `tidy` 안에서도 이 값을 날짜로 바꾸기 때문에,
        기록 하나만 망가져도 **앱에 자료가 아예 안 들어온다.**
     ⚠️ 범위 «안»이면서 말이 안 되는 값도 나쁘다: 마이크로초를 밀리초 자리에 적으면
        «서기 5만년 가입»이 되어 그 회원의 회비가 영영 「밀린 것 없음」으로 나온다(조용한 손해).
     그래서 2000년부터 «하루 뒤»까지만 때로 인정한다(폰 시계가 조금 빠른 것은 봐준다). */
  static const _timeFloor = 946684800000; // 2000-01-01

  static bool isSaneTime(Object? v) {
    if (v is! num || !v.isFinite) return false; // NaN 은 toInt() 부터 터진다
    final n = v.toInt();
    return n >= _timeFloor && n <= DateTime.now().millisecondsSinceEpoch + 86400000;
  }

  /// 숫자로 고치되, [asTime] 이면 «말이 되는 때»가 아닌 값은 아예 뺀다.
  static void _num(Map m, String k, {bool asTime = false}) {
    final v = m[k];
    if (v != null && v is! num) {
      final n = num.tryParse('$v');
      if (n == null) {
        m.remove(k);
      } else {
        m[k] = n;
      }
    }
    /* ⚠️ NaN·무한대는 «숫자이긴 하지만» 쓰는 곳마다 터진다:
       `round()`·`toInt()` 는 UnsupportedError 를 내고, 그리기에 쓰면 자리 셈이 NaN 이 되어
       화면이 통째로 안 뜬다(2026-08-23 실측: 상징 회전이 NaN 이면 홈·위쪽 막대가 다 죽었다).
       Firestore 의 숫자는 이 둘을 담을 수 있으므로 여기서 걸러 낸다. */
    final cur = m[k];
    if (cur is num && !cur.isFinite) {
      m.remove(k);
      return;
    }
    if (asTime && m.containsKey(k) && !isSaneTime(m[k])) m.remove(k);
  }

  static int money(Object? v) {
    final raw = v is num ? v : num.tryParse('$v');
    /* ⚠️ NaN·무한대는 `round()` 자체가 터진다(UnsupportedError).
       여기가 터지면 `tidyCouple` 이 통째로 터져 **모임 문서가 아예 안 들어오고**
       앱이 「불러오는 중」 화면에 갇힌다. 돈이 아니라 «없는 것»으로 본다. */
    if (raw == null || !raw.isFinite) return 0;
    final n = raw.round();
    return (n > 0 && n <= 100000000) ? n : 0;
  }

  /// 모임 문서도 같은 병에 걸린다 — 기록(items)만 지키면 반쪽이다.
  /// `couple['members'] as Map?` 에 글자가 들어 있으면 **회원 목록 화면이 통째로 안 뜬다.**
  static const _coupleStr = {'title', 'titleKey', 'theme', 'adminUid'};
  /// 회원 한 명 안에서 «글자여야 하는» 칸
  static const _memberStr = {'uid', 'name', 'emoji', 'role', 'title', 'birth', 'photo', 'movedTo'};

  /* 화면에 «한 줄로» 보여 주는 글의 길이 한도.
     ⚠️ 입력칸은 95회차에 다 막았지만, **서버에서 오는 값은 그 문을 안 거친다**
     (웹앱·백업 복원·손으로 고친 자료). 그런 값이 오면 화면이 그냥 «넘친다»:
     2026-08-23 실측 — 직책 2000자면 회원 줄이 **33,018픽셀** 밖으로 나갔고,
     출석 칩(Wrap 안이라 폭이 무한대로 주어진다)과 말풍선 위 이름도 마찬가지였다.
     위젯마다 줄임표를 다는 것보다 **들어오는 길목에서 한 번** 자르는 편이 빠뜨릴 데가 없다.
     넉넉히 잡아(60자) 멀쩡한 값은 절대 안 건드린다 — 입력칸 한도(12~14자)의 네댓 배다. */
  static const oneLineMax = 60;

  /// 사진 주소(data:)처럼 «길어도 되는» 칸은 자르면 안 된다
  static const _longOk = {'photo', 'uid', 'movedTo'};

  static String cutLine(String v) =>
      v.length <= oneLineMax ? v : '${v.substring(0, oneLineMax)}…';

  /// 눈에 보이는 글자가 하나도 없는지 (공백·전각공백만 있는 것도 «빈 것»이다)
  /// (Dart 의 trim 은 전각공백·탭·줄바꿈까지 지운다 — 실측 확인)
  static bool isBlank(String v) => v.trim().isEmpty;

  /* ⚠️ 망가진 글자를 «빈 글자»로 바꾸면 **화면이 투명해진다.**
     앱은 `(m['emoji'] as String?) ?? defaultAvatar` 처럼 «없을 때»의 기본값을 두는데,
     빈 글자는 «있는 값»이라 기본값이 안 걸린다 → 아바타·상징이 아무것도 없이 보인다.
     (2026-08-22, 화면을 실제로 그려 보는 시험에서 잡았다 — 「안 터진다」만 봐서는 안 보였다)
     그래서 **기본값이 있는 칸은 «없음(null)»으로** 둔다. */
  static const _defaulted = {'name', 'emoji', 'photo', 'role'};
  static const _coupleMap = {
    'members', 'pending', 'former', 'push', 'lastRead', 'lastSeen', 'typing', 'fee', 'emblem', 'clubs'
  };
  static Map<String, dynamic>? tidyCouple(Map<String, dynamic>? c) {
    if (c == null) return null;
    /* 겉껍데기부터 «아무 값이나 담을 수 있는 묶음»으로 만든다.
       서버에서 온 것은 늘 그렇지만, 백업·시험처럼 좁은 종류로 만들어진 묶음이 들어오면
       고치는 도중에 값을 못 넣어 **고치는 함수가 스스로 터진다.** */
    c = Map<String, dynamic>.from(c);
    for (final k in _coupleStr) {
      final v = c[k];
      if (v is String) {
        if (k == 'title') {
          // 빈 이름은 «없는 것»으로 — 안 그러면 위쪽 막대에 아무것도 안 뜬다
          if (isBlank(v)) {
            c.remove(k);
            continue;
          }
          c[k] = cutLine(v); // 위쪽 제목은 한 줄이다
        }
        continue;
      }
      if (v == null) continue;
      c[k] = (v is num || v is bool) ? '$v' : '';
    }
    for (final k in _coupleMap) {
      final v = c[k];
      if (v == null || v is Map) continue;
      c[k] = <String, dynamic>{}; // 배열·글자가 들어 있으면 화면이 통째로 멈춘다
    }
    /* ⚠️ 겉만 봐서는 모자란다 — **회원 한 명의 칸**이 망가져도 앱이 통째로 멈춘다.
       `members` 는 회원 목록·채팅 이름·아바타·「내 권한」까지 모든 화면이 읽는 자리라
       한 사람 때문에 단추가 전부 사라지거나 화면이 안 뜬다.
       2026-08-22 실측: 이름이 숫자·이모지가 배열인 회원 한 명에 여섯 곳이 모두 TypeError. */
    for (final k in const ['members', 'pending', 'former']) {
      final m = _open(c, k);
      if (m == null) continue;
      for (final uid in m.keys.toList()) {
        if (m[uid] is! Map) {
          m.remove(uid); // 묶음이 아니면 사람으로 볼 수 없다
          continue;
        }
        final one = _open(m, uid)!;
        for (final f in _memberStr) {
          final v = one[f];
          if (v is String) {
            /* ⚠️ 빈 글자·공백만 있는 값은 «없는 것»으로 본다.
               앱은 `(m['name'] as String?) ?? '회원'` 처럼 기본값을 두는데,
               빈 글자는 «있는 값»이라 기본값이 안 걸린다 →
               2026-08-23 실측: 이름이 아무것도 안 보이고 아바타가 투명해진다.
               (56회차에 «종류가 틀린 값»은 고쳤는데 «비어 있는 값»은 그대로였다)
               직책·생년월일은 «비어 있음»이 뜻을 가지므로 건드리지 않는다. */
            if (_defaulted.contains(f) && isBlank(v)) {
              one.remove(f);
              continue;
            }
            if (!_longOk.contains(f)) one[f] = cutLine(v);
            continue;
          }
          if (v == null) continue;
          one[f] = (v is num || v is bool) ? '$v' : (_defaulted.contains(f) ? null : '');
        }
        // 누구인지는 «자리 이름»이 알려준다 — 안쪽 값이 망가졌으면 그것으로 메운다
        if (one['uid'] is! String || (one['uid'] as String).isEmpty) one['uid'] = uid;
        // 들어온 때·나간 때·신청한 때는 숫자다 — 글자면 회비 계산과 목록 차례가 터진다
        for (final f in const ['joinedAt', 'leftAt', 'requestedAt']) {
          _num(one, f, asTime: true);
        }
      }
    }
    /* 알림 설정도 사람마다 든 묶음이다 — 여기가 터지면 **설정 화면과 홈의 알림 카드**가 안 뜬다. */
    final push = _open(c, 'push');
    if (push != null) {
      for (final uid in push.keys.toList()) {
        if (push[uid] is! Map) {
          push.remove(uid);
          continue;
        }
        final one = _open(push, uid)!;
        for (final f in const ['token', 'mute']) {
          final v = one[f];
          if (v == null || v is String) continue;
          one[f] = (v is num || v is bool) ? '$v' : '';
        }
        _num(one, 'at');
      }
    }
    /* 읽음·접속·입력중은 «사람마다 시각(숫자)» 이다.
       숫자가 아닌 것이 섞이면 **채팅 화면이 통째로 안 뜬다** —
       읽음 세기는 말풍선 하나하나마다 돌고, 입력중은 글자를 칠 때마다 돈다. */
    for (final k in const ['lastRead', 'lastSeen', 'typing']) {
      final m = _open(c, k);
      if (m == null) continue;
      for (final uid in m.keys.toList()) {
        final v = m[uid];
        if (v is num) continue;
        final n = num.tryParse('$v');
        if (n == null) {
          m.remove(uid); // 언제 봤는지 알 수 없으면 «없는 것»으로 본다
        } else {
          m[uid] = n;
        }
      }
    }
    /* 총괄 목록(META)의 방마다 든 값 — 여기가 터지면 **총괄 콘솔이 안 열려**
       방을 만들지도 고치지도 지우지도 못한다. */
    final clubs = _open(c, 'clubs');
    if (clubs != null) {
      for (final code in clubs.keys.toList()) {
        if (clubs[code] is! Map) {
          clubs.remove(code);
          continue;
        }
        final one = _open(clubs, code)!;
        final t = one['title'];
        if (t != null && t is! String) one['title'] = (t is num || t is bool) ? '$t' : '';
        _num(one, 'createdAt');
      }
    }
    // 월 회비도 「돈」이다 — 음수면 늘 미납으로 보이고, 천문학적 값이면 화면이 깨진다
    final fee = _open(c, 'fee');
    if (fee != null) {
      if (fee['amount'] != null) fee['amount'] = money(fee['amount']);
      _num(fee, 'day'); // 「내는 날」이 글자면 회비 화면이 터진다
      /* 🏦 회비 보내는 곳 — 「은행·계좌번호·예금주」를 한 줄로 적어 둔 글자.
         ⚠️ 글자가 아니면 버린다. 백업을 손으로 고쳤거나 옛 자료면 숫자·배열이 들어올 수 있는데,
            그대로 두면 `as String?` 로 읽는 자리에서 터져 **회비 화면이 통째로 안 뜬다.**
         ⚠️ 길이도 자른다 — 한 줄 자리에 그리므로 긴 글이 들어오면 화면 밖으로 넘친다. */
      final acc = fee['account'];
      if (acc is String) {
        final t = acc.trim();
        fee['account'] = t.length > 60 ? t.substring(0, 60) : t;
      } else if (acc != null) {
        fee.remove('account');
      }
    }
    /* 모임 상징은 **홈 맨 위**에서 그린다 — 여기가 터지면 홈 화면이 통째로 안 뜬다.
       크기·회전은 숫자, 갈래·이모지·사진은 글자라야 한다. */
    final em = _open(c, 'emblem');
    if (em != null) {
      _num(em, 'size');
      _num(em, 'rot');
      for (final f in const ['kind', 'emoji', 'photo']) {
        final v = em[f];
        if (v == null || v is String) continue;
        // 셋 다 기본값이 있는 칸이다 — 빈 글자로 두면 홈 맨 위가 투명해진다
        em[f] = (v is num || v is bool) ? '$v' : null;
      }
    }
    return c;
  }

  /// 서버·백업에서 온 기록의 빈칸을 메꾼다 —
  /// 날짜 없는 기록은 정렬에서, 글자 숫자는 회비 합계에서 화면을 망가뜨린다.
  static List<Map<String, dynamic>> tidy(List<Map<String, dynamic>> arr) {
    for (final x in arr) {
      /* 글자로 고치는 것이 **가장 먼저**다 — 날짜 채우기보다 뒤면
         숫자로 된 날짜가 그대로 남아 정렬·비교에서 터진다. */
      for (final k in _strFields) {
        final v = x[k];
        if (v is String) {
          if (_itemOneLine.contains(k)) x[k] = cutLine(v);
          continue;
        }
        if (v == null) continue;
        x[k] = (v is num || v is bool) ? '$v' : '';
      }
      for (final k in _dateFields) {
        final v = x[k];
        if (v is String && v.isNotEmpty) x[k] = fixDate(v);
      }
      for (final k in _arrFields) {
        final v = x[k];
        if (v == null || v is List) continue;
        /* ⚠️ `const []` 를 넣으면 안 된다 — 그 뒤에 이 묶음에 무언가 «더하려는» 자리가
           그 자리에서 터진다(Cannot modify an unmodifiable list).
           다듬기는 «고쳐 주는» 일이지 «다음 사람을 넘어뜨리는» 일이 아니다.
           (2026-08-29: 이상한 photoIds 를 넣고 사진첩을 그려 보다 잡았다) */
        x[k] = <dynamic>[];
      }
      for (final k in _mapFields) {
        final v = x[k];
        if (v == null || v is Map) continue;
        x[k] = <String, dynamic>{};
      }
      // 사진 번호는 «자리를 지키며» 고친다 — 빼면 썸네일과 원본이 엇갈린다
      final ids = x['photoIds'];
      if (ids is List && ids.any((e) => e is! String)) {
        x['photoIds'] = ids.map((e) => e is String ? e : null).toList();
      }
      /* 📊 투표는 «묶음 안에 배열»이 든 꼴이라 위 검사들에 안 걸린다.
         항목이 글자가 아니면 그리는 자리에서 터져 **대화방이 통째로 안 뜬다**
         (백업 복원·웹앱·손으로 고친 기록에서 이상한 값이 올 수 있다). */
      final poll = x['poll'];
      if (x['kind'] == 'poll') {
        final p = poll is Map ? poll.cast<String, dynamic>() : <String, dynamic>{};
        final opts = p['opts'];
        final q = p['q'];
        x['poll'] = {
          'q': (q is String && q.isNotEmpty) ? q : ((x['text'] as String?) ?? ''),
          'opts': opts is List
              ? opts.whereType<String>().where((s) => s.trim().isNotEmpty).toList()
              : const <String>[],
          'multi': p['multi'] == true,
          'closed': p['closed'] == true,
        };
      }
      /* 선납 달 목록은 «짝이 없으니» 이상한 것을 빼면 된다.
         그냥 두면 `.cast<String>()` 을 훑는 순간 터져 **회비 화면이 통째로 안 뜬다**
         (낸 달 세기·미납 계산이 전부 이 목록을 훑는다). */
      final fm = x['feeMonths'];
      if (fm is List && fm.any((e) => e is! String)) {
        x['feeMonths'] = fm.whereType<String>().toList();
      }
      /* 시각은 **모든 기록에 공통**이고 앱에서 18곳이 숫자로 읽는다
         (대화 정렬·날짜 구분선·안읽음 세기…). 게다가 바로 아래 「날짜 채우기」도 이 값을 읽어서,
         여기가 글자면 **정리하는 함수 자신이 터져 모든 화면이 죽는다.**
         그래서 날짜를 채우기 «전»에 먼저 고친다. */
      _num(x, 'createdAt', asTime: true);
      _num(x, 'updatedAt', asTime: true);
      final type = x['type'] as String?;
      if (x['date'] == null && _dateTypes.contains(type)) {
        x['date'] = ymd(DateTime.fromMillisecondsSinceEpoch(
            (x['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch));
      }
      for (final k in _numFields[type] ?? const <String>[]) {
        if (k == 'months' && !x.containsKey(k)) continue; // 선납 기록에만 있는 칸
        final v = x[k];
        if (v is num) continue;
        x[k] = v == null ? 0 : (num.tryParse('$v') ?? 0);
      }
      for (final k in _moneyFields[type] ?? const <String>[]) {
        x[k] = money(x[k]);
      }
    }
    return arr;
  }

  /// [docId]를 주면 그 이름으로 저장한다.
  ///
  /// 회비처럼 **두 사람이 동시에 같은 것을 기록할 수 있는** 경우에 쓴다.
  /// 이름을 정해두면 나중 것이 앞엣것을 덮어써서 **같은 달이 두 번 기록되지 않는다**
  /// (총무가 둘이면 같은 회원의 같은 달을 함께 눌러 회비가 두 배로 잡히던 자리).
  /* 이용권이 끊겼을 때 «왜 안 되는지» 알려 주는 자리.

     ⚠️ 예전에는 앱이 그냥 보내고 서버가 거절했다 — 회원 화면에는
        「저장하지 못했어요 — 다시 해주세요」만 떠서, **왜 안 되는지 알 길이 없었다.**
        긴 글을 다 쓰고 나서 잃기도 했다. 방장은 결제해야 하는 줄도 몰랐다.
        (팔리려면 «왜 안 되는지»부터 알아야 한다)
     ⚠️ 이건 «안내»일 뿐 잠금이 아니다 — 진짜 잠금은 서버 규칙이 한다.
        여기서 막는 것은 헛수고와 잃는 글을 줄이기 위해서다. */
  static String? lockReason() => Fee.locked ? Fee.lockedLine : null;

  Future<String?> addItem(String code, Map<String, dynamic> data, {String? docId}) async {
    if (Demo.on) return Demo.addItem(data, docId: docId);
    // 잠겼으면 보내지 않는다 — 서버가 어차피 거절한다. 헛수고와 잃는 글을 줄인다
    if (Fee.locked) return null;
    final item = {
      ...data,
      'coupleId': code,
      'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      'by': data['by'] ?? myUid,
      'uid': myUid,
    };
    final c = col(colOf(item['type'] as String?));
    // 문서 이름을 «먼저» 만든다 — 그래야 인터넷이 없어도 바로 돌려줄 수 있다
    final ref = docId == null ? c.doc() : c.doc(docId);
    final ok = await settle(() => ref.set(item), '저장');
    return ok ? ref.id : null;
  }

  /// 회비 기록의 고정 이름 — 「누가·어느 달부터」가 같으면 같은 기록으로 본다.
  static String feeDocId(String code, String uid, String firstMonth) =>
      'fee_${code}_${uid}_$firstMonth';

  Future<void> updateItem(String code, String id, String? type, Map<String, dynamic> patch) =>
      Demo.on
      ? Future.sync(() => Demo.updateItem(id, patch))
      : settleVoid(
          () => docRef(colOf(type), id)
              .update({...patch, 'updatedAt': DateTime.now().millisecondsSinceEpoch}),
          '고치기');

  Future<bool> deleteItem(String code, String id, String? type) async {
    if (Demo.on) return Demo.deleteItem(id);
    try {
      return await settle(() => docRef(colOf(type), id).delete(), '삭제');
    } catch (e) {
      _err(e);
      return false;
    }
  }

  /// 배열이 든 기록(참석 투표·출석·준비물 등)은 반드시 이걸로 고친다 —
  /// 통째로 덮어쓰면 그 사이 남이 한 투표가 사라진다.
  Future<bool> mutateItem(
    String code,
    String id,
    String? type,
    Map<String, dynamic>? Function(Map<String, dynamic> cur) fn,
  ) async {
    if (Demo.on) return Demo.applyItem(id, fn);
    final ref = docRef(colOf(type), id);
    var wrote = false;
    await _db.runTransaction((tx) async {
      // ⚠️ 다시 돌 때를 대비해 맨 위에서 되돌린다 (mutateCouple 과 같은 규칙)
      wrote = false;
      final s = await tx.get(ref);
      if (!s.exists) return;
      final patch = fn(s.data()!);
      if (patch == null) return;
      tx.set(ref, _withDelete(patch), SetOptions(merge: true));
      wrote = true;
    });
    return wrote;
  }

  /// 🧹 방을 지우기 전에 그 방의 기록을 모두 지운다.
  ///
  /// ⚠️ 순서가 중요하다. 방 문서를 **먼저** 지우면 보안 규칙이 「그 방 회원인지」를
  /// 확인할 길이 없어져, 남은 대화·사진·회비 기록에 아무도 손댈 수 없게 된다.
  /// 그러면 보이지도 않는 기록이 영영 남아 매달 보관 요금만 나간다.
  ///
  /// [onProgress]로 몇 건까지 지웠는지 알려준다 (기록이 많으면 오래 걸린다).
  Future<int> purgeClubData(String code, {void Function(int)? onProgress}) async {
    var done = 0;
    /* 「기록을 지우기 전에 번호를 모아 둔다」는 이 함수의 원칙을 **모임 문서 «자신»에게도** 쓴다.
       상징·아바타 사진은 문서 안에만 번호가 있어, 안 챙기면 문서와 함께 길을 잃는다. */
    try {
      dropPhotos(photoIdsOfCouple(await getCouple(code)));
    } catch (e) {
      _err(e, '모임 사진 치우기');
    }
    for (final name in ['items', 'msgs', 'photos']) {
      var guard = 0;
      while (guard++ < 500) {
        // 한 번에 300건씩 — 너무 크게 잡으면 묶음 쓰기 한도(500)에 걸린다
        final s = await col(name).where('coupleId', isEqualTo: code).limit(300).get();
        if (s.docs.isEmpty) break;

        /* ⚠️ 사진 원본은 **기록을 지우기 전에** 번호를 모아 둬야 한다.
           보안 규칙이 사진 보관함의 「목록 보기」를 막아 두었기 때문에(코드를 알아도 훑을 수 없게),
           기록을 먼저 지우면 그 사진들이 어디 있는지 **영영 찾을 수 없다.**
           한 장씩 정확한 주소로 지우는 것은 규칙이 허용한다. */
        final photoIds = <String>[];
        if (name != 'photos') {
          for (final d in s.docs) {
            photoIds.addAll(photoIdsOf(d.data()));
          }
        }
        // 실패하면 삭제 대기줄에 남아 다음에 다시 시도된다 (앱을 껐다 켜도 유지)
        for (final id in photoIds) {
          await deletePhoto(id);
        }

        final batch = _db.batch();
        for (final d in s.docs) {
          batch.delete(d.reference);
        }
        // 못 끝냈으면 던져서 멈춘다 — 그래야 방 문서가 남아 다음에 마저 지울 수 있다
        await mustSettle(() => batch.commit(), '기록 지우기');
        done += s.docs.length;
        onProgress?.call(done);
        if (s.docs.length < 300) break;
      }
    }
    return done;
  }

  // ─────────────────────────────── 사진 원본

  /// 원본은 Cloud Storage에 파일로 저장한다 (Firestore 문서보다 저장료가 싸고 크기 한도가 없다).
  int _photoSeq = 0;
  bool? _storageOk; // null=아직 모름, false=한 번 실패해서 이제 안 써봄

  Future<String?> savePhoto(String code, Uint8List bytes) async {
    // 체험 중에는 보관함에 못 올린다 — 그림 그 자체를 들고 있다가 화면에 그린다
    if (Demo.on) return Demo.keepPhoto(bytes);
    // 여러 장을 한 번에 올릴 때 같은 밀리초에 걸리면 번호가 겹쳐 서로 덮어쓴다 → 일련번호를 덧붙인다
    final tail = myUid.length > 4 ? myUid.substring(myUid.length - 4) : myUid;
    final id = '${DateTime.now().millisecondsSinceEpoch}_${_photoSeq++}$tail';
    try {
      if (_storageOk == false) throw Exception('storage unavailable');
      final ref = _st.ref('photos/$code/$id');
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          /* 사진은 한 번 올리면 «절대 안 바뀐다»(바꾸면 번호가 새로 생긴다).
             이 설정이 없으면 볼 때마다 서버에 「바뀌었나요」를 다시 묻는다 —
             사진 수만큼, 보는 사람 수만큼 요청이 곱해진다. 1년 동안 다시 안 묻게 한다. */
          cacheControl: 'public, max-age=31536000, immutable',
        ),
      );
      _storageOk = true;
      return 'st:$code/$id'; // id에 위치를 담아 두면 조회 때 바로 찾는다
    } catch (e) {
      /* ⚠️ 「이번 한 장이 안 올라간 것」과 「보관함을 아예 못 쓰는 것」은 다르다.
         예전에는 무엇이든 한 번 실패하면 보관함을 접었다 — 그러면 잠깐 끊긴 사이
         한 장이 실패했을 뿐인데 **그 뒤로 올리는 사진이 전부** 7배 비싼 길(Firestore)로 샜다.
         게다가 그 길은 문서 1MB 한도가 있어 큰 사진은 아예 저장도 안 된다.
         정말 못 쓸 때(통이 없음·요금 한도)만 접는다. */
      if (storageUnusable(e)) _storageOk = false;
      // Storage를 못 쓰면 예전처럼 Firestore 문서로 폴백
      try {
        await docRef('photos', id).set({
          'coupleId': code,
          // ⚠️ 「누가 올렸는지」를 꼭 적는다. 없으면 서버 규칙이 주인을 알 수 없어
          //    **올린 본인도 못 지우고** 사진이 영영 남아 보관 요금만 나간다
          'uid': myUid,
          'by': myUid,
          'data': 'data:image/jpeg;base64,${base64Encode(bytes)}',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
        return id;
      } catch (e2) {
        _err(e2);
        return null;
      }
    }
  }

  final _photoCache = <String, String?>{};

  /// 이미 받아둔 사진 주소 — 없으면 null.
  /// 화면을 다시 그릴 때 이걸 먼저 쓰면 사진이 깜빡이지 않는다.
  String? cachedPhoto(String? id) => id == null ? null : _photoCache[id];

  /* 같은 것을 «동시에» 여러 번 물어보면 한 번만 물어보게 묶는다.
     사진 한 장이 화면 여러 곳(격자·채팅·상징)에 동시에 뜨고, 화면은 남이 글씨만 쳐도 다시 그려진다.
     묶지 않으면 그때마다 저장소에 **새 요청**이 나가 요금·배터리·버벅임이 그만큼 늘어난다. */
  static Future<T> once<T>(
    Map<String, Future<T>> waiting,
    String key,
    Future<T> Function() work,
  ) {
    final cur = waiting[key];
    if (cur != null) return cur;
    final f = work();
    waiting[key] = f;
    // 끝나면 반드시 지운다 — 안 지우면 실패한 요청이 그대로 굳어 다시 시도할 수 없다
    return f.whenComplete(() => waiting.remove(key));
  }

  final _photoWait = <String, Future<String?>>{};

  /// 사진 주소(Storage는 https 주소, 폴백은 data: 주소)를 돌려준다.
  Future<String?> getPhoto(String? id) async {
    if (Demo.on) return Demo.getPhoto(id);
    if (id == null || id.isEmpty) return null;
    if (_photoCache.containsKey(id)) return _photoCache[id];
    return once(_photoWait, id, () => _fetchPhoto(id));
  }

  Future<String?> _fetchPhoto(String id) async {
    String? d;
    /* ⚠️ 「못 받았다」를 기억해 두면 안 된다.
       지하철·엘리베이터에서 한 번 못 받은 사진이 **앱을 껐다 켤 때까지 영영 깨진 채**로 남는다.
       정말 없어진 사진(object-not-found)일 때만 기억하고, 그 밖의 실패는 다음에 다시 해본다. */
    var gone = false;
    if (id.startsWith('st:')) {
      try {
        d = await _st.ref('photos/${id.substring(3)}').getDownloadURL();
      } catch (e) {
        gone = alreadyGone(e);
      }
    } else {
      try {
        final s = await docRef('photos', id).get();
        d = s.exists ? s.data()!['data'] as String? : null;
        gone = !s.exists;
      } catch (e) {
        gone = alreadyGone(e);
      }
    }
    if (d != null || gone) _photoCache[id] = d;
    return d;
  }

  /// 이 기록이 붙들고 있는 원본 번호를 모두 모은다.
  /// 한 군데라도 빠뜨리면 그 원본은 저장소에 영원히 남아 매달 용량 요금이 나간다.
  static List<String> photoIdsOf(Map<String, dynamic>? o) {
    if (o == null) return const [];
    // photoIds가 목록이 아닌 값(백업 복원·옛 기록 등)일 수 있다.
    // 여기서 죽으면 방 지우기·글 지우기가 통째로 멈추므로 조용히 건너뛴다.
    final many = o['photoIds'];
    return [
      o['photoId'],
      o['rcptId'],
      if (many is List) ...many,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
  }

  /* 🖼 모임 문서 «자신»이 들고 있는 사진 번호 — 모임 상징과 회원 아바타.
     ⚠️ 이 번호들은 items·msgs 가 아니라 **couples 문서 안**에 적혀 있다.
        그래서 방을 지울 때 `purgeClubData` 의 기록 훑기에 **한 장도 안 걸린다.**
        방 문서를 지우고 나면 어디서도 번호를 못 찾아(보관함 목록 보기는 규칙이 막았다)
        **원본이 영영 남아 매달 보관 요금만 나간다** — 이 함수가 스스로 경계하던 바로 그 일이다.
     탈퇴 기록(former)·신청(pending)에 남은 것까지 함께 챙긴다. */
  static List<String> photoIdsOfCouple(Map<String, dynamic>? c) {
    if (c == null) return const [];
    final out = <String>[];
    void add(Object? v) {
      if (v is String && v.isNotEmpty) out.add(v);
    }

    // ⚠️ `as Map?` 로 캐스팅하면 안 된다 — 상징 자리에 글자가 들어 있으면
    //    **그 자리에서 터져 방 지우기가 통째로 멈춘다**(백업 복원·손으로 고친 자료).
    final em = c['emblem'];
    if (em is Map) add(em['photo']);
    for (final k in const ['members', 'former', 'pending']) {
      final m = c[k];
      if (m is! Map) continue;
      for (final e in m.values) {
        if (e is Map) add(e['photo']);
      }
    }
    return out;
  }

  // 삭제 대기줄 — 못 지운 원본을 기기에 적어 뒀다가 다음에 마저 지운다.
  // 서버가 계속 거절하는 것은 앱을 켤 때마다 재시도하며 요금만 쓰므로 10번이면 포기한다.
  static const _maxDelTry = 10;
  static const _qKey = 'club_delq';
  static const _qnKey = 'club_delq_n';

  /* 🗑 **포기함.** 예전에는 10번을 채우거나 대기줄이 넘치면 «번호를 그냥 버렸다».
     번호가 사라지면 그 원본은 **아무도 못 보는 채로 매달 보관료만** 나가고,
     되짚을 실마리조차 없다. 그래서 버리지 않고 여기로 «옮긴다».
     ⚠️ 여기 있는 것은 **저절로 다시 시도하지 않는다** — 그러면 포기한 뜻이 없어지고
        앱을 켤 때마다 같은 실패를 되풀이하며 요금만 쓴다.
        사장님이 「다시 지워보기」를 누를 때만 대기줄로 돌아간다. */
  static const _qLostKey = 'club_delq_lost';
  static const lostMax = 500;

  /// 포기함에 넣는 셈 — 서버·기기 저장 없이 시험할 수 있게 떼어냈다.
  static ({List<String> lost, int forgotten}) planLost(
      List<String> lost, Iterable<String> add) {
    final l = lost.toList();
    final have = l.toSet();
    for (final id in add) {
      if (id.isEmpty || have.contains(id)) continue;
      have.add(id);
      l.add(id);
    }
    var forgotten = 0;
    while (l.length > lostMax) {
      have.remove(l.removeAt(0)); // 가장 오래된 것부터 — 여기서 넘치면 정말로 잊는다
      forgotten++;
    }
    return (lost: l, forgotten: forgotten);
  }

  /* 대기줄을 어떻게 바꿀지 «셈하는 부분»만 떼어냈다 — 기기 저장 없이 시험할 수 있게.
     이 자리는 이미 두 번 버그가 났다(31회차 깨진 값에 멈춤, 44회차 조용히 버림). */
  static const delQMax = 200;

  static ({List<String> queue, Map<String, int> tries, int dropped, bool gaveUp, List<String> lost})
      planPend(
    List<String> queue,
    Map<String, int> tries,
    String id,
    bool add, {
    bool failed = false,
  }) {
    final q = queue.toSet();
    final n = Map<String, int>.from(tries);
    if (!add) {
      n.remove(id);
      q.remove(id);
      return (queue: q.toList(), tries: n, dropped: 0, gaveUp: false, lost: const []);
    }
    if (failed) {
      n[id] = (n[id] ?? 0) + 1;
      if (n[id]! > _maxDelTry) {
        // 다시 해도 안 될 것 같으면 포기한다 — 그 원본은 서버에 남는다
        q.remove(id);
        n.remove(id);
        return (queue: q.toList(), tries: n, dropped: 0, gaveUp: true, lost: [id]);
      }
    }
    if (q.contains(id)) {
      return (queue: q.toList(), tries: n, dropped: 0, gaveUp: false, lost: const []);
    }
    q.add(id);
    var dropped = 0;
    final lost = <String>[];
    while (q.length > delQMax) {
      final first = q.first; // 넣은 차례대로 — 가장 오래된 것부터 뺀다
      q.remove(first);
      n.remove(first);
      lost.add(first); // 버리지 않고 «포기함»으로 — 원본이 서버에 남아 있으니 흔적을 지키다
      dropped++;
    }
    return (queue: q.toList(), tries: n, dropped: dropped, gaveUp: false, lost: lost);
  }

  void _pend(String id, bool add, {bool failed = false}) {
    final p = _prefs;
    if (p == null) return;
    // 세어 둔 값이 깨져 있어도(옛 형식·중간에 끊긴 저장) 지우기가 멈추면 안 된다
    var n = <String, int>{};
    try {
      final raw = jsonDecode(p.getString(_qnKey) ?? '{}');
      if (raw is Map) {
        raw.forEach((k, v) {
          final i = v is num ? v.toInt() : int.tryParse('$v');
          if (i != null) n['$k'] = i;
        });
      }
    } catch (_) {/* 처음부터 다시 센다 */}

    final r = planPend(p.getStringList(_qKey) ?? const [], n, id, add, failed: failed);
    /* 조용히 버리면 **안 지워진 사진이 매달 요금으로 쌓이는데 아무도 모른다.**
       자국이라도 남겨야 나중에 「왜 저장료가 이렇게 나오지」를 되짚을 수 있다. */
    if (r.dropped > 0) {
      _err('대기줄이 가득 차서 못 지운 사진 ${r.dropped}장을 «포기함»으로 옮겼어요 — 그 원본은 서버에 남습니다',
          '사진 지우기 대기줄');
    }
    if (r.gaveUp) {
      _err('$_maxDelTry번을 시도해도 못 지운 사진을 «포기함»으로 옮겼어요 — 그 원본은 서버에 남습니다 ($id)',
          '사진 지우기 대기줄');
    }
    if (r.lost.isNotEmpty) _toLost(p, r.lost);
    p.setStringList(_qKey, r.queue);
    p.setString(_qnKey, jsonEncode(r.tries));
  }

  static void _toLost(SharedPreferences p, Iterable<String> ids) {
    final r = planLost(p.getStringList(_qLostKey) ?? const [], ids);
    if (r.forgotten > 0) {
      _err('포기함마저 가득 차서 사진 ${r.forgotten}장의 번호를 잊었어요 — 그 원본은 영영 서버에 남습니다',
          '사진 지우기 대기줄');
    }
    p.setStringList(_qLostKey, r.lost);
  }

  /// 포기함에 몇 장 남아 있는지 — 화면에 「못 지운 사진 원본이 N개 남아 있어요」로 보여 준다.
  /// 숫자를 안 보여 주면 **아무도 모르는 채로 매달 보관료만** 나간다.
  int lostCount() => _prefs?.getStringList(_qLostKey)?.length ?? 0;

  /// 「다시 지워보기」 — 포기함에 있는 것을 **사장님이 누를 때만** 대기줄로 되돌린다.
  ///
  /// ⚠️ 저절로 부르면 안 된다. 그러면 포기한 뜻이 없어지고
  ///    앱을 켤 때마다 같은 실패를 되풀이하며 요금만 쓴다.
  Future<int> retryLost() async {
    final p = _prefs;
    if (p == null) return 0;
    final lost = p.getStringList(_qLostKey) ?? const <String>[];
    if (lost.isEmpty) return 0;
    /* 포기함을 «먼저» 비운다 — 나중에 비우면 도중에 앱이 꺼졌을 때
       같은 번호가 대기줄과 포기함 양쪽에 남아 두 배로 헛돈다. */
    p.setStringList(_qLostKey, const []);
    // 세던 횟수도 지운다 — 안 지우면 한 번 실패에 바로 다시 포기함으로 간다
    var n = <String, int>{};
    try {
      final raw = jsonDecode(p.getString(_qnKey) ?? '{}');
      if (raw is Map) {
        raw.forEach((k, v) {
          final i = v is num ? v.toInt() : int.tryParse('$v');
          if (i != null) n['$k'] = i;
        });
      }
    } catch (_) {/* 처음부터 다시 센다 */}
    final q = (p.getStringList(_qKey) ?? const <String>[]).toSet();
    for (final id in lost) {
      n.remove(id);
      q.add(id);
    }
    p.setStringList(_qKey, q.toList());
    p.setString(_qnKey, jsonEncode(n));
    await flushDeletes();
    return lost.length;
  }

  /// 되돌리기 시간이 끝나 원본을 지울 때 쓴다 — 그 순간은 보통 앱을 닫는 때라
  /// 요청이 끝까지 갈 보장이 없으니 먼저 대기줄에 적어두고 지운다.
  void dropPhotos(Iterable<String?> ids) {
    if (Demo.on) return; // 체험 사진은 서버에 없다 — 지울 것도 없다
    /* `data:` 로 시작하는 값은 그림이 **문서 안에 통째로** 들어 있던 옛 방식이라
       따로 지울 원본이 없다. 걸러 내지 않으면 보관함에 없는 것을 지우려다
       대기줄에서 10번을 헛돌고 요금만 쓴다. 부르는 곳마다 챙기면 언젠가 한 곳을 빠뜨리니
       **들어오는 문 한 곳에서** 거른다. */
    final list = ids
        .whereType<String>()
        .where((s) => s.isNotEmpty && !s.startsWith('data:'))
        .toList();
    if (list.isEmpty) return;
    for (final id in list) {
      _pend(id, true);
    }
    for (final id in list) {
      deletePhoto(id);
    }
  }

  bool _flushing = false;

  Future<void> flushDeletes() async {
    if (_flushing) return;
    _flushing = true;
    // 도중에 하나가 터져도 «다시 돌 수 있게» 반드시 표시를 되돌린다.
    // 안 그러면 그 뒤로 앱을 끌 때까지 대기줄이 한 번도 안 돌아 사진이 쌓인 채 요금만 나간다
    try {
      for (final id in _prefs?.getStringList(_qKey) ?? const <String>[]) {
        await deletePhoto(id);
      }
    } catch (e) {
      _err(e, '사진 지우기 대기줄');
    } finally {
      _flushing = false;
    }
  }

  /// 「지울 수 없는 이유」가 영영 그대로일 것 같은지 — 그럴 때만 실패로 센다.
  ///
  /// ⚠️ 인터넷이 없어서 못 지운 것을 실패로 세면 안 된다.
  /// 며칠 오프라인이었다는 이유로 10번을 채워 대기줄에서 빠지고,
  /// 그 사진은 아무도 못 보는 채로 남아 **매달 보관 요금만** 나간다.
  static bool countsAsFailure(Object e) {
    /* ⚠️ 서버가 준 오류가 «아닌» 것(값이 잘못돼 터진 것)은 다시 해도 똑같다 — 반드시 센다.
       예전에는 이것도 「인터넷 문제」쪽으로 몰아 `failed:false` 로 뒀는데,
       그러면 10번 세기가 아예 안 돌아 **영영 안 빠지는 줄**이 생긴다. */
    if (e is! FirebaseException) return true;
    // 권한이 없거나 값이 잘못된 것은 다시 해도 마찬가지 → 세어서 언젠가 포기한다
    const permanent = {'unauthorized', 'permission-denied', 'invalid-argument', 'invalid-checksum'};
    return permanent.contains(e.code);
  }

  /// 보관함을 «이번 실행 내내» 접을 만한 실패인가.
  /// 잠깐 끊긴 것·이 한 장이 큰 것은 «다음 장은 될 수 있다» — 접지 않는다.
  /// (`unauthorized` 는 일부러 뺀다: 크기 한도에 걸린 것도 같은 말로 오기 때문에
  ///  그걸로 접으면 「사진 한 장 커서 실패」가 다시 온 방을 물들인다)
  /// ※ 잘못 짚어도 손해는 «한 번 더 기다리는 것»뿐이다 — 폴백은 그대로 돌아간다.
  static bool storageUnusable(Object e) {
    final code = e is FirebaseException ? e.code : '';
    const dead = {'bucket-not-found', 'project-not-found', 'quota-exceeded'};
    return dead.contains(code);
  }

  /// 이미 없어진 것인지 (지울 게 없으니 성공으로 본다)
  static bool alreadyGone(Object e) {
    final code = e is FirebaseException ? e.code : '';
    return code == 'object-not-found' || code == 'not-found';
  }

  /* 지우기 시도의 «결말»에 따라 대기줄을 어떻게 할지 — 서버 없이 시험할 수 있게 떼어냈다.
       keep   : 대기줄에 남길지(=true) 뺄지(=false)
       failed : 「다시 해도 안 될 것」으로 세어 언젠가 포기할지
       ok     : 지워진 것으로 볼지

     ⚠️ 「답이 없음」을 keep:false 로 두면 안 된다. 예전에는 그 갈래가 대기줄을 아예 안 건드려
        **이미 적혀 있겠지** 하고 넘어갔는데, 미리 적어 두는 곳은 `dropPhotos` 하나뿐이었다.
        방 지우기(`purgeClubData`)는 안 적고 부르기 때문에, 6초 안에 답이 없으면
        그 원본은 대기줄에도 안 들어가고 바로 다음 줄에서 **사진 번호를 담고 있던 기록이 지워져**
        어디 있는지 영영 찾을 수 없게 됐다 (보관 요금만 매달 나간다). */
  static ({bool keep, bool failed, bool ok}) planAfterDelete({
    bool timedOut = false,
    Object? error,
  }) {
    if (error != null) {
      // 이미 없으면 지울 게 없는 것 — 대기줄에서 빼야 앱을 켤 때마다 헛되이 다시 시도하지 않는다
      if (alreadyGone(error)) return (keep: false, failed: false, ok: true);
      // 인터넷 문제 같은 건 세지 않고 대기줄에만 남긴다 (다음에 다시 시도)
      return (keep: true, failed: countsAsFailure(error), ok: false);
    }
    // 답이 없을 때도 «반드시» 대기줄에 적는다 (실패로 세지는 않는다)
    if (timedOut) return (keep: true, failed: false, ok: false);
    return (keep: false, failed: false, ok: true);
  }

  /* 🚫 이 번호로 «지우기를 해볼 수 있는가».

     ⚠️ `dropPhotos` 가 들어오는 문에서 `data:` 를 거르지만(144회차), **대기줄은 기기에 남는다.**
        그 고침 «전»에 쌓인 값이 아직 회원 폰에 있을 수 있고, `flushDeletes` 는 그 목록을
        그대로 읽어 지우려 든다. base64 글자에는 `//` 가 거의 반드시 들어 있어
        Firestore 가 `ArgumentError('A document path must not contain "//"')` 를 던지는데,
        그건 **FirebaseException 이 아니라서 실패로 세지도 않는다** →
        `keep:true, failed:false` 로 대기줄에 남아 **앱을 켤 때마다 영원히 다시 시도**한다.
     그래서 «해볼 수 있는 값인지»를 먼저 가른다 — 못 지울 값은 조용히 대기줄에서 뺀다. */
  static bool deletable(String? id) {
    if (id == null || id.isEmpty) return false;
    if (id.startsWith('data:')) return false; // 문서 안에 그림이 들어 있던 옛 방식 — 지울 원본이 없다
    if (id.startsWith('st:')) return id.length > 3; // 보관함 주소(st:방코드/번호)
    return !id.contains('/'); // Firestore 문서 이름에는 빗금이 들어갈 수 없다
  }

  Future<bool> deletePhoto(String? id) async {
    if (id == null || id.isEmpty) return false;
    if (!deletable(id)) {
      _pend(id, false); // 지울 것이 없으니 대기줄에서 뺀다 (다시 시도해도 소용없다)
      return true;
    }
    final isStorage = id.startsWith('st:');
    ({bool keep, bool failed, bool ok}) plan;
    try {
      /* ⏱ 답이 안 오면 매듭짓는다. 안 그러면 `flushDeletes` 가 첫 장에서 영영 기다리다
         「도는 중」 표시가 참인 채로 남아, 그 뒤로 앱을 끌 때까지 대기줄이 한 번도 안 돈다. */
      final f = isStorage
          ? _st.ref('photos/${id.substring(3)}').delete()
          : docRef('photos', id).delete();
      final done = await Future.any([
        f.then((_) => true),
        Future<bool>.delayed(_settleWait, () => false),
      ]);
      plan = planAfterDelete(timedOut: !done);
    } catch (e) {
      plan = planAfterDelete(error: e);
    }
    _pend(id, plan.keep, failed: plan.failed);
    return plan.ok;
  }

  // ─────────────────────────────── 기기에 저장하는 값들

  String? getStr(String k) => _prefs?.getString(k);
  Future<void> setStr(String k, String v) async => _prefs?.setString(k, v);
  Future<void> remove(String k) async => _prefs?.remove(k);
  int getInt(String k) => _prefs?.getInt(k) ?? 0;
  Future<void> setInt(String k, int v) async => _prefs?.setInt(k, v);

  static void _err(Object e, [String? what]) {
    // ignore: avoid_print
    print('저장소 오류${what == null ? '' : '($what)'}: $e');
  }
}

/// 2026-08-21 형태의 날짜 문자열 — 기록의 date 칸은 전부 이 형식이다.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseYmd(String? s) {
  if (s == null || s.length < 10) return DateTime.now();
  return DateTime.tryParse(s.substring(0, 10)) ?? DateTime.now();
}
