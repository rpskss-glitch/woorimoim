import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../logic.dart';
import '../moderation.dart';
import '../state.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';

/// 💬 단체 채팅.
class ChatTab extends StatefulWidget {
  /// 지금 채팅 탭을 보고 있는지. 탭은 뒤에서도 살아 있기 때문에,
  /// 이걸 안 보면 홈 화면을 보는 동안에도 「읽음」으로 처리돼
  /// 안 읽은 개수 표시가 영영 뜨지 않고, 남에게도 읽은 것처럼 보인다.
  final bool active;
  const ChatTab({super.key, required this.active});
  @override
  State<ChatTab> createState() => _ChatTabState();
}

/// 지금 온 대화를 «읽은 것»으로 볼지.
///
/// ⚠️ 「채팅 탭인지」만 보면 안 된다. 회원이 채팅 탭에 둔 채 폰을 주머니에 넣어도
/// 구독은 그대로 살아 있어서 새 대화가 오는 족족 «읽음»으로 적힌다.
///   · 보낸 사람 화면에는 아무도 안 봤는데 **「읽음 1」**이 뜨고
///   · 받는 사람의 **안읽음 배지는 영영 0**이라 새 대화가 온 줄을 모른다.
/// 아직 앱 상태가 안 알려졌으면(null) 첫 화면이므로 앞에 있는 것으로 본다.
/* 💬 대화 한 건을 «한 줄 글»로 — 말풍선·답장 미리보기·답장 바가 같은 말을 하게.
   ⚠️ 이 앱이 모르는 갈래(kind)가 온다. 웹앱(아이폰 회원이 쓴다)에는 **음성 메시지**가 있는데
      앱은 `img` 만 알아서 그 말풍선이 **텅 비어 있었다.**
      게다가 서버는 이미 「🎤 음성 메시지를 보냈어요」라고 알림을 보낸다 →
      **알림은 왔는데 열어 보면 아무것도 없는** 꼴이었다.
   모르는 갈래가 또 생겨도 «빈 자리»가 아니라 무엇인지는 보이게 한다. */
String msgLabel(Map<String, dynamic> m) {
  final kind = (m['kind'] as String?) ?? '';
  if (kind == 'img') return '📷 사진';
  if (kind == 'poll') return '📊 투표: ${Logic.poll(m).q}';
  if (kind == 'voice') return '🎤 음성 메시지 (웹에서 들을 수 있어요)';
  final text = (m['text'] as String?) ?? '';
  if (text.isNotEmpty) return text;
  // 갈래가 안 적힌 옛 대화는 그냥 빈 글이다 — 없는 말을 지어내지 않는다
  return kind.isEmpty ? '' : '📄 이 앱에서는 볼 수 없는 메시지예요';
}

/// 「입력 중」 표시가 살아 있는 시간 — 이 시간이 지나면 스스로 사라져야 한다.
const typingWindow = 4000;

/* ⌨️ 지금 «입력 중»인 사람들과, 그 표시가 사라져야 할 때까지 남은 시간.
   ⚠️ 이 표시는 서버 값의 «나이»로 정해진다 — 값이 그대로면 다시 그릴 일이 없다.
      그래서 상대가 치다가 멈추면, 4초가 지나도 화면이 안 바뀌어
      **「○○님이 입력 중…」이 몇 분씩 그대로 떠 있었다**
      (다음 대화나 접속 표시가 올 때에야 사라졌다).
      남은 시간을 함께 돌려주어 화면이 «제때 스스로» 지우게 한다. */
({List<String> uids, int expiresInMs}) typingLive(
  Map<String, dynamic> typing,
  bool Function(String uid) isMember,
  String myUid,
  int now,
) {
  final uids = <String>[];
  var soonest = typingWindow;
  typing.forEach((uid, v) {
    if (uid == myUid || !isMember(uid)) return;
    final age = now - ((v is num) ? v.toInt() : 0);
    if (age < 0 || age >= typingWindow) return; // 시계가 앞선 값도 안 믿는다
    uids.add(uid);
    final left = typingWindow - age;
    if (left < soonest) soonest = left;
  });
  return (uids: uids, expiresInMs: uids.isEmpty ? 0 : soonest);
}

bool countsAsRead(bool tabActive, AppLifecycleState? life) =>
    tabActive && (life == null || life == AppLifecycleState.resumed);

class _ChatTabState extends State<ChatTab> with WidgetsBindingObserver {
  final _textC = TextEditingController();
  final _scrollC = ScrollController();
  Map<String, dynamic>? _replyTo;
  int _typingSentAt = 0;
  bool _loadingOlder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppState.i.addListener(_onData);
    // 입력중·읽음만 바뀐 경우는 이쪽으로 온다 (홈·회비 계산을 다시 하지 않기 위해)
    AppState.i.live.addListener(_onLive);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markSeen();
      // 안 내려주면 「가장 오래된 대화」부터 보인다 — 채팅은 늘 최신이 먼저 보여야 한다
      _scrollToBottom();
    });
  }

  @override
  void didUpdateWidget(ChatTab old) {
    super.didUpdateWidget(old);
    // 방금 채팅 탭으로 들어왔다면 그때 읽음 처리한다
    if (!old.active && widget.active) {
      /* ⚠️ 여기서 «바로» 부르면 안 된다 — `didUpdateWidget` 은 **그리는 도중**에 불린다.
         읽음 표시는 모임 자료를 고치고, 그러면 알림이 퍼져 다른 탭들이 다시 그리려 든다.
         그 순간 Flutter 가 「그리는 중에는 다시 그리라고 할 수 없다」며 막는다:
           setState() or markNeedsBuild() called during build.
         탭 다섯이 «동시에 살아 있는» 이 앱에서는 한 번 옮길 때마다 네 개씩 났다
         (2026-08-29: 탭을 옮겨 보는 시험이 잡았다. 디버그 판에서는 빨간 화면이 되고,
          내보내는 판에서는 조용히 넘어가되 화면 갱신이 한 박자 밀린다).
         그리기가 끝난 뒤로 미룬다. */
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _markSeen();
      });
      _scrollToBottom(); // 다른 탭 갔다 돌아오면 다시 최신 대화가 보이게 (이미 다음 프레임에 돈다)
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppState.i.removeListener(_onData);
    AppState.i.live.removeListener(_onLive);
    _textC.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱으로 돌아왔을 때 비로소 읽은 것이다 — 여기서 안 하면 새 대화가 올 때까지 배지가 안 지워진다
    if (state == AppLifecycleState.resumed) _markSeen();
  }

  void _onData() {
    if (!mounted) return;
    // 다시 그리기 «전에» 내가 맨 아래를 보고 있었는지 봐 둔다.
    // 아래에 있었으면 새 대화를 따라 내려가고, 위쪽에서 옛 대화를 읽는 중이면 건드리지 않는다.
    final wasAtBottom = _atBottom;
    setState(() {});
    _markSeen();
    if (wasAtBottom && !_keepPosition) _scrollToBottom();
  }

  /// 지금 대화 맨 아래를 보고 있는지 (아직 안 그려졌으면 그렇다고 본다 — 첫 화면은 맨 아래여야 하므로)
  bool get _atBottom {
    if (!_scrollC.hasClients) return true;
    final p = _scrollC.position;
    return p.maxScrollExtent - p.pixels < 80;
  }

  void _onLive() {
    if (mounted) setState(() {});
  }

  /* 🚪 지금 보고 있는 방. `''` = 모두의 방, `'staff'` = 운영진 방.

     ⚠️ 앱에서 가리는 것만으로는 «비밀»이 되지 않는다 — 앱을 뜯으면 자료가 그대로 읽힌다.
        그래서 서버 규칙이 운영진 방을 직접 막는다(firestore.rules). 여기는 «화면»일 뿐이다.
     ⚠️ 운영진에서 내려온 사람이 이 값을 들고 있으면 안 된다 — 그릴 때 늘 다시 본다. */
  String _room = '';

  bool get _canStaffRoom => AppState.i.isAdmin;

  /// 차단한 회원의 대화는 내 화면에서 가린다 (지우는 것이 아니라 «나만 안 보는 것»)
  /// 그리고 «지금 보는 방»의 것만 남긴다 — 칸이 없는 옛 대화는 모두의 방이다.
  List<Map<String, dynamic>> get _msgs {
    final room = _canStaffRoom ? _room : ''; // 권한이 없어졌으면 모두의 방으로
    return Moderation.hide(AppState.i.by('msg'))
        .where((m) => ((m['room'] as String?) ?? '') == room)
        .toList();
  }

  /// 읽음 표시 — 남의 메시지를 어디까지 봤는지만 적는다.
  /// 내 것까지 세면 보낼 때마다 쓰기가 한 번 더 나가고, 단체방에선 그 쓰기가
  /// 구독 중인 회원 수만큼 읽기 요금으로 곱해진다.
  Future<void> _markSeen() async {
    // 보고 있지 않으면(딴 탭이거나 앱이 뒤에 있으면) 읽은 것이 아니다
    if (!countsAsRead(widget.active, WidgetsBinding.instance.lifecycleState)) return;
    final st = AppState.i;
    final code = st.code;
    if (code == null) return;
    final all = _msgs;
    if (all.isEmpty) return;

    final last = all.map((m) => ((m['createdAt'] as num?) ?? 0).toInt()).fold<int>(0, (a, b) => a > b ? a : b);
    if (last > st.lastSeenChat) st.lastSeenChat = last;

    final othersLast = all
        // 폰 바꾸기 «전»에 내가 쓴 말도 내 말이다 — 안 이으면 내 옛 말을 «남의 말»로 보고 읽음을 찍는다
        .where((m) => !Logic.isMe(m['by'] as String?, Store.i.myUid))
        .map((m) => ((m['createdAt'] as num?) ?? 0).toInt())
        .fold<int>(0, (a, b) => a > b ? a : b);
    final mine = ((st.couple?['lastRead'] as Map?)?[Store.i.myUid] as num?)?.toInt() ?? 0;
    if (othersLast > 0 && mine < othersLast) {
      /* 내 자리만 보낸다 — 사본을 통째로 보내면 낡은 남의 값이 최신 값을 덮어쓴다.
         일부러 안 기다린다: 읽음 표시 때문에 화면이 멈칫하면 안 된다 (실패해도 다음에 다시 적는다) */
      unawaited(Store.i.setCouple(code, {
        'lastRead': {Store.i.myUid: othersLast}
      }).catchError((_) {}));
    }
  }

  /* ⌨️ 「○○님이 입력 중…」은 **쓰지 않는다.**

     2026-08-30 사장님 결정 — 누가 글을 적고 있는지 남에게 알리지 않는다.
     동호회 대화방에서는 «보고 있다»는 것이 알려지는 것 자체가 부담이 된다
     (쓰다 지우면 그것도 상대에게 보였다).

     ⚠️ 덤으로 요금도 준다 — 이 값은 «글자를 칠 때마다» 서버에 쓰이는데,
        쓰기 한 번이 구독 중인 회원 수만큼 읽기 요금으로 곱해졌다.

     ⚠️ 읽는 쪽(`typingLive`)은 **지우지 않고 남겨 둔다** — 웹앱이 아직 이 값을 쓰고,
        옛 판 앱이 적어 둔 값이 남아 있을 수 있다. 우리는 «안 그릴» 뿐이다. */
  void _onTyping() {
    return; // 아무것도 보내지 않는다
    // ignore: dead_code
    final st = AppState.i;
    final code = st.code;
    if (code == null) return;
    final n = DateTime.now().millisecondsSinceEpoch;
    if (n - _typingSentAt < 3000) return;
    final lastSeen = (st.couple?['lastSeen'] as Map?)?.cast<String, dynamic>() ?? {};
    final anyWatching = lastSeen.entries.any((e) =>
        e.key != Store.i.myUid &&
        st.members.containsKey(e.key) &&
        n - (((e.value as num?) ?? 0).toInt()) < 600000);
    if (!anyWatching) return;
    _typingSentAt = n;
    Store.i.setCouple(code, {
      'typing': {Store.i.myUid: n}
    }).catchError((_) {});
  }

  Future<void> _send() async {
    final text = _textC.text.trim();
    if (text.isEmpty) return;
    final code = AppState.i.code;
    if (code == null) return;
    final reply = _replyTo;
    // 보내기에 실패하면 쓴 글을 되돌려준다 — 먼저 비우고 결과를 안 보면 쓴 글이 사라진다
    _textC.clear();
    setState(() => _replyTo = null);
    final id = await Store.i.addItem(code, {
      'type': 'msg',
      'text': text,
      // 운영진 방에서 쓴 말에는 표시를 남긴다 — 서버 규칙이 이 칸을 보고 막는다
      if (_canStaffRoom && _room.isNotEmpty) 'room': _room,
      if (reply != null) 'replyTo': reply['id'],
    });
    if (id == null) {
      /* ⚠️ 그냥 되돌려 넣으면 **그 사이 새로 쓰던 글을 덮어쓴다.**
         보내기는 최대 6초까지 걸리는데, 그동안 다음 말을 치고 있을 수 있다. */
      final busy = _textC.text.trim().isNotEmpty;
      if (!busy) _textC.text = text;
      if (mounted) {
        if (!busy) setState(() => _replyTo = reply);
        toast(context,
            busy ? '먼저 쓴 글을 보내지 못했어요 — 지금 쓰는 글은 그대로 뒀어요' : '보내지 못했어요 — 다시 눌러주세요');
      }
      return;
    }
    _scrollToBottom();
  }

  /// 사진 여러 장을 한 번에 보낸다 (웹앱과 같이 한 번에 5장까지).
  /// 5장으로 묶는 이유: 사진 한 장이 곧 메시지 1개라, 더 많이 보내면 단체방 전원에게
  /// 그만큼 알림과 읽기 요금이 곱해진다. 많이 올릴 때는 사진첩(게시판 탭)을 쓰면 된다.
  Future<void> _sendPhoto() async {
    final code = AppState.i.code;
    if (code == null) return;
/* ⚠️ 「세로」도 함께 줄여야 한다 — 가로만 줄이면 **세로로 긴 사진**(대화 스크린샷·
       파노라마)은 1600×6000 같은 크기로 남아 보관함 한도(2MB)를 넘는다.
       그러면 ① 이 사진이 안 올라가고 ② `savePhoto` 가 「보관함을 못 쓴다」고 보고
       **그 뒤로 앱을 끌 때까지 모든 사진이 7배 비싼 길(Firestore)로 간다.**
       (모임 상징 고르기는 처음부터 이렇게 하고 있었다 — 여기만 빠져 있었다) */
    var picked = await ImagePicker()
        .pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
    if (picked.isEmpty) return;
    if (picked.length > 5) {
      picked = picked.take(5).toList();
      if (mounted) toast(context, '한 번에 5장까지 보낼 수 있어요 (많은 사진은 사진첩에 올려주세요)');
    }
    if (mounted) toast(context, '사진 ${picked.length}장 올리는 중…');

    // 답장 중이었다면 첫 장에만 붙인다 (모든 장에 붙으면 대화가 어수선해진다)
    final reply = _replyTo;
    if (mounted && reply != null) setState(() => _replyTo = null);

    var fail = 0;
    for (var i = 0; i < picked.length; i++) {
      final bytes = await picked[i].readAsBytes();
      final photoId = await Store.i.savePhoto(code, bytes);
      if (photoId == null) {
        fail++;
        continue;
      }
      /* 🖼 웹은 사진을 «작은 그림» 칸으로만 그린다 — 안 넣으면 웹에서 깨져 보인다.
         못 만들어도 올리기는 그대로 간다(예전처럼 이 칸 없이 올라간다). */
      final thumb = await Store.makeThumb(bytes);
      final id = await Store.i.addItem(code, {
        'type': 'msg',
        'kind': 'img',
        'photoId': photoId,
        'text': '',
        if (i == 0 && reply != null) 'replyTo': reply['id'],
        if (thumb != null) 'thumb': thumb,
      });
      if (id == null) {
        // 글이 저장 안 됐으면 올린 원본도 남기지 않는다 (아무도 못 보는 파일에 저장료만 나간다)
        Store.i.dropPhotos([photoId]);
        fail++;
      }
    }
    if (mounted && fail > 0) {
      toast(
        context,
        fail == picked.length
            ? '사진을 보내지 못했어요 — 다시 시도해주세요'
            : '$fail장은 보내지 못했어요 — 다시 시도해주세요',
      );
    }
    _scrollToBottom();
  }

  /* 📊 투표 올리기 — 질문·항목을 받아 대화 한 건으로 보낸다.
     질문은 `poll.q` 와 `text` 에 «둘 다» 넣는다: 찾기·답장 미리보기·알림이 text 를 보고,
     투표를 모르는 옛 앱에서도 질문만은 보이게 하려는 것이다(빈 말풍선 방지). */
  Future<void> _newPoll() async {
    final code = AppState.i.code;
    if (code == null) return;
    final r = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true, // 글판이 올라와도 칸이 가려지지 않게
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: const PollForm(),
      ),
    );
    if (r == null || !mounted) return;
    final reply = _replyTo;
    final id = await Store.i.addItem(code, {
      'type': 'msg',
      'kind': 'poll',
      'text': r['q'],
      'poll': {
        'q': r['q'],
        'opts': r['opts'],
        'multi': r['multi'],
        'closed': false,
        // 기한을 안 골랐으면 이 칸이 아예 없다 (없음 = 기한 없는 투표)
        if (r['until'] != null) 'until': r['until'],
      },
      'votes': <String, dynamic>{},
      if (reply != null) 'replyTo': reply['id'],
    });
    if (!mounted) return;
    // 실패했는데 아무 말도 안 하면 올라간 줄 알고 회원들의 답을 기다린다
    if (id == null) return saveFailToast(context, '투표를 올리지 못했어요 — 다시 시도해주세요');
    setState(() => _replyTo = null);
    _scrollToBottom();
  }

  /* 그림이 자라 목록이 길어졌을 때 «맨 아래를 보고 있던 사람만» 따라 내려간다.

     ⚠️ 위에서 옛 대화를 읽는 중인 사람을 끌어내리면 안 된다 — 읽던 자리를 잃는다.
        그래서 자라기 «전»에 아래였는지 묻고(_atBottom), 아니면 아무것도 안 한다. */
  void _followGrowth() {
    if (!mounted || _keepPosition || !_scrollC.hasClients) return;
    final p = _scrollC.position;
    /* ⚠️ 여기서 `_atBottom`(80px)을 쓰면 안 된다 — 이 알림은 그림이 **이미 자란 뒤**에 온다.
       그 사이 아래쪽이 그림 높이만큼 밀려 나가서, 아래를 보고 있던 사람도
       「아래가 아니다」로 판정돼 버린다. 그림 한 장이 자라는 높이(폭 200에 세로로 긴 표면
       400~500px)를 여유로 준다. 옛 대화를 읽는 사람은 그보다 훨씬 위에 있어 안 끌려온다. */
    if (p.maxScrollExtent - p.pixels > 500) return;
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollC.hasClients) return;
      _scrollC.jumpTo(_scrollC.position.maxScrollExtent);
    });
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder) return;
    final code = AppState.i.code;
    if (code == null) return;
    setState(() => _loadingOlder = true);
    // 붙기 «전» 길이를 재 둔다 — 얼마나 위로 늘었는지 알아야 자리를 지킬 수 있다
    final before = _scrollC.hasClients ? _scrollC.position.maxScrollExtent : 0.0;
    int n;
    try {
      n = await Store.i.loadOlder(code);
    } catch (_) {
      /* ⚠️ 여기서 안 받아 내면 「불러오는 중…」이 **참인 채로 굳는다.**
         · 단추는 다시 눌리지도 않는다(맨 위에서 _loadingOlder 로 막혀 있다)
         · 게다가 _keepPosition 이 참으로 남아 **새 대화가 와도 화면이 안 내려간다** —
           대화는 오는데 화면이 안 따라가는, 까닭을 알 수 없는 고장이 된다.
         채팅 탭을 나갔다 들어와야 풀린다. */
      if (!mounted) return;
      setState(() => _loadingOlder = false);
      return toast(context, '옛 대화를 불러오지 못했어요 — 연결을 확인하고 다시 눌러주세요');
    }
    if (!mounted) return;
    setState(() => _loadingOlder = false);
    /* ⚠️ 옛 대화는 «위»에 붙는다. 스크롤 값은 그대로인데 위로 내용이 늘어나므로
       가만두면 화면이 **가장 오래된 대화로 튄다** — 읽던 자리를 잃고 한참을 다시 내려와야 한다.
       (2026-08-23 실측: 50건을 붙이자 맨 위가 «50개 더 옛것»으로 바뀌었다)
       늘어난 만큼 내려 주면 보고 있던 말이 그 자리에 그대로 남는다. */
    if (n > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollC.hasClients) return;
        final p = _scrollC.position;
        final grew = p.maxScrollExtent - before;
        if (grew > 0) _scrollC.jumpTo((p.pixels + grew).clamp(0.0, p.maxScrollExtent));
      });
    }
    if (n == 0) toast(context, '더 불러올 대화가 없어요');
  }

  /// 옛 대화를 불러오는 중에는 맨 아래로 끌어내리지 않는다 (읽던 자리를 잃는다)
  bool get _keepPosition => _loadingOlder;

  Future<void> _menu(Map<String, dynamic> m) async {
    /* ⚠️ 여기는 «권한»이다 — `Logic.isMe` 로 넓히면 안 된다.
       서버는 글에 적힌 번호만 보므로 폰 바꾸기 «전» 글은 지우기를 거절한다
       (화면에만 단추를 띄우면 눌러도 안 되는 헛단추가 된다). */
    final mine = m['by'] == Store.i.myUid;
    /* 운영진은 «남의 대화»도 지울 수 있다 — 서버 규칙이 그렇게 열어 두었고
       (firestore.rules 의 `allow delete` 가 방장·운영진에게 열어 준다 —
        규칙 주석에도 「남이 쓴 글·대화는 못 지운다(운영진·총괄은 예외)」라고 적혀 있다)
       게시판·사진첩은 처음부터 그렇게 하고 있었다. **채팅만 빠져 있어서**
       욕설·스팸이 올라와도 방장이 손을 못 댔다 —
       사진첩은 회원에게 「운영진은 모두 지울 수 있어요」라고 «알리기까지» 한다. */
    final canDelete = mine || AppState.i.isAdmin;
    final pick = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('❤️', style: TextStyle(fontSize: 22)),
              title: const Text('좋아요 남기기'),
              onTap: () => Navigator.pop(c, 'react'),
            ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('답장하기'),
              onTap: () => Navigator.pop(c, 'reply'),
            ),
            if (canDelete)
              ListTile(
                leading: Icon(Icons.delete_outline, color: dangerText(context)),
                title: Text('지우기', style: TextStyle(color: dangerText(context))),
                onTap: () => Navigator.pop(c, 'del'),
              ),
            /* 🚩🚫 남이 쓴 글에는 신고·차단이 있어야 한다 (애플 1.2 — 없으면 반려).
               내 글에는 보이지 않는다 — 자기 글을 신고하거나 자기를 차단할 일은 없다. */
            if (!mine && Moderation.canBlock(m['by'] as String?, Store.i.myUid)) ...[
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('신고하기'),
                onTap: () => Navigator.pop(c, 'report'),
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: Text('${AppState.i.nameOf(m['by'] as String?)}님 차단하기'),
                onTap: () => Navigator.pop(c, 'block'),
              ),
            ],
          ],
        ),
      ),
    );
    if (pick == null) return;
    final code = AppState.i.code;
    if (code == null) return; // 고르는 사이에 모임에서 빠졌을 수 있다
    if (pick == 'report') {
      return _report(m);
    } else if (pick == 'block') {
      return _block(m['by'] as String?);
    }
    if (pick == 'reply') {
      setState(() => _replyTo = m);
    } else if (pick == 'react') {
      var ok = false;
      try {
        ok = await Store.i.mutateItem(code, m['id'] as String, 'msg', (cur) {
          // ⚠️ 트랜잭션 콜백은 **서버 날것**을 받는다 — 들어올 때 고쳐 둔 값이 아니다
          final r = Logic.asMap(cur['reacts']);
          /* 폰을 바꾸기 «전» 번호로 남긴 것도 내 것이다 — 뗄 때는 **전부** 뗀다.
             안 그러면 옛 하트가 남아 한 사람인데 둘로 보이고, 그것을 영영 못 뗀다. */
          final mine = Logic.myReactKeys(r, Store.i.myUid);
          return {
            'reacts': mine.isEmpty
                ? {Store.i.myUid: '❤️'}
                : {for (final k in mine) k: Store.del}
          };
        });
      } catch (_) {
        ok = false;
      }
      // 창 밖(「더 보기」로 펼친 옛 대화)이면 구독이 안 알려준다 — 그 한 건만 다시 맞춘다
      await Store.i.syncOlder(m['id'] as String, 'msg');
      if (!mounted) return;
      if (!ok) return saveFailToast(context, '반응을 남기지 못했어요 — 연결을 확인해주세요');
    } else if (pick == 'del') {
      final ok = await Store.i.deleteItem(code, m['id'] as String, 'msg');
      // 창 밖이면 구독이 안 알려준다 — 안 빼면 «지운 대화가 화면에 그대로» 남는다
      if (ok) await Store.i.syncOlder(m['id'] as String, 'msg', removed: true);
      if (!mounted) return;
      if (!ok) return toast(context, '지우지 못했어요 — 다시 시도해주세요');
      // 되돌리기 시간이 지나면 사진 원본도 정리한다 (대기줄을 거치므로 실패해도 다음에 재시도)
      Store.i.dropPhotos(Store.photoIdsOf(m));
      toast(context, '메시지를 지웠어요');
    }
  }

  /* 🚩🚫 신고·차단은 «이용자 글이 보이는 모든 자리»가 같은 길을 쓴다(common.dart).
     여기서 따로 짜면 게시판 댓글 쪽과 어긋나고, 한쪽만 고쳐진다. */
  Future<void> _report(Map<String, dynamic> m) =>
      reportSheet(context, m, snippet: msgLabel(m));

  Future<void> _block(String? uid) => blockSheet(context, uid, () {});



  @override
  Widget build(BuildContext context) {
    final st = AppState.i;
    final msgs = _msgs;

    return Column(
      children: [
        /* 🚪 방 바꾸기 — **운영진에게만 보인다.**
           평회원에게 보이면 「눌러도 안 되는 문」이 되어 오히려 궁금해진다. */
        if (_canStaffRoom)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '', label: Text('모두의 방')),
                ButtonSegment(value: 'staff', label: Text('🔒 운영진')),
              ],
              selected: {_room},
              onSelectionChanged: (v) => setState(() => _room = v.first),
            ),
          ),
        Expanded(
          child: msgs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_room.isEmpty ? '🏸' : '🔒',
                          style: const TextStyle(fontSize: 44)),
                      const SizedBox(height: 10),
                      Text(_room.isEmpty ? '모임 단체 대화방이에요\n첫 인사를 건네보세요!' : '운영진끼리만 보는 방이에요\n회원에게는 보이지 않아요',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).hintColor, height: 1.5)),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollC,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: msgs.length + 1,
                  itemBuilder: (c, idx) {
                    if (idx == 0) {
                      if (!Store.i.hasOlder()) return const SizedBox.shrink();
                      return Center(
                        child: TextButton(
                          onPressed: _loadingOlder ? null : _loadOlder,
                          child: Text(_loadingOlder ? '불러오는 중…' : '↑ 이전 대화 더 보기'),
                        ),
                      );
                    }
                    final i = idx - 1;
                    final m = msgs[i];
                    final prev = i > 0 ? msgs[i - 1] : null;
                    final showDay = prev == null ||
                        _dayOf(prev) != _dayOf(m);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDay) _DayDivider(day: _dayOf(m)),
                        _Bubble(
                          msg: m,
                          prev: showDay ? null : prev,
                          isLastMine: _isLastMine(m, msgs),
                          readCount: _readCount(((m['createdAt'] as num?) ?? 0).toInt()),
                          othersCount: st.memberList.length - 1,
                          onLongPress: () => _menu(m),
                          onPhotoShown: _followGrowth,
                        ),
                      ],
                    );
                  },
                ),
        ),
        /* 「○○님이 입력 중…」은 **안 그린다** — 위 `_onTyping` 의 설명 참고.
           (웹앱이 적어 둔 값이 와도 이 화면에는 안 띄운다) */
        if (_replyTo != null)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.reply, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${st.nameOf(_replyTo!['by'] as String?)}: ${_preview(_replyTo!)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _replyTo = null),
                ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            color: Theme.of(context).cardColor,
            child: Row(
              children: [
                /* 단추가 셋이면 좁은 폰에서 입력칸이 눌린다 — 셋 다 좁혀서 넣는다
                   (실측: 360px 폰에서 기본 크기 그대로면 입력칸이 130px 밑으로 내려간다) */
                IconButton(
                  onPressed: _sendPhoto,
                  icon: const Icon(Icons.photo_outlined),
                  tooltip: '사진 보내기',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: _newPoll,
                  icon: const Icon(Icons.bar_chart_rounded),
                  tooltip: '투표 만들기',
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: TextField(
                    controller: _textC,
                    onChanged: (_) => _onTyping(),
                    minLines: 1,
                    maxLines: 4,
                    /* 대화 한 건은 **회원 전원에게 그대로 내려간다.**
                       다른 칸은 모두 길이를 막아 두었는데 여기만 열려 있어서,
                       긴 글을 붙여 넣으면 그 크기가 «회원 수만큼» 곱해진다.
                       2000자면 보통 대화(200~300자)의 예닐곱 배라 넉넉하다. */
                    maxLength: 2000,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: '메시지 입력',
                      counterText: '', // 입력 줄이 좁다 — 숫자는 안 보여준다
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _send,
                  icon: const Icon(Icons.send, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _dayOf(Map<String, dynamic> m) =>
      ymd(DateTime.fromMillisecondsSinceEpoch(((m['createdAt'] as num?) ?? 0).toInt()));

  bool _isLastMine(Map<String, dynamic> m, List<Map<String, dynamic>> all) {
    for (var i = all.length - 1; i >= 0; i--) {
      if (Logic.isMe(all[i]['by'] as String?, Store.i.myUid)) return identical(all[i], m);
    }
    return false;
  }

  /// 나를 뺀 회원 중 이 메시지 시각 이후를 읽은 사람 수.
  int _readCount(int at) {
    final st = AppState.i;
    final reads = (st.couple?['lastRead'] as Map?)?.cast<String, dynamic>() ?? {};
    var n = 0;
    reads.forEach((uid, v) {
      if (uid == Store.i.myUid) return;
      if (!st.members.containsKey(uid)) return;
      if ((((v as num?) ?? 0).toInt()) >= at) n++;
    });
    return n;
  }

  String _preview(Map<String, dynamic> m) => msgLabel(m);
}

class _DayDivider extends StatelessWidget {
  final String day;
  const _DayDivider({required this.day});
  @override
  Widget build(BuildContext context) {
    final isToday = day == ymd(DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(isToday ? '오늘' : fmtDateFull(day),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final Map<String, dynamic>? prev;
  final bool isLastMine;
  final int readCount;
  final int othersCount;
  final VoidCallback onLongPress;
  /// 사진이 그려져 «키가 자랐을 때» 알린다 — 목록이 따라 내려갈 수 있게
  final VoidCallback onPhotoShown;

  const _Bubble({
    required this.msg,
    required this.prev,
    required this.isLastMine,
    required this.readCount,
    required this.othersCount,
    required this.onLongPress,
    required this.onPhotoShown,
  });

  @override
  Widget build(BuildContext context) {
    final st = AppState.i;
    final cs = Theme.of(context).colorScheme;
    /* 폰을 바꾸기 «전»에 쓴 내 말도 내 말이다 — 안 이으면 지난 대화가 통째로
       «남의 말풍선»(왼쪽·내 아바타·내 이름이 얹힌 채)으로 보인다. */
    final mine = Logic.isMe(msg['by'] as String?, Store.i.myUid);
    final at = ((msg['createdAt'] as num?) ?? 0).toInt();
    // 같은 사람이 3분 안에 연달아 보낸 것은 얼굴·이름을 한 번만 (대화가 덜 어수선하게)
    final grouped = prev != null &&
        prev!['by'] == msg['by'] &&
        (at - (((prev!['createdAt'] as num?) ?? 0).toInt())).abs() < 180000;

    final reacts = Logic.reactEmojis(msg['reacts']); // 폰 바꾸기 전후는 «한 사람»
    final replyId = msg['replyTo'] as String?;
    // 말풍선마다 전체를 훑지 않는다 — 미리 만들어 둔 표에서 바로 찾는다
    final replied = st.byId(replyId);

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: msg['kind'] == 'img'
          ? const EdgeInsets.all(4)
          : const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: mine ? cs.primary : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyId != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                // 내 말풍선은 글씨가 onPrimary 다 — 띠까지 같은 색으로 깔면 서로 묻힌다.
                // 글씨의 «반대쪽»으로 눌러야 읽힌다 (theme.dart quoteTint 참고)
                color: (mine ? quoteTint(context) : cs.primary)
                    .withValues(alpha: quoteTintAlpha),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                /* 답장을 단 원래 대화가 아직 안 불러와졌거나 지워졌으면 `replied`가 없다.
                   그때 인용을 통째로 빼면 **그냥 보통 말처럼 보여** 무슨 얘기에 답한 건지 알 수 없다. */
                replied == null
                    ? '↩ 지난 대화'
                    : '${st.nameOf(replied['by'] as String?)}: '
                        '${msgLabel(replied.cast<String, dynamic>())}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    color: mine ? cs.onPrimary : null),
              ),
            ),
          if (msg['kind'] == 'img')
            /* 그림이 그려지면 높이가 늘어난다 — 그때 «아래를 보고 있었으면» 따라 내려간다.
               안 그러면 방금 올라온 사진이 화면 밖으로 밀려 회원이 못 보고 지나친다
               (2026-08-29: 총무가 올린 회비 표가 실제로 그렇게 안 보였다). */
            ClubPhoto(
                photoId: msg['photoId'] as String?,
                width: 200,
                decodeWidth: 600,
                onShown: onPhotoShown)
          else if (msg['kind'] == 'poll')
            PollCard(msg: msg, mine: mine, myUid: Store.i.myUid)
          else
            Text(
              msgLabel(msg),
              style: TextStyle(fontSize: 15, height: 1.35, color: mine ? cs.onPrimary : null),
            ),
          if (reacts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(reacts, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );

    final meta = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (mine && isLastMine && othersCount > 0)
            Text(
              readCount > 0 ? '읽음 $readCount' : '안읽음',
              style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.w700),
            ),
          Text(fmtHm(at),
              style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: grouped ? 2 : 10),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Row(
          mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine)
              SizedBox(
                width: 38,
                child: grouped ? null : Avatar(msg['by'] as String?, size: 34),
              ),
            if (!mine) const SizedBox(width: 6),
            if (mine) meta,
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine && !grouped)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 3),
                      child: Text(
                        st.nameOf(msg['by'] as String?),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  bubble,
                ],
              ),
            ),
            if (!mine) meta,
          ],
        ),
      ),
    );
  }
}

/* 📊 투표 말풍선 ────────────────────────────────────────────────────
   ⚠️ 안쪽 «항목 칸»은 자기 색(cardColor)을 쓴다 — 내 말풍선은 바탕이 진하고 글씨가 흰색이라
      물려받으면 글씨가 안 보이고, 밤 화면에서는 흰 고정색이 눈을 찌른다.
   ⚠️ 표는 «내 자리»(votes.내번호)만 적는다. 통째로 덮어쓰면 그 사이 남이 찍은 표가 사라진다. */
class PollCard extends StatefulWidget {
  final Map<String, dynamic> msg;

  /// 내 말풍선인지 (바탕이 진하다)
  final bool mine;

  /// 내 번호. 밖에서 받는다 — 그려 보는 시험이 Firebase 없이도 띄울 수 있게.
  final String myUid;
  const PollCard(
      {super.key, required this.msg, required this.mine, required this.myUid});

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  bool _busy = false;

  Future<void> _vote(int i) async {
    if (_busy) return;
    final code = AppState.i.code;
    if (code == null) return;
    final id = widget.msg['id'] as String;
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await Store.i.mutateItem(code, id, 'msg', (cur) {
        // ⚠️ 트랜잭션 콜백은 **서버 날것**을 받는다 — 지금 화면의 값이 아니다
        final p = Logic.poll(cur);
        if (p.closed) return null; // 그 사이 마감됐다면 아무것도 쓰지 않는다
        if (i < 0 || i >= p.opts.length) return null;
        final next = Logic.pollNext(Logic.pollMine(cur, Store.i.myUid), i, p.multi);
        return {
          'votes': {
            // 폰을 바꾸기 «전» 번호로 남은 옛 표는 함께 뗀다 (안 떼면 한 사람이 두 번 세진다)
            for (final k in Logic.pollOldKeys(cur, Store.i.myUid)) k: Store.del,
            Store.i.myUid: next.isEmpty ? Store.del : next,
          }
        };
      });
    } catch (_) {
      ok = false;
    }
    // 창 밖(「이전 대화 더 보기」로 펼친 것)이면 구독이 안 알려준다 — 그 한 건만 다시 맞춘다
    await Store.i.syncOlder(id, 'msg');
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) toast(context, '투표하지 못했어요 — 다시 눌러주세요');
  }

  Future<void> _setClosed(bool closed) async {
    final code = AppState.i.code;
    if (code == null) return;
    final id = widget.msg['id'] as String;
    var ok = false;
    try {
      ok = await Store.i.mutateItem(code, id, 'msg', (cur) => {
            'poll': {'closed': closed}
          });
    } catch (_) {
      ok = false;
    }
    await Store.i.syncOlder(id, 'msg');
    if (!mounted) return;
    if (!ok) return toast(context, '바꾸지 못했어요 — 다시 시도해주세요');
    toast(context, closed ? '투표를 마감했어요 🔒' : '투표를 다시 열었어요');
  }

  void _who() {
    final st = AppState.i;
    final p = Logic.poll(widget.msg);
    final t = Logic.pollTally(widget.msg);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📊 ${p.q}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              for (var i = 0; i < p.opts.length; i++) ...[
                Text('${p.opts[i]} · ${t.per[i].length}명',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Padding(
                  padding: const EdgeInsets.only(top: 3, bottom: 10),
                  child: Text(
                    t.per[i].isEmpty ? '아직 없어요' : t.per[i].map(st.nameOf).join(' · '),
                    style: TextStyle(fontSize: 12, color: Theme.of(c).hintColor),
                  ),
                ),
              ],
              Text('${t.voters}명이 투표했어요${p.multi ? ' (여러 개 고를 수 있는 투표예요)' : ''}',
                  style: TextStyle(fontSize: 12, color: Theme.of(c).hintColor)),
            ],
          ),
        ),
      ),
    );
  }

  /* ⏳ 기한이 되는 «그 순간» 스스로 다시 그린다.
     안 그러면 대화방을 보고 있어도 「투표 중」인 채로 남아, 눌러 봐야 그때 닫힌 걸 안다. */
  Timer? _dueTick;

  @override
  void dispose() {
    _dueTick?.cancel();
    super.dispose();
  }

  /* 남은 시간을 회원 말로 — 「2시간 남음」·「10분 남음」.
     ⚠️ 분 단위까지만 센다. 초까지 보여 주면 1초마다 다시 그려야 하고,
        회원에게도 쫓기는 느낌만 준다. */
  static String _leftLabel(int? until) {
    if (until == null) return '';
    final left = until - DateTime.now().millisecondsSinceEpoch;
    if (left <= 0) return '';
    final m = left ~/ 60000;
    if (m < 60) return ' · ${m < 1 ? 1 : m}분 남음';
    final h = m ~/ 60;
    if (h < 24) return ' · $h시간 남음';
    return ' · ${h ~/ 24}일 남음';
  }

  void _armDueTick() {
    _dueTick?.cancel();
    final left = Logic.pollLeftMs(widget.msg);
    if (left == null) return;
    _dueTick = Timer(Duration(milliseconds: left + 200), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    _armDueTick();
    final cs = Theme.of(context).colorScheme;
    final p = Logic.poll(widget.msg);
    final t = Logic.pollTally(widget.msg);
    final mine = Logic.pollMine(widget.msg, widget.myUid);
    final top = t.per.fold<int>(0, (a, b) => b.length > a ? b.length : a);
    /* 마감·다시 열기는 만든 사람과 운영진만. 서버는 회원이면 고칠 수 있게 열려 있어
       화면에서 막는다 (반응·고정과 같은 잣대). 폰 바꾸기 전 글도 «내 글»로 본다 —
       여기는 지우기 같은 권한이 아니라 «누가 만들었나»이고, 서버도 회원이면 받아 준다. */
    final boss =
        Logic.isMe(widget.msg['by'] as String?, widget.myUid) || AppState.i.isAdmin;
    final onDark = widget.mine ? cs.onPrimary : null;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 190),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // 안 적으면 «남은 높이를 다 차지한다» — 말풍선 하나가 화면을 덮는다(실측 682px)
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 9, top: 1),
            child: Text('📊 ${p.q}',
                style: TextStyle(
                    fontSize: 14, height: 1.4, fontWeight: FontWeight.w800, color: onDark)),
          ),
          for (var i = 0; i < p.opts.length; i++)
            _Option(
              label: p.opts[i],
              count: t.per[i].length,
              percent: t.voters == 0 ? 0 : t.per[i].length / t.voters,
              picked: mine.contains(i),
              // 마감된 뒤에는 가장 많이 받은 항목에 왕관 (결과가 한눈에 보이게)
              won: p.closed && t.per[i].isNotEmpty && t.per[i].length == top,
              onTap: p.closed || _busy ? null : () => _vote(i),
              /* 👥 누가 골랐는지 «바로» 보여 준다 — 예전에는 「누가 골랐나」를
                 눌러야만 알 수 있어서, 투표 중에 판을 읽으려면 매번 창을 열어야 했다.
                 얼굴만 깔면 한눈에 들어오고, 자세한 이름은 그 창이 그대로 맡는다. */
              faces: t.per[i].map(AppState.i.emojiOf).toList(),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 2,
              children: [
                Text(
                  '${t.voters == 0 ? '아직 아무도 안 골랐어요' : '${t.voters}명 참여'}'
                  '${p.multi ? ' · 복수 선택' : ''}'
                  /* 기한이 있는 투표는 «언제 끝나는지»가 참여를 좌우한다 —
                     끝난 뒤에는 「종료」라고 분명히 알려야 다시 누르지 않는다. */
                  '${p.closed ? (p.until != null ? ' · 투표가 종료되었습니다' : ' · 🔒 마감') : _leftLabel(p.until)}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: onDark ?? Theme.of(context).hintColor),
                ),
                if (t.voters > 0)
                  _FootButton(label: '누가 골랐나', onTap: _who, onPrimary: widget.mine),
                if (boss)
                  _FootButton(
                    label: p.closed ? '다시 열기' : '마감하기',
                    onTap: () => _setClosed(!p.closed),
                    onPrimary: widget.mine,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 투표 항목 한 칸 — 고른 사람 비율만큼 띠가 찬다.
class _Option extends StatelessWidget {
  final String label;
  final int count;
  final double percent;
  final bool picked;
  final bool won;
  final VoidCallback? onTap;

  /// 이 항목을 고른 사람들의 얼굴 — 투표 중에도 바로 보인다
  final List<String> faces;

  const _Option({
    required this.label,
    required this.count,
    required this.percent,
    required this.picked,
    required this.won,
    required this.onTap,
    this.faces = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = BorderRadius.circular(12);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Theme.of(context).cardColor,
        // ⚠️ shape 와 borderRadius 를 «함께» 주면 Flutter 가 그 자리에서 터진다
        //    (말풍선이 빨간 오류 상자가 된다 — web_shape_test 가 잡아 줬다)
        shape: RoundedRectangleBorder(
          borderRadius: r,
          side: BorderSide(color: picked ? cs.primary : cs.outlineVariant, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // 띠는 «글씨 뒤»에 깔린다 — 흐리게 깔아야 글씨가 묻히지 않는다
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percent.clamp(0.0, 1.0),
                  child: ColoredBox(color: cs.primary.withValues(alpha: 0.16)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  children: [
                    if (picked)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Icon(Icons.check_circle, size: 15, color: cs.primary),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            won ? '👑 $label' : label,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: picked ? cs.primary : null,
                            ),
                          ),
                          /* 👥 고른 사람 얼굴 — 투표 중에도 «바로» 보인다.
                             ⚠️ 여섯까지만. 큰 모임에서 다 그리면 말풍선이 화면을 덮는다.
                                자세한 이름은 「누가 골랐나」가 그대로 맡는다. */
                          if (faces.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                faces.take(6).join(' ') +
                                    (faces.length > 6 ? ' +${faces.length - 6}' : ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ),
                    /* ⚠️ 「N명 NN%」도 «자리를 나눠 갖게» 한다.
                       폰 설정에서 글자를 키운 회원(중장년 동호회에는 흔하다)이
                       좁은 폰(360px)으로 보면 이 줄이 오른쪽으로 넘쳤다 —
                       2026-08-29 실측 43픽셀. 넘친 자리는 아예 못 누른다. */
                    if (count > 0)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text('$count명 ${(percent * 100).round()}%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).hintColor)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 투표 카드 밑에 놓는 작은 글씨 단추 (누가 골랐나 · 마감하기)
class _FootButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool onPrimary;
  const _FootButton({required this.label, required this.onTap, required this.onPrimary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = onPrimary ? cs.onPrimary : cs.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: c,
              decoration: TextDecoration.underline,
              decorationColor: c,
            )),
      ),
    );
  }
}

/* 📊 투표 만들기 — 질문 하나와 항목 2~8개.
   ⚠️ 항목 칸은 «컨트롤러»로 들고 있는다. 다시 그릴 때마다 새로 만들면
      한 칸을 더하거나 뺄 때 **적던 글이 사라진다.** */
class PollForm extends StatefulWidget {
  const PollForm({super.key});

  /// 항목은 8개까지 — 더 늘리면 말풍선이 화면을 다 덮고, 고르는 사람도 헷갈린다
  static const maxOpts = 8;

  @override
  State<PollForm> createState() => _PollFormState();
}

class _PollFormState extends State<PollForm> {
  final _q = TextEditingController();
  final _opts = [TextEditingController(), TextEditingController()];
  bool _multi = false;

  /* ⏳ 몇 «시간» 뒤에 끝낼까. 0이면 기한 없음(사람이 손으로 마감).
     ⚠️ 「며칠 뒤」가 아니라 시간으로 센다 — 동호회 투표는 「오늘 저녁까지」처럼
        하루 안에 끝나는 것이 대부분이라, 날짜로만 고르게 하면 늘 넉넉히 잡게 된다. */
  int _hours = 0;
  static const _hourChoices = <int, String>{
    0: '기한 없음',
    3: '3시간',
    6: '6시간',
    24: '하루',
    72: '사흘',
    168: '일주일',
  };

  @override
  void dispose() {
    _q.dispose();
    for (final c in _opts) {
      c.dispose();
    }
    super.dispose();
  }

  void _send() {
    final q = _q.text.trim();
    final opts = _opts.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (q.isEmpty) return toast(context, '무엇을 물어볼지 적어주세요');
    if (opts.length < 2) return toast(context, '고를 항목을 2개 이상 적어주세요');
    if (opts.toSet().length != opts.length) return toast(context, '같은 항목이 두 번 있어요');
    Navigator.pop(context, {
      'q': q,
      'opts': opts,
      'multi': _multi,
      // 기한 없음(0)이면 아예 안 보낸다 — 칸이 없는 것이 «기한 없음»이다
      if (_hours > 0)
        'until': DateTime.now()
            .add(Duration(hours: _hours))
            .millisecondsSinceEpoch,
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📊 투표 만들기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
              controller: _q,
              // 60자 — 다듬기가 «한 줄 칸»을 자르는 길이와 맞춘다 (input_fits_test 가 지켜본다)
              maxLength: 60,
              maxLines: 2,
              minLines: 1,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '무엇을 물어볼까요?',
                hintText: '예) 이번 주 토요일 번개 어때요?',
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < _opts.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _opts[i],
                        maxLength: 30,
                        maxLines: 1,
                        decoration: InputDecoration(
                          labelText: '${i + 1}번째 항목',
                          counterText: '',
                        ),
                      ),
                    ),
                    if (_opts.length > 2)
                      IconButton(
                        tooltip: '${i + 1}번째 항목 빼기',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _opts.removeAt(i).dispose()),
                      ),
                  ],
                ),
              ),
            if (_opts.length < PollForm.maxOpts)
              TextButton.icon(
                onPressed: () => setState(() => _opts.add(TextEditingController())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('항목 추가'),
              ),
            /* ⏳ 언제까지 받을지 — 고른 시각이 지나면 투표가 «저절로» 끝난다.
               사람이 마감하기를 기다리면 잊은 투표가 몇 달씩 열린 채 남는다. */
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text('언제까지 받을까요',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).hintColor)),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _hourChoices.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _hours == e.key,
                    onSelected: (_) => setState(() => _hours = e.key),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _multi,
              onChanged: (v) => setState(() => _multi = v),
              title: const Text('여러 개 고르기', style: TextStyle(fontSize: 14)),
              subtitle:
                  const Text('한 사람이 여러 항목을 고를 수 있어요', style: TextStyle(fontSize: 12)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('누가 무엇을 골랐는지 회원 모두가 볼 수 있어요 (비밀 투표는 아니에요)',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(onPressed: _send, child: const Text('투표 올리기')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
