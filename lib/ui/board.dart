import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../logic.dart';
import '../moderation.dart';
import '../comments.dart';
import '../state.dart';
import '../store.dart';
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
  }

  @override
  void dispose() {
    AppState.i.removeListener(_r);
    super.dispose();
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
    // 차단한 회원의 글은 내 화면에서 가린다 (애플 1.2 — 차단이 한 화면에만 있으면 안 된다)
    final rows = Moderation.hide(AppState.i.by('diary'))..sort(Logic.byNotice);
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

  Widget _photos(BuildContext context) {
    final rows = [...Moderation.hide(AppState.i.by('photo'))]
      ..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
    if (rows.isEmpty) {
      return Center(
        child: Text('아직 사진이 없어요\n모임 사진을 올려보세요',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).hintColor, height: 1.6)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: rows.length,
      itemBuilder: (c, i) => _PhotoTile(item: rows[i], onChanged: _r),
    );
  }

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
    final id = item['id'] as String?;
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
              if (mine || st.isAdmin)
                PopupMenuButton<String>(
                  onSelected: (v) async {
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
                  itemBuilder: (_) => const [PopupMenuItem(value: 'del', child: Text('지우기'))],
                ),
            ],
          ),
          const SizedBox(height: 10),
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
            Text(item['title'] as String,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
          ],
          /* 목록에서는 «앞부분만» 보인다 — 길면 글 하나가 화면을 통째로 먹어
             다음 글이 있는지조차 알 수 없다. 전문은 눌러 들어가서 읽는다. */
          Text((item['text'] as String?) ?? '',
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

class _PhotoTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onChanged;
  const _PhotoTile({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 길게 누르면 지우기 (내 사진이거나 운영진일 때만)
      onLongPress: () => _delete(context),
      child: ClubPhoto(
        photoId: item['photoId'] as String?,
        radius: BorderRadius.circular(10),
        decodeWidth: 400, // 격자 한 칸은 작다 — 원본 그대로 올리면 폰이 못 버틴다
        onTap: () async {
          final src = await Store.i.getPhoto(item['photoId'] as String?);
          if (!context.mounted) return;
          // 조용히 아무 일도 안 일어나면 회원은 화면이 멈춘 줄 알고 계속 누른다
          if (src == null) return toast(context, '사진을 불러오지 못했어요 — 잠시 후 다시 눌러주세요');
          showPhotoViewer(context, src);
        },
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    // ⚠️ 권한 — 위와 같은 이유로 폰 바꾸기 전 번호까지 넓히지 않는다
    final mine = item['by'] == Store.i.myUid;
    if (!mine && !AppState.i.isAdmin) {
      // 길게 눌렀는데 아무 반응이 없으면 눌린 건지 아닌지 알 수 없다
      return toast(context, '내가 올린 사진만 지울 수 있어요 (운영진은 모두 지울 수 있어요)');
    }
    final ok = await confirmSheet(context, '이 사진을 지울까요?', '되돌릴 수 없어요',
        okLabel: '지우기', danger: true);
    if (!ok || !context.mounted) return;
    final code = AppState.i.code;
    if (code == null) return;
    final done = await Store.i.deleteItem(code, item['id'] as String, 'photo');
    if (!context.mounted) return;
    if (!done) return toast(context, '지우지 못했어요 — 다시 시도해주세요');
    // 기록을 지웠으면 원본도 정리한다 (대기줄을 거치므로 실패해도 다음에 다시 시도한다)
    Store.i.dropPhotos(Store.photoIdsOf(item));
    toast(context, '사진을 지웠어요');
    onChanged();
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
      return toast(context, '올리지 못했어요 — 다시 눌러주세요');
    }
    Navigator.pop(context, true);
    toast(context, '글을 올렸어요 📔');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(context).viewInsets.bottom + 18),
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
