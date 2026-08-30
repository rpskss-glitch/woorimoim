import 'package:flutter/material.dart';

import '../logic.dart';
import '../moderation.dart';
import '../state.dart';
import '../store.dart';
import 'common.dart';

/* 📸 모임 사진첩 — **웹앱과 같은 사진첩.**

   왜 다시 지었나
     같은 모임을 웹과 앱이 함께 본다. 그런데 웹 사진첩에는 설명·태그·즐겨찾기·반응이
     있는데 앱에는 «격자와 지우기»뿐이었다. 그래서
       · 웹으로 정리한 회원과 앱만 쓰는 회원이 **서로 다른 사진첩**을 봤고
       · 앱 회원은 남이 남긴 반응도, 자기가 붙인 태그도 못 봤다.

   ⚠️ **칸 이름은 웹과 글자 하나까지 같다** — 다르면 서로 못 읽는다:
        caption(설명·#태그) · fav(즐겨찾기) · reacts.<내번호> · reactAt.<내번호> · date
   ⚠️ 태그는 «따로 담지 않는다». 웹처럼 **설명에서 읽어 낸다**(#모임후기).
      따로 담으면 웹에서 설명만 고쳤을 때 태그가 어긋난다.
   ⚠️ 반응은 **내 칸만** 고친다(`reacts.<내번호>`). 통째로 쓰면 둘이 동시에 누를 때
      한 사람 것이 지워진다.

   아직 없는 것(웹에는 있다): 슬라이드쇼 · 내보내기(파일 저장) · 홈/채팅 배경 지정.
   내보내기는 파일을 폰에 저장하는 꾸러미가 있어야 해서 손대지 않았다. */

/// 설명에서 #태그를 읽어 낸다 — **웹과 같은 규칙**(최대 6개, 12자까지)
List<String> photoTags(String? caption) {
  final out = <String>[];
  for (final m in RegExp(r'#[\w가-힣]{1,12}').allMatches(caption ?? '')) {
    final t = m.group(0)!.substring(1);
    if (!out.contains(t)) out.add(t);
    if (out.length >= 6) break;
  }
  return out;
}

/// 사진에 남길 수 있는 반응 — 웹과 같은 다섯 가지
const photoReactions = ['❤️', '😂', '😍', '🥺', '👍'];

/* 사진 한 장 고치기 — 됐으면 참.
   ⚠️ `Store.i.updateItem` 은 «참·거짓»을 안 돌려주고 **던진다.**
      받아 내지 않으면 잠긴 모임·연결 끊김에서 화면이 그대로 빨갛게 된다. */
Future<bool> _patchPhoto(String code, String id, Map<String, dynamic> patch) async {
  try {
    await Store.i.updateItem(code, id, 'photo', patch);
    return true;
  } catch (_) {
    return false;
  }
}

class AlbumView extends StatefulWidget {
  final VoidCallback onChanged;
  const AlbumView({super.key, required this.onChanged});

  @override
  State<AlbumView> createState() => _AlbumViewState();
}

class _AlbumViewState extends State<AlbumView> {
  bool _favOnly = false;
  String? _tag;
  String? _month;
  bool _asc = false;

  /// 정리 모드 — 고른 사진 번호. null 이면 보통 모드
  Set<String>? _pick;

  List<Map<String, dynamic>> get _all {
    final rows = [...Moderation.hide(AppState.i.by('photo'))]
      ..sort((a, b) {
        final da = (a['date'] as String?) ?? '';
        final db = (b['date'] as String?) ?? '';
        final byDate = db.compareTo(da);
        if (byDate != 0) return byDate;
        return ((b['createdAt'] as num?) ?? 0)
            .compareTo((a['createdAt'] as num?) ?? 0);
      });
    return _asc ? rows.reversed.toList() : rows;
  }

  List<Map<String, dynamic>> get _rows {
    var l = _all;
    if (_favOnly) l = l.where((p) => p['fav'] == true).toList();
    if (_tag != null) {
      l = l.where((p) => photoTags(p['caption'] as String?).contains(_tag)).toList();
    }
    if (_month != null) {
      l = l.where((p) => _dayOf(p).startsWith(_month!)).toList();
    }
    return l;
  }

  /// 이 사진이 «언제»인가 — 날짜 칸이 없으면 올린 때로 본다(웹과 같은 규칙)
  static String _dayOf(Map<String, dynamic> p) {
    final d = (p['date'] as String?) ?? '';
    if (d.length >= 10) return d;
    final at = (p['createdAt'] as num?)?.toInt();
    return at == null ? '' : ymd(DateTime.fromMillisecondsSinceEpoch(at));
  }

  void _r() {
    if (mounted) setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final rows = _rows;
    if (all.isEmpty) {
      return Center(
        child: Text('아직 사진이 없어요\n모임 사진을 올려보세요',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).hintColor, height: 1.6)),
      );
    }

    // 달별로 묶는다 — 웹과 같이 「2026년 8월」 제목을 얹는다
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final p in rows) {
      groups.putIfAbsent(_dayOf(p).padRight(7).substring(0, 7), () => []).add(p);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _head(context, all, rows),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              children: [
                Text('조건에 맞는 사진이 없어요',
                    style: TextStyle(color: Theme.of(context).hintColor)),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => setState(() {
                    _favOnly = false;
                    _tag = null;
                    _month = null;
                  }),
                  child: const Text('필터 해제'),
                ),
              ],
            ),
          ),
        for (final k in groups.keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
            child: Row(
              children: [
                /* 달 제목을 누르면 그 달만 본다 — 사진이 쌓이면 위아래로 한참 밀어야 해서,
                   웹에도 있는 길이다. 한 번 더 누르면 풀린다. */
                InkWell(
                  onTap: () => setState(() => _month = _month == k ? null : k),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(_monthLabel(k),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 6),
                Text('${groups[k]!.length}장',
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).hintColor)),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemCount: groups[k]!.length,
            itemBuilder: (c, i) => _tile(context, groups[k]![i], rows),
          ),
        ],
      ],
    );
  }

  static String _monthLabel(String k) {
    if (k.length < 7) return '날짜 없음';
    final y = int.tryParse(k.substring(0, 4));
    final m = int.tryParse(k.substring(5, 7));
    if (y == null || m == null) return '날짜 없음';
    return '$y년 $m월';
  }

  Widget _head(BuildContext context, List<Map<String, dynamic>> all,
      List<Map<String, dynamic>> rows) {
    final favN = all.where((p) => p['fav'] == true).length;
    // 자주 쓴 태그 — 많이 쓴 순으로 열두 개까지 (웹과 같다)
    final cnt = <String, int>{};
    for (final p in all) {
      for (final t in photoTags(p['caption'] as String?)) {
        cnt[t] = (cnt[t] ?? 0) + 1;
      }
    }
    final tags = cnt.keys.toList()
      ..sort((a, b) => (cnt[b]! - cnt[a]!) != 0 ? cnt[b]! - cnt[a]! : a.compareTo(b));

    final picking = _pick != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                picking
                    ? '${_pick!.length}장 골랐어요'
                    : '사진 ${all.length}장${favN > 0 ? ' · 💗 $favN' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (picking)
              TextButton(
                onPressed: () => setState(() => _pick = null),
                child: const Text('취소'),
              )
            else
              TextButton.icon(
                onPressed: () => setState(() => _pick = <String>{}),
                icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                label: const Text('정리'),
              ),
          ],
        ),
        if (picking)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton(
                onPressed: _pick!.isEmpty ? null : () => _favPicked(true),
                child: const Text('💗 즐겨찾기'),
              ),
              OutlinedButton(
                onPressed: _pick!.isEmpty ? null : _tagPicked,
                child: const Text('🏷 태그 달기'),
              ),
              OutlinedButton(
                onPressed: _pick!.isEmpty ? null : _delPicked,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('🗑 지우기'),
              ),
              OutlinedButton(
                onPressed: rows.isEmpty
                    ? null
                    : () => setState(() {
                          final ids = rows.map((p) => p['id'] as String).toSet();
                          // 다 골랐으면 한 번 더 눌러 모두 푼다
                          _pick = _pick!.length >= ids.length ? <String>{} : ids;
                        }),
                child: Text(_pick!.length >= rows.length && rows.isNotEmpty
                    ? '전체 해제'
                    : '전체 선택'),
              ),
            ],
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              FilterChip(
                label: Text('전체 ${all.length}'),
                selected: !_favOnly,
                onSelected: (_) => setState(() => _favOnly = false),
              ),
              FilterChip(
                label: Text('💗 즐겨찾기 $favN'),
                selected: _favOnly,
                onSelected: (_) => setState(() => _favOnly = true),
              ),
              ActionChip(
                avatar: Icon(_asc ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16),
                label: Text(_asc ? '오래된순' : '최신순'),
                onPressed: () => setState(() => _asc = !_asc),
              ),
              if (_month != null)
                InputChip(
                  label: Text(_monthLabel(_month!)),
                  onDeleted: () => setState(() => _month = null),
                ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_tag != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: const Text('전체'),
                        onDeleted: () => setState(() => _tag = null),
                      ),
                    ),
                  for (final t in tags.take(12))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('#$t ${cnt[t]}'),
                        selected: _tag == t,
                        onSelected: (v) => setState(() => _tag = v ? t : null),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> p,
      List<Map<String, dynamic>> rows) {
    final id = p['id'] as String;
    final note = ((p['caption'] as String?) ?? '').trim();
    final picking = _pick != null;
    final picked = picking && _pick!.contains(id);
    final tags = photoTags(p['caption'] as String?);
    /* 남이 남긴 반응 — 내 것은 뺀다(내가 뭘 눌렀는지는 사진을 열면 보인다).
       ⚠️ **폰 바꾸기 전 내 번호도 나다.** 그대로 견주면 옛 하트가 «남의 것»으로 세어져
          한 사람인데 둘로 보인다 — `Logic.isMe` 가 옛 번호까지 이어 준다. */
    final others = ((p['reacts'] as Map?) ?? {})
        .entries
        .where((e) => !Logic.isMe(e.key as String?, Store.i.myUid) && e.value is String)
        .toList();

    return GestureDetector(
      onLongPress: picking ? null : () => setState(() => _pick = {id}),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClubPhoto(
            photoId: p['photoId'] as String?,
            radius: BorderRadius.circular(10),
            decodeWidth: 400, // 격자 한 칸은 작다 — 원본 그대로 올리면 폰이 못 버틴다
            onTap: () {
              if (picking) {
                return setState(() =>
                    picked ? _pick!.remove(id) : _pick!.add(id));
              }
              _open(context, p, rows);
            },
          ),
          if (note.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(10)),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                    color: const Color(0x99000000),
                    child: Text(note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
              ),
            ),
          // 💗 즐겨찾기 · 🏷 태그 · 남의 반응 — 웹 격자와 같은 자리
          Positioned(
            top: 4,
            right: 4,
            child: IgnorePointer(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tags.isNotEmpty) const Text('🏷', style: TextStyle(fontSize: 12)),
                  if (p['fav'] == true)
                    const Text('💗', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          if (others.isNotEmpty)
            Positioned(
              left: 4,
              top: 4,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0x99000000),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${others.first.value}${others.length > 1 ? others.length : ''}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
            ),
          if (picking)
            Positioned(
              right: 4,
              bottom: 4,
              child: IgnorePointer(
                child: Icon(
                  picked ? Icons.check_circle : Icons.circle_outlined,
                  color: picked
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white70,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, Map<String, dynamic> p,
      List<Map<String, dynamic>> rows) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PhotoPage(
          rows: rows,
          start: rows.indexWhere((x) => x['id'] == p['id']),
        ),
      ),
    );
    _r();
  }

  // ── 정리 모드에서 한꺼번에 ───────────────────────────────────────
  Future<void> _favPicked(bool on) async {
    final code = AppState.i.code;
    if (code == null) return;
    final ids = _pick!.toList();
    var ok = 0;
    for (final id in ids) {
      if (await _patchPhoto(code, id, {'fav': on})) ok++;
    }
    if (!mounted) return;
    setState(() => _pick = null);
    toast(context, ok == ids.length ? '$ok장 즐겨찾기에 넣었어요' : '$ok장만 됐어요');
    _r();
  }

  Future<void> _tagPicked() async {
    final t = await askText(context,
        title: '태그 달기',
        hint: '태그 (예: 대회)',
        helper: '고른 사진 설명 끝에 #태그로 붙어요 — 웹에서도 같은 태그로 보여요',
        maxLength: 12,
        okLabel: '붙이기');
    final tag = (t ?? '').replaceAll('#', '').trim();
    if (tag.isEmpty || !mounted) return;
    final code = AppState.i.code;
    if (code == null) return;
    final ids = _pick!.toList();
    var ok = 0;
    for (final id in ids) {
      final p = AppState.i.by('photo').firstWhere((x) => x['id'] == id,
          orElse: () => <String, dynamic>{});
      if (p.isEmpty) continue;
      final cur = ((p['caption'] as String?) ?? '').trim();
      if (photoTags(cur).contains(tag)) continue; // 이미 있으면 두 번 붙이지 않는다
      /* 웹 입력칸이 40자라 그 안에서 맞춘다 — 넘치면 설명 쪽을 줄인다(웹과 같은 규칙).
         안 맞추면 웹에서 그 사진을 고칠 때 글자가 잘려 태그가 사라진다. */
      final head = cur.length > 40 - tag.length - 2
          ? cur.substring(0, (40 - tag.length - 2).clamp(0, cur.length)).trim()
          : cur;
      final next = head.isEmpty ? '#$tag' : '$head #$tag';
      if (await _patchPhoto(code, id, {'caption': next})) ok++;
    }
    if (!mounted) return;
    setState(() => _pick = null);
    toast(context, '$ok장에 #$tag 를 붙였어요');
    _r();
  }

  Future<void> _delPicked() async {
    final ids = _pick!.toList();
    final ok = await confirmSheet(
        context, '사진 ${ids.length}장을 지울까요?', '되돌릴 수 없어요',
        okLabel: '지우기', danger: true);
    if (!ok || !mounted) return;
    final code = AppState.i.code;
    if (code == null) return;
    var done = 0, denied = 0;
    for (final id in ids) {
      final p = AppState.i.by('photo').firstWhere((x) => x['id'] == id,
          orElse: () => <String, dynamic>{});
      if (p.isEmpty) continue;
      // ⚠️ 권한은 한 장씩 볼 때와 같다 — 내 사진이거나 운영진일 때만
      if (p['by'] != Store.i.myUid && !AppState.i.isAdmin) {
        denied++;
        continue;
      }
      if (await Store.i.deleteItem(code, id, 'photo')) {
        done++;
        // 기록을 지웠으면 원본도 정리한다 (안 그러면 아무도 못 보는 파일에 저장료만 나간다)
        Store.i.dropPhotos(Store.photoIdsOf(p));
      }
    }
    if (!mounted) return;
    setState(() => _pick = null);
    toast(
        context,
        denied > 0
            ? '$done장 지웠어요 — $denied장은 남이 올린 사진이라 못 지워요'
            : '$done장 지웠어요');
    _r();
  }
}

/* 🖼 사진 한 장 크게 보기 — 좌우로 넘기고, 설명·태그·반응·즐겨찾기를 여기서 다룬다.
   웹의 「사진 보기」와 같은 자리다. */
class PhotoPage extends StatefulWidget {
  final List<Map<String, dynamic>> rows;
  final int start;
  const PhotoPage({super.key, required this.rows, required this.start});

  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> {
  late final PageController _pc;
  late int _i;

  /// 지금 사진을 «확대해서 보고 있는가»
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _i = widget.start < 0 ? 0 : widget.start;
    _pc = PageController(initialPage: _i);
    AppState.i.addListener(_r);
  }

  @override
  void dispose() {
    AppState.i.removeListener(_r);
    _pc.dispose();
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  /// 화면에 그릴 «지금 값» — 목록은 열 때 찍힌 것이라 반응·설명은 새로 읽는다
  Map<String, dynamic> _live(Map<String, dynamic> p) =>
      AppState.i.by('photo').firstWhere((x) => x['id'] == p['id'], orElse: () => p);

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) return const SizedBox.shrink();
    final at = _i.clamp(0, widget.rows.length - 1);
    final p = _live(widget.rows[at]);
    final note = ((p['caption'] as String?) ?? '').trim();
    final tags = photoTags(p['caption'] as String?);
    /* 내가 남긴 반응 — **폰 바꾸기 전 번호로 남긴 것도 내 것**이다. */
    final reacts = Logic.asMap(p['reacts']);
    final myKeys = Logic.myReactKeys(reacts, Store.i.myUid);
    final mine = myKeys.isEmpty ? null : reacts[myKeys.first];
    final others = reacts.entries
        .where((e) => !Logic.isMe(e.key, Store.i.myUid) && e.value is String)
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${at + 1} / ${widget.rows.length}',
            style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            tooltip: p['fav'] == true ? '즐겨찾기 빼기' : '즐겨찾기',
            onPressed: () => _fav(p),
            icon: Text(p['fav'] == true ? '💗' : '🤍',
                style: const TextStyle(fontSize: 20)),
          ),
          IconButton(
            tooltip: '더 보기',
            onPressed: () => _more(p),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pc,
              /* ⚠️ 확대한 동안에는 **넘기기를 멈춘다.** 안 그러면 확대한 사진을 옆으로 밀어
                 보려는 순간 다음 사진으로 넘어가 버려 «확대가 쓸모없어진다». */
              physics: _zoomed
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: widget.rows.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (c, i) => Center(
                child: _ZoomPhoto(
                  key: ValueKey(widget.rows[i]['id']),
                  photoId: widget.rows[i]['photoId'] as String?,
                  onZoom: (z) {
                    if (z != _zoomed) setState(() => _zoomed = z);
                  },
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFF111315),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppState.i.emojiOf(p['by'] as String?)} '
                    '${AppState.i.nameOf(p['by'] as String?)} · '
                    '${fmtDateFull(_AlbumViewState._dayOf(p))}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(note,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, height: 1.5)),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final t in tags)
                          Text('#$t',
                              style: const TextStyle(
                                  color: Color(0xFF9FD0FF), fontSize: 12)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  /* ⚠️ **한 줄(Row)로 두면 안 된다.** 반응 다섯에 남이 남긴 것까지
                     한 줄에 몰아넣으면 360px 폰에서 오른쪽으로 **90px 넘쳤다**(실측).
                     넘친 자리는 잘려서 «아예 못 누른다». 자리가 모자라면 다음 줄로 내린다. */
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final e in photoReactions)
                        InkWell(
                          onTap: () => _react(p, e),
                          borderRadius: BorderRadius.circular(20),
                          /* ⚠️ **44×44 아래로 내리지 말 것.** 반응 다섯이 나란히 붙어 있어
                             작으면 옆의 다른 반응을 누른다 — 되돌리려면 또 눌러야 한다.
                             (실측 36×40 이었다. 애플 44 · 구글 48 이 기준이다) */
                          child: Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: mine == e
                                  ? const Color(0x33FFFFFF)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(23),
                            ),
                            child: Text(e, style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                      // 남이 남긴 반응 — 누구인지 알 수 있게 아바타와 함께
                      for (final o in others.take(4))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            '${AppState.i.emojiOf(o.key)}${o.value}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fav(Map<String, dynamic> p) async {
    final code = AppState.i.code;
    if (code == null) return;
    final on = p['fav'] != true;
    final ok = await _patchPhoto(code, p['id'] as String, {'fav': on});
    if (!mounted) return;
    if (!ok) return saveFailToast(context, '바꾸지 못했어요 — 잠시 후 다시 해주세요');
    setState(() {});
  }

  /* ❤️ 반응 — **내 칸만** 고친다.
     통째로 쓰면 둘이 동시에 누를 때 한 사람 것이 지워진다(웹도 이렇게 한다).
     같은 것을 다시 누르면 «지우기»다. */
  Future<void> _react(Map<String, dynamic> p, String e) async {
    final code = AppState.i.code;
    final me = Store.i.myUid;
    if (code == null || me.isEmpty) return;
    final reacts = Logic.asMap(p['reacts']);
    /* 폰을 바꾸기 «전» 번호로 남긴 것도 내 것이다 — **뗄 때는 전부 뗀다.**
       안 그러면 옛 하트가 남아 한 사람인데 둘로 보이고, 그것을 영영 못 뗀다. */
    final myKeys = Logic.myReactKeys(reacts, me);
    final off = myKeys.isNotEmpty && reacts[myKeys.first] == e;
    final patch = <String, dynamic>{};
    for (final k in myKeys) {
      patch['reacts.$k'] = null;
      patch['reactAt.$k'] = null;
    }
    if (!off) {
      patch['reacts.$me'] = e;
      patch['reactAt.$me'] = DateTime.now().millisecondsSinceEpoch;
    }
    final ok = await _patchPhoto(code, p['id'] as String, patch);
    if (!mounted) return;
    if (!ok) return saveFailToast(context, '반응을 남기지 못했어요');
    setState(() {});
  }

  Future<void> _more(Map<String, dynamic> p) async {
    final pick = await chooseSheet(context, '사진', '', [
      ['edit', '✏️ 설명·날짜 고치기'],
      ['delete', '🗑 지우기'],
    ]);
    if (pick == null || !mounted) return;
    if (pick == 'edit') return _edit(p);
    if (pick == 'delete') return _delete(p);
  }

  Future<void> _edit(Map<String, dynamic> p) async {
    final code = AppState.i.code;
    if (code == null) return;
    /* ⚠️ 설명은 **40자**까지 — 웹 입력칸과 같다.
       더 길게 받으면 웹에서 그 사진을 고칠 때 뒤가 잘려 태그가 사라진다. */
    final cap = await askText(context,
        title: '사진 설명',
        initial: ((p['caption'] as String?) ?? ''),
        hint: '설명 · #태그도 좋아요',
        helper: '#태그를 적으면 사진첩에서 그 태그로 모아 볼 수 있어요 (웹에서도 같아요)',
        maxLength: 40,
        okLabel: '저장');
    if (cap == null || !mounted) return;
    final ok = await _patchPhoto(code, p['id'] as String, {'caption': cap.trim()});
    if (!mounted) return;
    if (!ok) return saveFailToast(context, '저장하지 못했어요');
    toast(context, '저장했어요');
    setState(() {});
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    // ⚠️ 권한 — 격자에서와 같다. 내 사진이거나 운영진일 때만
    final mine = p['by'] == Store.i.myUid;
    if (!mine && !AppState.i.isAdmin) {
      return toast(context, '내가 올린 사진만 지울 수 있어요 (운영진은 모두 지울 수 있어요)');
    }
    final ok = await confirmSheet(context, '이 사진을 지울까요?', '되돌릴 수 없어요',
        okLabel: '지우기', danger: true);
    if (!ok || !mounted) return;
    final code = AppState.i.code;
    if (code == null) return;
    final done = await Store.i.deleteItem(code, p['id'] as String, 'photo');
    if (!mounted) return;
    if (!done) return toast(context, '지우지 못했어요 — 다시 시도해주세요');
    Store.i.dropPhotos(Store.photoIdsOf(p));
    toast(context, '사진을 지웠어요');
    Navigator.pop(context);
  }
}

/* 🔍 확대해서 볼 수 있는 사진 한 장.

   🔴 `InteractiveViewer` 를 그냥 두면 **좌우로 미는 손짓을 통째로 먹는다** —
      그래서 사진첩에서 다음 사진으로 «넘길 수가 없었다»(2026-08-30 실측).
      확대하지 않은 동안에는 밀기를 끄고, 확대했을 때만 켠다. */
class _ZoomPhoto extends StatefulWidget {
  final String? photoId;
  final ValueChanged<bool> onZoom;
  const _ZoomPhoto({super.key, required this.photoId, required this.onZoom});

  @override
  State<_ZoomPhoto> createState() => _ZoomPhotoState();
}

class _ZoomPhotoState extends State<_ZoomPhoto> {
  final _tc = TransformationController();
  bool _on = false;

  @override
  void initState() {
    super.initState();
    _tc.addListener(_check);
  }

  @override
  void dispose() {
    _tc.removeListener(_check);
    _tc.dispose();
    super.dispose();
  }

  void _check() {
    // 1보다 커졌으면 «확대한 것» — 아주 작은 흔들림은 무시한다
    final z = _tc.value.getMaxScaleOnAxis() > 1.02;
    if (z == _on) return;
    setState(() => _on = z);
    widget.onZoom(z);
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
        transformationController: _tc,
        panEnabled: _on, // 확대했을 때만 민다 — 아니면 넘기기가 막힌다
        minScale: 1,
        maxScale: 5,
        child: ClubPhoto(photoId: widget.photoId, fit: BoxFit.contain),
      );
}
