import 'package:flutter/material.dart';

import '../config.dart';
import '../logic.dart';
import '../moderation.dart';
import '../push.dart';
import '../state.dart';
import '../store.dart';
import 'admin.dart';
import 'album.dart';
import 'common.dart';
import 'members.dart';
import 'owner_guide.dart';
import 'post_screen.dart';

/* 🏠 홈 — **웹앱 첫 화면과 같은 얼굴.**

   2026-08-31 사장님: 「예전 첫 화면(웹)이 이렇게 예쁜 게 많은데」 — 앱 홈은
   카드 네 장뿐이라 웹을 쓰던 회원이 앱을 열면 «허전한 딴 앱»으로 보였다.
   웹 홈의 카드들을 그대로 가져온다(자료가 같은 방이라 값도 똑같이 나온다):

     회원 얼굴 무리 + 상징 + 창단 N년째 → 빠른 단추 4개 → 가입 승인 대기(운영진)
     → 클럽 D-day → 다음 모임(참석·미정·불참) → 이번 달 출석(메달 순위)
     → 이번 달 회비(몇 명 냈나) → 회비 장부(잔액·지출) → 사진첩 띠 → 최근 게시판

   ⚠️ 웹에만 있고 여기 없는 것: 「오늘 챙길 것」(준비물), 「모아보기」, 「홈 카드 고르기」.
      자료 모양을 아직 안 맞춰서다 — 넣을 때는 웹과 같은 칸 이름으로. */
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
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

  /* 화면을 다시 그린다. ⚠️ **아직 그 화면이 있는지 보고** 그린다 —
     그 사이 모임에서 빠지거나 방이 없어져 화면이 사라졌을 수 있다(183회차). */
  void _r() {
    if (mounted) setState(() {});
  }

  /// 아래쪽 탭으로 옮긴다 (0홈 1채팅 2일정 3게시판 4회비 — 웹과 같은 순서) — 꺼풀(shell)이 듣고 있다
  void _go(int tab) => AppState.i.openTab.value = tab;

  /* 🤫 숨은 입구 — 모임 «상징»을 다섯 번 두드리면 총괄 콘솔.
     설정 맨 아래 버전 글씨에도 같은 길이 있는데, 모임 안에 들어와 있으면
     그 글씨까지 내려가는 것이 번거로워 첫 화면에도 둔다.
     ⚠️ 화면에는 아무 흔적이 없다 — 모르는 사람은 그냥 그림을 누른 것이다. */
  int _emblemTaps = 0;

  Future<void> _tapEmblem() async {
    _emblemTaps++;
    if (_emblemTaps < 5) return;
    _emblemTaps = 0;
    await openAdminByTaps(context);
  }

  @override
  Widget build(BuildContext context) {
    final st = AppState.i;
    final now = DateTime.now();
    final month = ymd(now).substring(0, 7);
    final next = Logic.nextEvent();
    final feeAmount = ((st.couple?['fee'] as Map?)?['amount'] as num?)?.toInt() ?? 0;
    final pending = ((st.couple?['pending'] as Map?) ?? {})
        .values
        .whereType<Map>()
        .toList()
      ..sort((a, b) =>
          ((a['requestedAt'] as num?) ?? 0).compareTo((b['requestedAt'] as num?) ?? 0));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        /* 📖 방장 안내서 — **방장에게만, 닫기 전까지.** 맨 위에 둔다:
           새 방장이 제일 먼저 봐야 할 것이라 아래에 두면 못 찾는다. */
        if (OwnerGuideCard.shouldShow()) ...[
          OwnerGuideCard(onClosed: _r, onGo: _go),
          const SizedBox(height: 12),
        ],
        _hero(context, st, now),
        const SizedBox(height: 12),
        _quick(context),
        const SizedBox(height: 12),

        // 🤝 가입 승인 대기 — 운영진에게만. 놓치면 신청자가 며칠씩 기다린다
        if (st.isAdmin && pending.isNotEmpty) ...[
          SectionCard(
            title: '⏳ 가입 승인 대기',
            trailing: TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) => const MembersScreen())),
              child: const Text('승인하러 가기 ›'),
            ),
            child: Column(
              children: [
                for (final p in pending.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text((p['emoji'] as String?) ?? defaultAvatar,
                            style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text((p['name'] as String?) ?? '신청자',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Text(_reqDay(p['requestedAt']),
                            style: TextStyle(
                                fontSize: 12, color: Theme.of(context).hintColor)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        ..._ddays(context, now),

        if (next != null) ...[
          SectionCard(
            title: '📍 다음 모임',
            trailing: TextButton(
                onPressed: () => _go(2), child: const Text('일정 ›')),
            child: _NextEventCard(event: next.event, date: next.date, onChanged: _r),
          ),
          const SizedBox(height: 12),
        ],

        ..._attendCard(context, st, month),
        if (feeAmount > 0) ..._feeCard(context, st, month, feeAmount),
        ..._ledgerCard(context, month),
        ..._photoStrip(context),
        ..._boardCard(context, st),

        // 알림 권유 — 아직 안 켰을 때만 («토큰이 있는지»를 본다)
        if (Push.i.mode != 'off' && !Push.i.ready)
          SectionCard(
            title: '🔔 알림을 켤까요?',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('새 대화·공지가 올라오면 알려드려요. 설정에서 「공지만 받기」로 줄일 수도 있어요.',
                    style: TextStyle(height: 1.5, color: Theme.of(context).hintColor)),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: () async {
                    final ok = await Push.i.setup();
                    if (!context.mounted) return;
                    toast(context, Push.i.offReason(ok));
                  },
                  child: const Text('알림 켜기'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── 🏸 얼굴 무리 + 상징 + 창단 ──────────────────────────────────
  Widget _hero(BuildContext context, AppState st, DateTime now) {
    final members = st.memberList;
    final startRaw = st.couple?['startDate'] as String?;
    final start = startRaw == null ? null : DateTime.tryParse(startRaw);
    final years = start == null ? 0 : now.difference(start).inDays ~/ 365;
    final since = start == null
        ? ''
        : '창단 ${fmtDateFull(startRaw!)}${years >= 1 ? ' · $years년째 함께' : ''} · ';
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        child: Column(
          children: [
            /* 회원 «얼굴 무리» — 웹 홈의 얼굴이자 이 화면이 예뻐 보이는 이유다.
               많아도 여덟까지만 — 다 그리면 큰 모임에서 화면 절반이 얼굴이 된다. */
            if (members.isNotEmpty) ...[
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in members.take(8))
                    Avatar(m['uid'] as String?, size: 52),
                  if (members.length > 8)
                    CircleAvatar(
                      radius: 26,
                      child: Text('+${members.length - 8}',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            GestureDetector(
              onTap: _tapEmblem,
              child: const Emblem(basePx: emblemBasePx, capScale: 2),
            ),
            const SizedBox(height: 10),
            Text(
              (st.couple?['title'] as String?) ?? Cfg.appName,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text('$since회원 ${members.length}명',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).hintColor)),
            const SizedBox(height: 12),
            ActionChip(
              avatar: const Text('🏅'),
              label: const Text('배지 · 출석순위'),
              onPressed: () => _openBadges(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── ⚡ 빠른 단추 네 개 — 웹 홈의 그 줄 ──────────────────────────
  Widget _quick(BuildContext context) {
    Widget tile(String emoji, String label, VoidCallback onTap) => Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 6),
                    FittedBox(
                      // 큰 글자에서도 한 줄 — 네 칸이라 폭이 좁다
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return Row(
      children: [
        tile('📅', '일정', () => _go(2)),
        const SizedBox(width: 8),
        tile('✏️', '글 쓰기', () => _go(3)),
        const SizedBox(width: 8),
        tile('💰', '회비 장부', () => _go(4)),
        const SizedBox(width: 8),
        tile('📸', '사진첩', () => _openAlbum(context)),
      ],
    );
  }

  // ── ⏳ 클럽 D-day — 웹에서 만든 것을 그대로 보여 준다 ───────────
  List<Widget> _ddays(BuildContext context, DateTime now) {
    final today = ymd(now);
    final rows = AppState.i
        .by('dday')
        .where((d) => ((d['date'] as String?) ?? '').compareTo(today) >= 0)
        .toList()
      ..sort((a, b) =>
          ((a['date'] as String?) ?? '').compareTo((b['date'] as String?) ?? ''));
    if (rows.isEmpty) return const [];
    return [
      SectionCard(
        title: '⏳ 클럽 D-day',
        child: SizedBox(
          height: 108,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final d in rows.take(5))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    width: 130,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text((d['emoji'] as String?) ?? '🏆',
                            style: const TextStyle(fontSize: 20)),
                        Text(
                          _dLabel(today, d['date'] as String? ?? today),
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        Text((d['title'] as String?) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  static String _dLabel(String today, String date) {
    final n = DateTime.parse(date).difference(DateTime.parse(today)).inDays;
    return n == 0 ? 'D-day' : 'D-$n';
  }

  // ── ✅ 이번 달 출석 — 메달 순위 (웹과 같은 얼굴) ─────────────────
  List<Widget> _attendCard(BuildContext context, AppState st, String month) {
    final rank = Logic.monthRank();
    if (rank.isEmpty) return const [];
    final mine = rank
        .where((e) => Logic.isMe(e.key, Store.i.myUid))
        .fold(0, (a, e) => a + e.value);
    // 이번 달에 «있었던» 모임 수 — 지난 회차 중 이번 달 것
    final meets =
        Logic.eventRows(past: true).where((r) => r.date.startsWith(month)).length;
    const medal = ['🥇', '🥈', '🥉'];
    return [
      SectionCard(
        title: '✅ 이번 달 출석',
        trailing: TextButton(
            onPressed: () => _openBadges(context), child: const Text('순위 전체 ›')),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${meets > 0 ? '이번 달 모임 $meets번 · ' : ''}나는 $mine회 출석했어요',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < rank.length && i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Text(medal[i], style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Avatar(rank[i].key, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(st.nameOf(rank[i].key),
                            overflow: TextOverflow.ellipsis)),
                    Text('${rank[i].value}회',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary)),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  // ── 🏦 이번 달 회비 — 몇 명 냈고 누가 남았나 (웹의 초록 카드) ────
  List<Widget> _feeCard(
      BuildContext context, AppState st, String month, int feeAmount) {
    final members = st.memberList;
    if (members.isEmpty) return const [];
    final paid = members
        .where((m) => Logic.paidIn(m['uid'] as String? ?? '', month))
        .length;
    final unpaidNames = [
      for (final m in members)
        if (!Logic.paidIn(m['uid'] as String? ?? '', month))
          (m['name'] as String?) ?? '회원'
    ];
    final iPaid = Logic.paidIn(Store.i.myUid, month);
    final myLate = Logic.unpaidMonths(Store.i.myUid);
    return [
      SectionCard(
        title: '🏦 이번 달 회비',
        trailing: Text('1인 ${fmtWon(feeAmount)}',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: members.isEmpty ? 0 : paid / members.length,
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('$paid/${members.length}명',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              iPaid
                  ? '나는 냈어요 ✓${unpaidNames.isEmpty ? ' — 모두 냈어요 🎉' : ' — 아직 ${unpaidNames.length}명 남았어요'}'
                  : myLate.isEmpty
                      ? '이번 달 회비를 아직 안 냈어요'
                      /* «이상»을 빼먹으면 안 된다 — 밀린 달은 12까지만 세므로,
                         3년치 밀린 회원도 12달로 보여 그게 전부인 줄 안다 */
                      : '아직 안 낸 달: ${myLate.join(', ')}'
                          '${Logic.unpaidTruncated(Store.i.myUid) ? ' 이상' : ''}',
              style: const TextStyle(height: 1.5),
            ),
            if (st.isTreasurer && unpaidNames.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text('미납: ${unpaidNames.take(4).join(', ')}'
                        '${unpaidNames.length > 4 ? ' 외 ${unpaidNames.length - 4}명' : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).hintColor)),
                  ),
                  TextButton(onPressed: () => _go(4), child: const Text('회비 받기')),
                ],
              ),
            ] else if (!st.isTreasurer && !iPaid) ...[
              const SizedBox(height: 4),
              Text('입금은 총무님께 하시면 총무님이 기록해요',
                  style:
                      TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  // ── 💰 회비 장부 — 잔액·이번 달 지출 (웹의 두 상자) ──────────────
  List<Widget> _ledgerCard(BuildContext context, String month) {
    final ledgers = AppState.i.by('ledger');
    if (ledgers.isEmpty) return const [];
    final bal = Logic.balance();
    var monthOut = 0;
    for (final l in ledgers) {
      if (l['kind'] == 'out' && ((l['date'] as String?) ?? '').startsWith(month)) {
        monthOut += ((l['amount'] as num?) ?? 0).toInt();
      }
    }
    Widget box(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).hintColor)),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        );
    return [
      SectionCard(
        title: '💰 회비 장부',
        trailing: TextButton(onPressed: () => _go(4), child: const Text('자세히 ›')),
        child: Row(
          children: [
            box('현재 잔액', fmtWon(bal)),
            const SizedBox(width: 10),
            box('이번 달 지출', fmtWon(monthOut)),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  // ── 📸 사진첩 띠 — 최근 넉 장 ───────────────────────────────────
  List<Widget> _photoStrip(BuildContext context) {
    final rows = [...Moderation.hide(AppState.i.by('photo'))]
      ..sort((a, b) =>
          ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
    if (rows.isEmpty) return const [];
    return [
      SectionCard(
        title: '📸 모임 사진첩',
        trailing: TextButton(
            onPressed: () => _openAlbum(context), child: const Text('전체 ›')),
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              for (var i = 0; i < rows.length && i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: ClubPhoto(
                    photoId: rows[i]['photoId'] as String?,
                    radius: BorderRadius.circular(10),
                    decodeWidth: 200,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => PhotoPage(rows: rows, start: i)),
                    ).then((_) => _r()),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  // ── 📔 최근 게시판 ──────────────────────────────────────────────
  List<Widget> _boardCard(BuildContext context, AppState st) {
    final diaries = [...Moderation.hide(st.by('diary'))]
      ..sort((a, b) =>
          ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
    if (diaries.isEmpty) return const [];
    final d = diaries.first;
    final photos = st.by('photo').length;
    /* 🔴 **못 보는 방의 대화는 안 센다.** 평회원 홈에 「대화 9개」라고 떠 있는데
       들어가면 6개뿐이면, 회원은 뭔가 사라진 줄 안다.
       (room 칸이 없는 옛 대화는 모두의 방이다) */
    final msgs = st
        .by('msg')
        .where((m) => ((m['room'] as String?) ?? '').isEmpty || st.isAdmin)
        .length;
    return [
      SectionCard(
        title: '📔 최근 게시판',
        trailing: TextButton(onPressed: () => _go(3), child: const Text('전체 ›')),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => PostScreen(postId: d['id'] as String)),
          ).then((_) => _r()),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${fmtDateFull(d['date'] as String?)} · '
                '${st.emojiOf(d['by'] as String?)} ${st.nameOf(d['by'] as String?)}',
                style:
                    TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 4),
              Text((d['title'] as String?) ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              if (((d['text'] as String?) ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(d['text'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).hintColor)),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  Chip(
                      label: Text('📔 글 ${diaries.length}개'),
                      visualDensity: VisualDensity.compact),
                  if (photos > 0)
                    Chip(
                        label: Text('📸 사진첩 $photos장'),
                        visualDensity: VisualDensity.compact),
                  if (msgs > 0)
                    Chip(
                        label: Text('💬 대화 $msgs개'),
                        visualDensity: VisualDensity.compact),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  // ── 여닫이들 ────────────────────────────────────────────────────
  void _openAlbum(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('모임 사진첩')),
          body: AlbumView(onChanged: _r),
        ),
      ),
    ).then((_) => _r());
  }

  /// 🏅 내 배지 + 전체 출석 순위 — 예전 홈 카드 두 장을 여기로 모았다
  void _openBadges(BuildContext context) {
    final st = AppState.i;
    final myAttend = Logic.attendStats()[Store.i.myUid] ?? 0;
    final badges = Logic.badgesOf(myAttend);
    final nextBadge = Logic.nextBadge(myAttend);
    final rank = Logic.monthRank();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (c, ctl) => ListView(
          controller: ctl,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            const Text('🏅 내 배지',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final b in badges)
                  Chip(
                      label: Text('${b.$2} ${b.$3}'),
                      visualDensity: VisualDensity.compact),
                if (badges.isEmpty)
                  Text('아직 배지가 없어요 — 첫 출석이 첫 배지예요',
                      style: TextStyle(color: Theme.of(c).hintColor)),
              ],
            ),
            if (nextBadge != null) ...[
              const SizedBox(height: 8),
              Text(
                  '다음 배지 ${nextBadge.$2} ${nextBadge.$3}까지 ${nextBadge.$1 - myAttend}번 남았어요',
                  style: TextStyle(fontSize: 12, color: Theme.of(c).hintColor)),
            ],
            const SizedBox(height: 18),
            const Text('✅ 이번 달 출석 순위',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (rank.isEmpty)
              Text('이번 달 출석이 아직 없어요',
                  style: TextStyle(color: Theme.of(c).hintColor)),
            for (final e in rank)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Avatar(e.key, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(st.nameOf(e.key),
                            overflow: TextOverflow.ellipsis)),
                    Text('${e.value}회',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _reqDay(Object? at) {
    if (at is! num) return '대기';
    return '${fmtDateFull(ymd(DateTime.fromMillisecondsSinceEpoch(at.toInt())))} 신청';
  }
}

/// 다음 모임 한 장 — 날짜 상자 + 참석 투표 + 참석자 얼굴 (웹과 같은 얼굴)
class _NextEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String date;
  final VoidCallback onChanged;
  const _NextEventCard({required this.event, required this.date, required this.onChanged});

  Future<void> _vote(BuildContext context, String v) async {
    final code = AppState.i.code;
    if (code == null) return;
    final key = Logic.rkey(date, Store.i.myUid);
    /* 투표는 반드시 트랜잭션으로 — 통째로 덮어쓰면 그 사이 남이 한 투표가 사라진다. */
    var ok = false;
    try {
      ok = await Store.i.mutateItem(code, event['id'] as String, 'event', (cur) {
        final rsvp = Logic.asMap(cur['rsvp']);
        // 폰을 바꾸기 «전» 번호로 찍은 표까지 함께 치운다
        final mine = Logic.markKeys(rsvp, date, Store.i.myUid);
        final now = mine.isEmpty ? null : rsvp[mine.first];
        if (now == v) {
          return {'rsvp': {for (final k in mine) k: Store.del}};
        }
        return {
          'rsvp': {for (final k in mine) k: Store.del, key: v}
        };
      });
    } catch (_) {
      ok = false;
    }
    if (!context.mounted) return;
    if (!ok) return saveFailToast(context, '투표를 저장하지 못했어요 — 다시 눌러주세요');
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final st = AppState.i;
    final my = Logic.myRsvp(event, date);
    final yes = Logic.rsvpCount(event, date, 'yes');
    final no = Logic.rsvpCount(event, date, 'no');
    /* 「미정」은 웹에서 찍는 값이다 — 앱이 몰라 보이지 않으면
       웹 회원 표가 «사라진 것»처럼 보인다. 여기서도 찍고 셀 수 있게 한다. */
    final maybe = Logic.rsvpCount(event, date, 'maybe');
    final time = event['time'] as String?;
    final place = event['place'] as String?;
    final today = ymd(DateTime.now());
    final dDays =
        DateTime.parse(date).difference(DateTime.parse(today)).inDays;
    // 참석한다고 한 사람 얼굴 — 「누가 오나」가 모임의 첫 궁금증이다
    final yesUids = Logic.asMap(event['rsvp'])
        .entries
        .where((e) => e.value == 'yes' && e.key.startsWith('${date}_'))
        .map((e) => e.key.substring(date.length + 1))
        .toList();

    Widget voteBtn(String v, String label, int n) => Expanded(
          child: BusyButton(
            onTap: () => _vote(context, v),
            style: FilledButton.styleFrom(
              backgroundColor: my == v
                  ? (v == 'yes' ? cs.primary : Colors.grey.shade700)
                  : null,
              foregroundColor: my == v
                  ? (v == 'yes' ? cs.onPrimary : Colors.white)
                  : null,
              minimumSize: const Size.fromHeight(46),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: FittedBox(child: Text('$label $n')),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 웹의 「오늘!」 날짜 상자
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    dDays <= 0 ? '오늘!' : 'D-$dDays',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: cs.primary),
                  ),
                  Text(fmtDateFull(date),
                      style: TextStyle(
                          fontSize: 11, color: Theme.of(context).hintColor)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (event['title'] as String?) ?? '모임',
                    style:
                        const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${time == null || time.isEmpty ? '' : '$time · '}'
                    '${place == null || place.isEmpty ? '' : place}',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            voteBtn('yes', '🙆 참석', yes),
            const SizedBox(width: 6),
            voteBtn('maybe', '🤔 미정', maybe),
            const SizedBox(width: 6),
            voteBtn('no', '🙅 불참', no),
          ],
        ),
        if (yesUids.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text('참석 ${yesUids.length}명: ',
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).hintColor)),
              Expanded(
                child: Text(
                  yesUids.map((u) => st.emojiOf(u)).join(' '),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
