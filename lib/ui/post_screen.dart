import 'package:flutter/material.dart';

import '../comments.dart';
import '../logic.dart';
import '../moderation.dart';
import '../state.dart';
import '../store.dart';
import 'common.dart';

/* 📄 게시판 글 하나 — 글을 눌러 들어와 «전문»을 읽고 댓글을 단다.

   ⚠️ 목록에서는 글이 길면 잘라 보여 주는데, 여기서는 **자르지 않는다.**
      들어와서도 잘려 있으면 회원은 뒷내용을 읽을 길이 아예 없다.

   ⚠️ 이 화면은 «지금 자료»를 그대로 다시 읽는다(AppState 를 듣는다).
      글이 지워지면(다른 사람이 지웠거나 내가 지웠거나) 빈 화면에 갇히지 않게
      스스로 나간다. */
class PostScreen extends StatefulWidget {
  final String postId;
  const PostScreen({super.key, required this.postId});
  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AppState.i.addListener(_r);
  }

  @override
  void dispose() {
    AppState.i.removeListener(_r);
    _c.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  Map<String, dynamic>? get _post {
    for (final x in AppState.i.by('diary')) {
      if (x['id'] == widget.postId) return x;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    // 글이 사라졌다 — 안내하고 되돌아간다 (빈 화면에 갇히면 나갈 길을 못 찾는다)
    if (post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('게시글')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Text('이 글이 지워졌어요',
                style: TextStyle(color: Theme.of(context).hintColor)),
          ),
        ),
      );
    }

    final comments = Comments.of(widget.postId)
        .where((c) => !Moderation.isBlocked(c['by'] as String?))
        .toList();
    final st = AppState.i;

    return Scaffold(
      appBar: AppBar(title: const Text('게시글')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
              children: [
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Avatar(post['by'] as String?, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(st.nameOf(post['by'] as String?),
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(post['date'] as String? ?? '',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).hintColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (post['notice'] == true) ...[
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('📌 공지',
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if ((post['title'] as String?)?.isNotEmpty == true) ...[
                        Text(post['title'] as String,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                      ],
                      // ⚠️ 여기서는 자르지 않는다 — 들어와서도 잘리면 읽을 길이 없다
                      SelectableText((post['text'] as String?) ?? '',
                          style: const TextStyle(height: 1.7)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                  child: Text('💬 댓글 ${comments.length}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                if (comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Center(
                      child: Text('아직 댓글이 없어요 — 처음으로 남겨보세요',
                          style: TextStyle(color: Theme.of(context).hintColor)),
                    ),
                  )
                else
                  for (final c in comments) _CommentRow(comment: c, onChanged: _r),
              ],
            ),
          ),
          _writeBar(context),
        ],
      ),
    );
  }

  Widget _writeBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              /* ⚠️ 한글 입력은 «그대로 흘려보내야» 한다 —
                 여기에 제 나름의 상태·되돌림을 두면 글자가 겹쳐 찍힌다(KoInput 함정). */
              child: TextField(
                controller: _c,
                maxLines: 4,
                minLines: 1,
                maxLength: Comments.maxLen,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: '댓글 남기기',
                  border: OutlineInputBorder(),
                  isDense: true,
                  counterText: '', // 글자 수 표시는 자리를 먹는다 — 한계는 보낼 때 알린다
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _busy ? null : _send,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _c.text;
    setState(() => _busy = true);
    String? why;
    try {
      why = await Comments.add(widget.postId, text);
    } catch (e) {
      why = '댓글을 남기지 못했어요 — 다시 해주세요';
    } finally {
      /* ⚠️ 「도는 중」은 **터졌을 때도** 풀어야 한다.
         안 풀면 보내기 단추가 그 자리에서 영영 잠겨, 앱을 껐다 켜야 다시 쓸 수 있다. */
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (why != null) return toast(context, why);
    _c.clear();
    // 방금 쓴 댓글이 보이게 아래로 — 안 그러면 「눌렀는데 아무 일도 없다」로 보인다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }
}

class _CommentRow extends StatelessWidget {
  final Map<String, dynamic> comment;
  final VoidCallback onChanged;
  const _CommentRow({required this.comment, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final by = comment['by'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(by, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(AppState.i.nameOf(by),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text(comment['date'] as String? ?? '',
                        style: TextStyle(
                            fontSize: 11, color: Theme.of(context).hintColor)),
                  ],
                ),
                const SizedBox(height: 2),
                Text((comment['text'] as String?) ?? '',
                    style: const TextStyle(height: 1.5)),
              ],
            ),
          ),
          // 신고·차단은 «남의» 댓글에만 뜻이 있다
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 18),
            onSelected: (v) => _menu(context, v),
            itemBuilder: (_) => [
              if (Comments.canDelete(comment))
                const PopupMenuItem(value: 'del', child: Text('지우기')),
              if (by != Store.i.myUid) ...[
                const PopupMenuItem(value: 'report', child: Text('신고하기')),
                const PopupMenuItem(value: 'block', child: Text('이 사람 차단')),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _menu(BuildContext context, String v) async {
    if (v == 'del') {
      final ok = await confirmSheet(context, '이 댓글을 지울까요?', '되돌릴 수 없어요',
          okLabel: '지우기', danger: true);
      if (!ok || !context.mounted) return;
      final done = await Comments.remove(comment['id'] as String);
      if (!context.mounted) return;
      toast(context, done ? '댓글을 지웠어요' : '지우지 못했어요 — 다시 해주세요');
      onChanged();
      return;
    }
    if (v == 'report') {
      await reportSheet(context, comment);
      return;
    }
    if (v == 'block') {
      await blockSheet(context, comment['by'] as String?, onChanged);
    }
  }
}
