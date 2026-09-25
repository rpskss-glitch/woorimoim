import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../logic.dart';
import '../moderation.dart';
import '../comments.dart';
import '../state.dart';
import '../store.dart';
import 'album.dart';
import 'common.dart';
import 'post_screen.dart';

/// 📔 게시판 + 📸 사진첩.
class BoardTab extends StatefulWidget {
  const BoardTab({super.key});
  @override
  State<BoardTab> createState() => _BoardTabState();
}

class _BoardTabState extends State<BoardTab> {
  int _tab = 0; // 0=글 1=사진

  @override
  void initState() {
    super.initState();
    AppState.i.addListener(_r);
    AppState.i.openAction.addListener(_onAction);
    // 이 탭이 «방금 처음» 떴다면, 홈이 남겨 둔 할 일이 이미 기다리고 있을 수 있다
    WidgetsBinding.instance.addPostFrameCallback((_) => _onAction());
  }

  @override
  void dispose() {
    AppState.i.removeListener(_r);
    AppState.i.openAction.removeListener(_onAction);
    super.dispose();
  }

  /* ✏️ 홈의 「글 쓰기」 — 게시판으로 옮기는 데서 그치지 않고 **글쓰기 창까지** 연다.
     ⚠️ 예전에는 탭만 옮겼다. 게시판을 마지막에 「사진」 칸으로 두었으면
        「사진 올리기」 화면이 떠서, 글을 쓰러 왔는데 사진 화면이 나왔다(2026-09-25 조사). */
  void _onAction() {
    if (!mounted || AppState.i.openAction.value != 'write') return;
    AppState.i.openAction.value = null; // 한 번만 — 안 비우면 탭을 옮길 때마다 창이 또 뜬다
    setState(() => _tab = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _writePost(context);
    });
  }

  /* 📸 사진 여러 장 올리기는 «오래 걸리는 일»이다 — 한 장마다 작은 그림을 만들고 올린다.
     그동안 단추가 그대로 눌리면 **같은 사진이 두 번 올라간다**(사진첩에도 두 장, 요금도 두 배).
     처음 띄운 「…장 올리는 중」 토스트는 몇 초 뒤 사라지므로 그것만으로는 진행을 알 수 없다.
     그래서 «몇 장째인지»를 단추에 계속 보여 주고, 그동안은 못 누르게 한다. */
  bool _upBusy = false;
  int _upDone = 0, _upTotal = 0;

  /* 화면을 다시 그린다. ⚠️ **아직 그 화면이 있는지 보고** 그린다 —
     이 함수는 «오래 걸리는 일이 끝난 뒤»(사진 지우기·기록 지우기) 자식 화면이 불러 주는데,
     그 사이 모임에서 빠지거나 방이 없어져 화면이 사라졌을 수 있다.
     없어진 화면을 고치려 하면 Flutter 가 터진다(분석기는 setState 를 안 본다 — 183회차). */
  void _r() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
          /* ⚠️ «달리는 이름(heroTag)»을 안 주면 Flutter 가 모두 같은 이름을 쓴다.
             탭 다섯이 IndexedStack 으로 «동시에 살아 있어» 한 화면에 둥근 단추가 여럿이다.
             그러면 화면을 옮길 때 「같은 이름이 둘」이라며 **앱이 빨간 화면으로 터진다** —
             2026-08-29 설정에서 「월 회비」을 저장하는 순간 실제로 터졌고,
             이미 나간 판에도 그대로 들어 있었다. */
          heroTag: 'board-write',  // 게시판 글 쓰기
        onPressed: _upBusy
            ? null
            : (_tab == 0 ? () => _writePost(context) : () => _addPhotos(context)),
        icon: _upBusy
            ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(_tab == 0 ? Icons.edit_outlined : Icons.add_photo_alternate_outlined),
        label: Text(_upBusy
            ? '$_upDone/$_upTotal 올리는 중…'
            : (_tab == 0 ? '글 쓰기' : '사진 올리기')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('글')),
                ButtonSegment(value: 1, label: Text('사진')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Expanded(child: _tab == 0 ? _posts(context) : _photos(context)),
        ],
      ),
    );
  }

  Widget _posts(BuildContext context) {
    // 공지가 위로 — 안 그러면 「공지로 올리기」가 하는 일이 없다
    /* 차단한 회원의 글은 내 화면에서 가린다 (애플 1.2 — 차단이 한 화면에만 있으면 안 된다)

       ⚠️ `[...]` 로 **복사한 뒤** 정렬한다. `by(...)` 가 주는 것은 «앱이 들고 있는 그 목록»이라,
          제자리에서 뒤섞으면 그 차례를 믿는 다른 화면이 엉뚱한 순서를 보게 된다.
          게다가 글이 하나도 없으면 «고칠 수 없는 빈 목록»이 와서 정렬하는 순간 **터진다**
          (2026-08-29: 이상한 자료로 게시판을 그려 보다 잡았다). */
    final rows = [...Moderation.hide(AppState.i.by('diary'))]..sort(Logic.byNotice);
    if (rows.isEmpty) {
      return Center(
        child: Text('아직 올라온 글이 없어요\n공지나 후기를 남겨보세요',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).hintColor, height: 1.6)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (c, i) => _PostCard(item: rows[i], onChanged: _r),
    );
  }

  /* 📸 사진첩 — **웹앱과 같은 사진첩**(설명·태그·즐겨찾기·반응·정리).
     예전에는 여기에 격자만 있었다. 그래서 웹으로 정리한 회원과 앱만 쓰는 회원이
     서로 다른 사진첩을 봤다 — 앨범 쪽에 모아 두고 여기서는 부르기만 한다. */
  Widget _photos(BuildContext context) => AlbumView(onChanged: _r);

  Future<void> _writePost(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => const _PostForm(),
    );
    if (ok == true) _r();
  }

  /// 여러 장을 한 번에 — 실패한 장수도 정확히 알려준다.
  Future<void> _addPhotos(BuildContext context) async {
    if (_upBusy) return; // 올리는 중에 또 누르면 같은 사진이 두 번 올라간다
    final code = AppState.i.code;
    if (code == null) return;
    /* 🔒 잠긴 모임이면 고르기 «전에» 말한다.
       ⚠️ 예전에는 20장을 고르면 20장을 다 올린 뒤 기록이 거절돼 하나씩 도로 지우고,
          「0장 올렸어요 (20장 실패 — 다시 시도해주세요)」라고 했다 — 이용권 얘기는 없이
          연결 탓처럼 들렸다(2026-09-25 조사). */
    final locked = Store.lockReason();
    if (locked != null) return toast(context, locked);
    /* ⚠️ 「세로」도 함께 줄여야 한다 — 가로만 줄이면 **세로로 긴 사진**(대화 스크린샷·
       파노라마)은 1600×6000 같은 크기로 남아 보관함 한도(2MB)를 넘는다.
       그러면 ① 이 사진이 안 올라가고 ② `savePhoto` 가 「보관함을 못 쓴다」고 보고
       **그 뒤로 앱을 끌 때까지 모든 사진이 7배 비싼 길(Firestore)로 간다.**
       (모임 상징 고르기는 처음부터 이렇게 하고 있었다 — 여기만 빠져 있었다) */
    final picked = await ImagePicker()
        .pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
    if (picked.isEmpty) return;
    if (!context.mounted) return;
    toast(context, '사진 ${picked.length}장 올리는 중…');
    setState(() {
      _upBusy = true;
      _upDone = 0;
      _upTotal = picked.length;
    });

    var ok = 0, fail = 0;
    try {
      for (final x in picked) {
        try {
          final bytes = await x.readAsBytes();
          final photoId = await Store.i.savePhoto(code, bytes);
          if (photoId == null) {
            fail++;
            continue;
          }
          /* 🖼 웹은 사진을 «작은 그림» 칸으로만 그린다 — 안 넣으면 웹에서 깨져 보인다.
             못 만들어도 올리기는 그대로 간다(예전처럼 이 칸 없이 올라간다). */
          final thumb = await Store.makeThumb(bytes);
          final id = await Store.i.addItem(code, {
            'type': 'photo',
            'photoId': photoId,
            'date': ymd(DateTime.now()),
            if (thumb != null) 'thumb': thumb,
          });
          if (id == null) {
            // 기록이 안 남았으면 원본도 지운다 — 안 그러면 아무도 못 보는 파일에 저장료만 나간다
            Store.i.dropPhotos([photoId]);
            fail++;
          } else {
            ok++;
          }
        } finally {
          /* 진행 수는 **어느 길로 끝나든** 오른다 — 건너뛰는 길(continue)에서 빠뜨리면
             실패한 장부터 숫자가 멈춰 「멈춘 것」처럼 보인다. */
          if (mounted) setState(() => _upDone = ok + fail);
        }
      }
    } finally {
      // 도중에 터져도 «단추는 반드시» 되살린다 — 안 그러면 다시는 못 올린다
      if (mounted) setState(() => _upBusy = false);
    }
    if (!context.mounted) return;
    toast(context,
        fail == 0 ? '사진 $ok장을 올렸어요 📸' : '$ok장 올렸어요 ($fail장 실패 — 다시 시도해주세요)');
    _r();
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onChanged;
  const _PostCard({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final st = AppState.i;
    /* ⚠️ 여기는 «권한»이다 — 폰 바꾸기 «전» 번호까지 넓히면 안 된다.
       서버는 글에 적힌 번호만 보므로 지우기를 거절한다(눌러도 안 되는 헛단추가 된다). */
    final mine = item['by'] == Store.i.myUid;
    final notice = item['notice'] == true;
    final pinned = item['pinned'] == true;
    final id = item['id'] as String?;
    /* 🚩 남의 글에는 신고·차단 — 애플 1.2. 예전에는 메뉴가 내 글·운영진에게만 떠서
       회원은 게시판 글을 신고할 길이 없었다(2026-09-25 조사).
       «남인가»는 폰 바꾸기 전 번호까지 이어 본다(Moderation.canBlock). */
    final canReport = Moderation.canBlock(item['by'] as String?, Store.i.myUid);
    /* 📄 글을 누르면 «글 안»으로 들어간다 — 거기서 전문을 읽고 댓글을 단다.
       목록에서는 글이 잘려 보이므로, 들어갈 길이 없으면 뒷내용을 읽을 방법이 아예 없다. */
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: id == null
          ? null
          : () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => PostScreen(postId: id))),
      child: SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(item['by'] as String?, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 📌 는 «글»에 붙는 표시다 — 이름 옆에 두면 사람이 공지인 것처럼 보인다
                    Text(st.nameOf(item['by'] as String?),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(item['date'] as String? ?? '',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                  ],
                ),
              ),
              if (mine || st.isAdmin || canReport)
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'report') {
                      return reportSheet(context, item, snippet: postSnippet(item));
                    }
                    if (v == 'block') {
                      return blockSheet(context, item['by'] as String?, onChanged);
                    }
                    /* 📌 위에 고정 — 회칙·계좌번호처럼 «늘 맨 위에 있어야 하는 글».
                       ⚠️ 운영진만 할 수 있다. 글쓴이 아무나 고정하면
                          너도나도 올려 붙여 게시판 맨 위가 뒤죽박죽이 된다. */
                    if (v == 'pin') {
                      final code = st.code;
                      final id = item['id'] as String?;
                      if (code == null || id == null) return;
                      /* ⚠️ 서버가 거절하면(이용권 만료·권한) 던진다 — 안 받으면
                            «눌렀는데 아무 일도 없는 단추»가 된다. 실패를 말로 알린다. */
                      try {
                        await Store.i.updateItem(code, id, 'diary', {'pinned': !pinned});
                      } catch (_) {
                        if (context.mounted) {
                          toast(context, pinned
                              ? '고정을 풀지 못했어요 — 다시 시도해주세요'
                              : '고정하지 못했어요 — 다시 시도해주세요');
                        }
                        return;
                      }
                      if (!context.mounted) return;
                      toast(context, pinned ? '고정을 풀었어요' : '맨 위에 고정했어요 📌');
                      onChanged();
                      return;
                    }
                    if (v != 'del') return;
                    final ok = await confirmSheet(context, '이 글을 지울까요?', '되돌릴 수 없어요',
                        okLabel: '지우기', danger: true);
                    if (!ok) return;
                    final code = st.code;
                    if (code == null) return;
                    final done =
                        await Store.i.deleteItem(code, item['id'] as String, 'diary');
                    if (!context.mounted) return;
                    if (!done) return toast(context, '지우지 못했어요 — 다시 시도해주세요');
                    Store.i.dropPhotos(Store.photoIdsOf(item));
                    // 딸린 댓글도 함께 — 안 지우면 «주인 없는 댓글»이 영영 남는다
                    await Comments.removeAllOf(item['id'] as String);
                    if (!context.mounted) return;
                    toast(context, '글을 지웠어요');
                    onChanged();
                  },
                  itemBuilder: (_) => [
                    if (st.isAdmin)
                      PopupMenuItem(
                          value: 'pin',
                          child: Text(pinned ? '고정 풀기' : '📌 맨 위에 고정')),
                    if (mine || st.isAdmin)
                      const PopupMenuItem(value: 'del', child: Text('지우기')),
                    if (canReport) ...[
                      const PopupMenuItem(value: 'report', child: Text('신고하기')),
                      const PopupMenuItem(value: 'block', child: Text('이 사람 차단')),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (pinned) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('📌 고정',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
          ],
          if (notice) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('📌 공지',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
          ],
          if ((item['title'] as String?)?.isNotEmpty == true) ...[
            Text(Moderation.mask(item['title'] as String),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
          ],
          /* 목록에서는 «앞부분만» 보인다 — 길면 글 하나가 화면을 통째로 먹어
             다음 글이 있는지조차 알 수 없다. 전문은 눌러 들어가서 읽는다. */
          Text(Moderation.mask(item['text'] as String?),
              style: const TextStyle(height: 1.6),
              maxLines: 4,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.mode_comment_outlined,
                  size: 15, color: Theme.of(context).hintColor),
              const SizedBox(width: 5),
              Text('댓글 ${id == null ? 0 : Comments.count(id)}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              const Spacer(),
              Text('눌러서 읽기',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _PostForm extends StatefulWidget {
  const _PostForm();
  @override
  State<_PostForm> createState() => _PostFormState();
}

class _PostFormState extends State<_PostForm> {
  final _title = TextEditingController();
  final _text = TextEditingController();
  bool _notice = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final text = _text.text.trim();
    if (text.isEmpty) return toast(context, '내용을 적어주세요');
    final code = AppState.i.code;
    if (code == null) return;
    setState(() => _busy = true);
    final id = await Store.i.addItem(code, {
      'type': 'diary',
      'title': _title.text.trim(),
      'text': text,
      'notice': _notice,
      'date': ymd(DateTime.now()),
    });
    if (!mounted) return;
    if (id == null) {
      setState(() => _busy = false);
      return saveFailToast(context, '올리지 못했어요 — 다시 눌러주세요');
    }
    Navigator.pop(context, true);
    toast(context, '글을 올렸어요 📔');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).viewPadding.bottom + 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('글 쓰기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              maxLength: 40,
              decoration: const InputDecoration(labelText: '제목 (없어도 돼요)', counterText: ''),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _text,
              maxLines: 6,
              /* 글도 회원 전원이 내려받는다 — 제목처럼 길이를 막아 둔다.
                 다만 공지·후기는 길 수 있으니 넉넉히 잡고, 여기서는 «남은 글자»를 보여준다
                 (제목과 달리 4000자는 눈으로 가늠이 안 된다). */
              maxLength: 4000,
              decoration: const InputDecoration(labelText: '내용'),
            ),
            if (AppState.i.isAdmin) ...[
              const SizedBox(height: 6),
              SwitchListTile(
                value: _notice,
                onChanged: (v) => setState(() => _notice = v),
                title: const Text('📌 공지로 올리기'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? '올리는 중…' : '올리기'),
            ),
          ],
        ),
      ),
    );
  }
}
