import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../fee_book.dart';
import '../logic.dart';
import '../state.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';
import 'fee_sheet_screen.dart';

/// 💰 회비 장부.
/// 권한 규칙(웹앱과 같음): 기록·수정·삭제·현금 수납은 총무(또는 방장)만.
/// 일반 회원은 내 미납 여부와 내역·통계를 볼 수만 있다.
class WalletTab extends StatefulWidget {
  const WalletTab({super.key});
  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  int _tab = 0; // 0=현황 1=내역 2=통계
  /// 내역에서 지금 보여주는 개수 — 다 만들면 기록이 쌓일수록 화면이 멈칫한다
  int _shown = 50;

  /* ☑️ 「여러 명 한 번에 받기」 — 모임 날 총무가 그 자리에서 여러 사람 회비를 받는다.
     한 사람씩 누르면 회원 20명이면 스무 번을 눌러야 하고, 중간에 누구를 빠뜨렸는지도 모른다. */
  bool _pickMode = false;
  final _picked = <String>{};

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
     이 함수는 «오래 걸리는 일이 끝난 뒤»(사진 지우기·기록 지우기) 자식 화면이 불러 주는데,
     그 사이 모임에서 빠지거나 방이 없어져 화면이 사라졌을 수 있다.
     없어진 화면을 고치려 하면 Flutter 가 터진다(분석기는 setState 를 안 본다 — 183회차). */
  void _r() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final st = AppState.i;
    return Scaffold(
      backgroundColor: Colors.transparent,
      /* ⚠️ «여러 명 고르는 중»에는 둥근 단추를 치운다.
         2026-08-29 화면에서 잡은 버그: 고르기를 켜면 아래에 「N명 회비 한 번에 받기」
         가로 단추가 생기는데, 그 위에 「기록하기」가 겹쳐 앉아 **오른쪽 절반을 덮었다.**
         돈을 기록하는 단추라 잘못 눌리면 엉뚱한 창이 뜨고, 고르는 중에
         「기록하기」를 누를 일도 없으니 아예 안 그린다. */
      floatingActionButton: (st.isTreasurer && !_pickMode)
          ? FloatingActionButton.extended(
              /* ⚠️ «달리는 이름(heroTag)»을 안 주면 Flutter 가 모두 같은 이름을 쓴다.
                 탭 다섯이 IndexedStack 으로 «동시에 살아 있어» 한 화면에 둥근 단추가 여럿이다.
                 그러면 화면을 옮길 때 「같은 이름이 둘」이라며 **앱이 빨간 화면으로 터진다** —
                 2026-08-29 설정에서 「월 회비」을 저장하는 순간 실제로 터졌고,
                 이미 나간 판에도 그대로 들어 있었다. */
              heroTag: 'wallet-add',  // 회비 기록하기
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: const Text('기록하기'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _BalanceCard(),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('현황')),
              ButtonSegment(value: 1, label: Text('내역')),
              ButtonSegment(value: 2, label: Text('통계')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 14),
          if (_tab == 0) ..._status(context),
          if (_tab == 1) ..._ledger(context),
          if (_tab == 2) ..._stats(context),
        ],
      ),
    );
  }

  // ── 현황: 총무는 전원 명단, 일반 회원은 내 것만
  List<Widget> _status(BuildContext context) {
    final st = AppState.i;
    final fee = (st.couple?['fee'] as Map?)?.cast<String, dynamic>();
    final amount = (fee?['amount'] as num?)?.toInt() ?? 0;

    if (amount <= 0) {
      return [
        SectionCard(
          child: Text(
            st.isAdmin
                ? '아직 회비 금액을 정하지 않았어요.\n설정 → 회비에서 월 회비를 정하면 현황이 나와요.'
                : '아직 회비 금액이 정해지지 않았어요.',
            style: const TextStyle(height: 1.6),
          ),
        )
      ];
    }

    if (!st.isTreasurer) {
      final unpaid = Logic.unpaidMonths(Store.i.myUid);
      final prepaid = Logic.prepaidLeft(Store.i.myUid);
      return [
        SectionCard(
          title: '내 회비',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('월 회비 ${fmtWon(amount)}',
                  style: TextStyle(color: Theme.of(context).hintColor)),
              const SizedBox(height: 10),
              if (unpaid.isEmpty)
                Text(
                  prepaid > 0 ? '밀린 회비가 없어요 · 앞으로 $prepaid달치 선납 👍' : '밀린 회비가 없어요 👍',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${unpaid.length}달 밀렸어요 (${fmtWon(amount * unpaid.length)})',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: moneyOut(context))),
                    const SizedBox(height: 4),
                    Text(unpaid.join(', '), style: TextStyle(color: Theme.of(context).hintColor)),
                  ],
                ),
              const SizedBox(height: 10),
              Text('입금은 총무님께 하시면 총무님이 기록해요',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              _AccountBar(),
            ],
          ),
        )
      ];
    }

    // 총무·방장 — 전원 납부 명단
    final members = AppState.i.memberList;
    return [
      SectionCard(
        title: '회원별 납부 현황',
        trailing: Text('월 ${fmtWon(amount)}',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        child: Column(
          children: [
            _AccountBar(),
            /* ⚠️ `Wrap` 이라야 한다 — 「표로 보기」·「밀린 사람 모두」·「여러 명 한 번에」가
               한 줄에 다 못 들어가면 오른쪽으로 넘친다. 폰 설정에서 글자를 키운 회원
               (중장년 동호회에는 흔하다)이 좁은 폰(360px)으로 보면 실제로 넘쳤다 —
               2026-08-29 실측 29픽셀. 넘친 자리의 단추는 아예 못 누른다.
               `Wrap` 은 자리가 모자라면 **아랫줄로 내려 준다.** */
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _pickMode
                    ? Text('받은 분들을 골라주세요 (${_picked.length}명)',
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).hintColor))
                    // 📋 종이 표처럼 «사람 × 달»로 보기 — 대화방에 그대로 올릴 수 있다
                    : TextButton.icon(
                        onPressed: () => openFeeSheet(context),
                        icon: const Icon(Icons.table_chart_outlined, size: 18),
                        label: const Text('📋 표로 보기'),
                      ),
                if (_pickMode)
                  TextButton(
                    onPressed: () => setState(() {
                      // 「밀린 사람만」 고르기 — 모임 날 총무가 가장 자주 하는 일
                      _picked
                        ..clear()
                        ..addAll(members
                            .where((m) => Logic.unpaidMonths(m['uid'] as String).isNotEmpty)
                            .map((m) => m['uid'] as String));
                    }),
                    child: const Text('밀린 사람 모두'),
                  ),
                TextButton(
                  onPressed: () => setState(() {
                    _pickMode = !_pickMode;
                    _picked.clear();
                  }),
                  child: Text(_pickMode ? '그만두기' : '☑️ 여러 명 한 번에'),
                ),
              ],
            ),
            for (final m in members)
              _MemberFeeRow(
                member: m,
                onChanged: _r,
                pickMode: _pickMode,
                picked: _picked.contains(m['uid']),
                onPick: (on) => setState(() {
                  final uid = m['uid'] as String;
                  on ? _picked.add(uid) : _picked.remove(uid);
                }),
              ),
            if (_pickMode) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _picked.isEmpty ? null : () => _receiveMany(context, members),
                  icon: const Icon(Icons.done_all),
                  label: Text(_picked.isEmpty
                      ? '받은 분을 골라주세요'
                      : '${_picked.length}명 회비 한 번에 받기'),
                ),
              ),
            ],
          ],
        ),
      )
    ];
  }

  /* ☑️ 여러 명 회비를 한 번에 받는다.

     ⚠️ 「몇 달치」는 **한 번만** 묻는다 — 모임 날 총무는 대개 「이번 달치」를 한꺼번에 받는다.
        사람마다 묻게 하면 고르기 모드를 쓰는 뜻이 없어진다.
     ⚠️ 한 사람이 실패해도 나머지는 계속 적는다(`FeeBook.receiveMany`).
        그리고 **무엇이 됐고 무엇이 안 됐는지 반드시 말한다** — 총무가 「다 됐겠지」로
        넘어가면 안 적힌 회원은 그대로 미납으로 남는다. */
  Future<void> _receiveMany(BuildContext context, List<Map<String, dynamic>> members) async {
    final amount = ((AppState.i.couple?['fee'] as Map?)?['amount'] as num?)?.toInt() ?? 0;
    if (amount <= 0) return;
    final chosen = members.where((m) => _picked.contains(m['uid'])).toList();
    if (chosen.isEmpty) return;

    final months = await askMonths(
      context,
      title: '${chosen.length}명 회비 받기',
      monthly: amount,
      people: chosen.length,
      maxMonths: FeeBook.maxMonths,
    );
    if (months == null || !context.mounted) return;

    toast(context, '${chosen.length}명 기록하는 중…');
    final res = await FeeBook.receiveMany(members: chosen, months: months);
    if (!context.mounted) return;

    final ok = res.where((r) => r.done).toList();
    final bad = res.where((r) => !r.done).toList();
    setState(() {
      _pickMode = false;
      _picked.clear();
    });
    if (bad.isEmpty) {
      toast(context, '${ok.length}명 회비 ${fmtWon(ok.fold<int>(0, (a, r) => a + r.won))}을 기록했어요 💵');
    } else {
      // 안 된 사람을 이름으로 정확히 알려 준다 — 「몇 명 실패」로는 누구를 다시 받을지 모른다
      await confirmSheet(
        context,
        '${ok.length}명 기록, ${bad.length}명 못 함',
        bad.map((r) => '· ${r.name}: ${r.why ?? "안 됐어요"}').join('\n'),
        okLabel: '알겠어요',
      );
    }
    _r();
  }

  // ── 내역: 누구나 열람
  List<Widget> _ledger(BuildContext context) {
    final rows = [...AppState.i.by('ledger')]
      ..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
    if (rows.isEmpty) {
      return [
        SectionCard(child: Text('아직 기록이 없어요', style: TextStyle(color: Theme.of(context).hintColor)))
      ];
    }
    // 최근 것부터 조금씩 — 기록이 몇 백 건 쌓여도 화면이 멈칫하지 않게
    final shown = rows.take(_shown).toList();
    final rest = rows.length - shown.length;
    return [
      for (final x in shown) ...[
        _LedgerRow(item: x, onChanged: _r),
        const SizedBox(height: 8),
      ],
      if (rest > 0)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: OutlinedButton(
            onPressed: () => setState(() => _shown += 50),
            child: Text('이전 기록 $rest건 더 보기'),
          ),
        ),
    ];
  }

  // ── 통계: 누구나 열람
  List<Widget> _stats(BuildContext context) {
    final rows = AppState.i.by('ledger');
    final inSum = rows.where((x) => x['kind'] == 'in').fold<int>(0, (s, x) => s + Logic.asInt(x['amount']));
    final outSum = rows.where((x) => x['kind'] != 'in').fold<int>(0, (s, x) => s + Logic.asInt(x['amount']));
    final byCat = <String, int>{};
    for (final x in rows.where((x) => x['kind'] != 'in')) {
      // 웹앱은 영어 열쇠로 적는다 — 한글로 맞춰야 같은 갈래끼리 합쳐진다
      final c = Logic.catLabel(x['cat']) ?? '기타';
      byCat[c] = (byCat[c] ?? 0) + Logic.asInt(x['amount']);
    }
    final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [
      SectionCard(
        title: '전체',
        child: Column(
          children: [
            _StatRow('들어온 돈', fmtWon(inSum), moneyIn(context)),
            _StatRow('나간 돈', fmtWon(outSum), moneyOut(context)),
            const Divider(height: 20),
            // 마이너스인데 강조색으로 두면 총무가 «괜찮은 줄» 안다 — 이 앱의 돈 색 규칙을 따른다
            _StatRow('남은 돈', fmtWon(inSum - outSum),
                inSum - outSum < 0 ? moneyOut(context) : Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (cats.isNotEmpty)
        SectionCard(
          title: '어디에 썼나',
          child: Column(
            children: [
              for (final c in cats) _StatRow(c.key, fmtWon(c.value), null),
            ],
          ),
        ),
    ];
  }

  Future<void> _openForm(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => const _LedgerForm(),
    );
    if (ok == true) _r();
  }
}

class _BalanceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bal = Logic.balance();
    final cs = Theme.of(context).colorScheme;
    // 통장이 비면(마이너스면) 한눈에 보여야 한다
    final color = bal < 0 ? moneyOut(context) : cs.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            Text('모임 통장', style: TextStyle(color: Theme.of(context).hintColor)),
            const SizedBox(height: 6),
            Text(fmtWon(bal),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _StatRow(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

/// 회원 한 줄 — 총무가 여기서 바로 「회비 받기」를 누른다.
class _MemberFeeRow extends StatelessWidget {
  final Map<String, dynamic> member;
  final VoidCallback onChanged;

  /// 고르기 모드에서는 단추 대신 «네모칸»을 보인다
  final bool pickMode;
  final bool picked;
  final void Function(bool on)? onPick;

  const _MemberFeeRow({
    required this.member,
    required this.onChanged,
    this.pickMode = false,
    this.picked = false,
    this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final uid = member['uid'] as String;
    final unpaid = Logic.unpaidMonths(uid);
    final prepaid = Logic.prepaidLeft(uid);
    final cs = Theme.of(context).colorScheme;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Avatar(uid, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member['name'] as String? ?? '회원',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  unpaid.isEmpty
                      ? (prepaid > 0 ? '선납 $prepaid달' : '밀린 것 없음')
                      : '${unpaid.length}달${Logic.unpaidTruncated(uid) ? ' 이상' : ''} 밀림'
                          ' · ${unpaid.first}부터',
                  style: TextStyle(
                    fontSize: 12,
                    color: unpaid.isEmpty ? Theme.of(context).hintColor : moneyOut(context),
                  ),
                ),
              ],
            ),
          ),
          if (pickMode)
            Checkbox(value: picked, onChanged: (v) => onPick?.call(v ?? false))
          else
            FilledButton.tonal(
              onPressed: () => _receive(context, uid, member['name'] as String? ?? '회원'),
              // ⚠️ 줄 안의 단추는 «가로 꽉 채우기»를 되돌려야 한다 — 안 그러면 옆 이름이 0폭이 된다
              style: inlineButtonStyle.merge(FilledButton.styleFrom(
                backgroundColor: unpaid.isEmpty ? null : cs.primary,
                foregroundColor: unpaid.isEmpty ? null : cs.onPrimary,
              )),
              child: const Text('회비 받기'),
            ),
        ],
      ),
    );
    // 고르기 모드에서는 «줄 아무 데나» 눌러도 켜진다 — 작은 네모만 누르게 하면 손이 아프다
    return pickMode
        ? InkWell(onTap: () => onPick?.call(!picked), child: row)
        : row;
  }

  /* 회비 받기 — 몇 달치든 받을 수 있다(직접 적기 포함).
     받은 달은 이미 받은 다음 달부터 자동으로 이어진다. */
  Future<void> _receive(BuildContext context, String uid, String name) async {
    final amount =
        ((AppState.i.couple?['fee'] as Map?)?['amount'] as num?)?.toInt() ?? 0;
    if (amount <= 0) return toast(context, '설정에서 월 회비 금액을 먼저 정해주세요');

    final months = await askMonths(
      context,
      title: '$name님 회비 받기',
      monthly: amount,
      maxMonths: FeeBook.maxMonths,
    );
    if (months == null || !context.mounted) return;

    final r = await FeeBook.receive(uid: uid, name: name, months: months);
    if (!context.mounted) return;
    if (r.skipped || !r.done) {
      return saveFailToast(context, r.why ?? '기록하지 못했어요 — 다시 눌러주세요');
    }
    toast(context,
        '$name님 회비 ${fmtWon(r.won)}을 기록했어요 💵 (${Logic.feeSpan(r.months)})');
    onChanged();
  }
}

class _LedgerRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onChanged;
  const _LedgerRow({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isIn = item['kind'] == 'in';
    final amount = Logic.asInt(item['amount']);
    final span = Logic.feeSpan(item['feeMonths']);
    final cat = Logic.catLabel(item['cat']); // 웹앱이 적은 영어 열쇠도 한글로
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (isIn ? moneyIn(context) : moneyOut(context)).withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(isIn ? Icons.south_west : Icons.north_east,
                size: 18, color: isIn ? moneyIn(context) : moneyOut(context)),
          ),
          const SizedBox(width: 12),
          /* 🧾 영수증이 붙어 있으면 여기서 바로 보인다 — 눌러서 크게 볼 수 있다.
             찾을 자리는 사진첩이 아니라 «그 지출 기록 옆»이다.

             ⚠️ 목록에서는 **썸네일을 먼저** 쓴다(웹앱도 그렇게 한다).
                원본을 받아오면 내역 한 장에 마흔 건이 뜰 때 마흔 장을 받는다 —
                느려지고 그만큼 요금이 나간다. 썸네일은 기록 안에 이미 들어 있다. */
          if (_receiptOf(item) != null) ...[
            _ReceiptThumb(item: item),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((item['title'] as String?) ?? (isIn ? '입금' : '지출'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '${item['date'] ?? ''}'
                  '${span == null ? '' : ' · $span'}'
                  '${cat == null ? '' : ' · $cat'}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          /* ⚠️ 금액도 «자리를 나눠 갖게» 한다. 한 줄에 동그란 아이콘·제목·금액·메뉴가
             모두 들어가는데, 폰 설정에서 글자를 키운 회원(중장년 동호회에는 흔하다)이
             좁은 폰(360px)으로 보면 넘쳤다 — 2026-08-29 실측 18픽셀.
             금액은 «잘리면 안 되는» 값이라 줄이지 않고 자리만 확보한다. */
          Flexible(
            child: Text('${isIn ? '+' : '-'}${fmtWon(amount)}',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isIn ? moneyIn(context) : moneyOut(context))),
          ),
          /* 지우기는 «둘 다» 맞아야 서버가 받아 준다 —
             돈을 다룰 수 있고(isTreasurer), 그 기록을 지울 수 있어야 한다(canDeleteItem).
             하나만 보고 메뉴를 띄우면 눌러도 안 되는 단추가 된다. */
          if (AppState.i.isTreasurer &&
              Logic.canDeleteItem(item, Store.i.myUid))
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v != 'del') return;
                final ok = await confirmSheet(context, '이 기록을 지울까요?', '되돌릴 수 없어요',
                    okLabel: '지우기', danger: true);
                if (!ok) return;
                final code = AppState.i.code;
                if (code == null) return;
                final done =
                    await Store.i.deleteItem(code, item['id'] as String, 'ledger');
                if (!context.mounted) return;
                if (!done) return toast(context, '지우지 못했어요 — 다시 시도해주세요');
                Store.i.dropPhotos(Store.photoIdsOf(item));
                toast(context, '기록을 지웠어요');
                onChanged();
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'del', child: Text('지우기'))],
            ),
        ],
      ),
    );
  }
}

/* 지출 갈래는 **웹앱과 같은 열쇠**로 적는다(보여 줄 때만 한글 — `Logic.catLabel`).
   ⚠️ 예전에는 한글을 그대로 적었다. 그런데 웹앱의 「어디에 썼나」는 **아는 열쇠 7개만** 세므로
      (`LEDGER_CATS.filter(x => (x.cat||'etc') === k)`), 앱으로 적은 지출이
      **아이폰 회원 화면의 갈래별 합계에서 통째로 빠졌다** — 목록에는 나오는데 합계에는 없다.
      총무가 아이폰이면 갈래별 지출을 실제보다 적게 본다.
   웹의 `LEDGER_CATS` 와 같은 열쇠·같은 차례. */
const _outCats = ['court', 'shuttle', 'party', 'game', 'gear', 'etc'];

class _LedgerForm extends StatefulWidget {
  const _LedgerForm();
  @override
  State<_LedgerForm> createState() => _LedgerFormState();
}

class _LedgerFormState extends State<_LedgerForm> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  String _cat = _outCats.first;
  DateTime _date = DateTime.now();
  bool _busy = false;

  /* 🧾 영수증 사진 — **사진첩과 따로 간다.**

     ⚠️ 사진첩에 올리면(`type: 'photo'`) 모임 사진들 사이에 영수증이 섞인다.
        그래서 장부 기록 «안»에 번호만 붙인다(`rcptId`) — 웹앱이 이미 그렇게 한다.
        칸 이름을 웹과 똑같이 써야 서로 읽는다(`rcptId`·`rcptThumb`).
     ⚠️ 올려 두고 저장에 실패하면 **원본만 보관함에 남아** 매달 요금이 나간다.
        그래서 저장이 안 되면 방금 올린 것을 도로 지운다. */
  String? _rcptId;
  String? _rcptThumb;
  bool _rcptBusy = false;
  /// 저장까지 끝났는가 — 안 끝난 채 창이 닫히면 올려 둔 영수증이 «주인 없는 원본»이 된다
  bool _saved = false;

  @override
  void dispose() {
    /* ⚠️ 영수증만 올려 두고 **창을 그냥 닫는** 길이 있다(뒤로가기·바깥 누르기).
       그러면 그 원본은 아무 기록도 안 붙들고 있는 채 보관함에 남아
       **매달 요금만 나간다** — 아무도 못 보는 파일이다.
       저장이 끝났으면 그 기록이 붙들고 있으므로 건드리지 않는다. */
    if (!_saved && _rcptId != null) Store.i.dropPhotos([_rcptId]);
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    if (_rcptBusy) return;
    final code = AppState.i.code;
    if (code == null) return;
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
    if (x == null || !mounted) return;
    setState(() => _rcptBusy = true);
    try {
      final bytes = await x.readAsBytes();
      final id = await Store.i.savePhoto(code, bytes);
      if (id == null) {
        if (mounted) toast(context, '영수증을 올리지 못했어요 — 다시 눌러주세요');
        return;
      }
      // 웹은 «작은 그림» 칸으로만 그린다 — 안 넣으면 웹에서 깨져 보인다
      final thumb = await Store.makeThumb(bytes);
      if (!mounted) return;
      // 바꿔 붙이는 것이면 앞서 올린 것은 지운다 (저장 전이라 아무 데도 안 걸려 있다)
      final old = _rcptId;
      setState(() {
        _rcptId = id;
        _rcptThumb = thumb;
      });
      if (old != null) Store.i.dropPhotos([old]);
    } finally {
      if (mounted) setState(() => _rcptBusy = false);
    }
  }

  void _removeReceipt() {
    final old = _rcptId;
    setState(() {
      _rcptId = null;
      _rcptThumb = null;
    });
    // 아직 저장 전이라 이 원본은 아무 기록도 안 붙들고 있다 — 그대로 두면 요금만 나간다
    if (old != null) Store.i.dropPhotos([old]);
  }

  Future<void> _save() async {
    if (_busy) return;
    final title = _title.text.trim();
    final amount = int.tryParse(_amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (title.isEmpty) return toast(context, '어디에 썼는지 적어주세요');
    if (amount <= 0) return toast(context, '금액을 적어주세요');
    final code = AppState.i.code;
    if (code == null) return;
    setState(() => _busy = true);
    final id = await Store.i.addItem(code, {
      'type': 'ledger',
      'kind': 'out',
      'title': title,
      'amount': amount,
      'cat': _cat,
      /* 💰 「누가 냈나」 — 이 앱에는 고르는 칸이 없고 «모임 통장에서 나간 것»이 전제다.
         ⚠️ 안 적으면 안 되는 이유: 같은 자료를 보는 웹은 이 칸을 그대로 화면에 그리는데,
            비어 있으면 `nameOf(undefined)` 가 **「탈퇴한 회원」**을 돌려준다 →
            앱에서 적은 지출이 전부 「탈퇴한 회원이 결제」로 보인다.
         `wallet` 은 웹이 「회비통장」을 가리킬 때 쓰는 말이다(웹의 기본값과 같다). */
      'payer': Store.walletPayer,
      'date': ymd(_date),
      // 🧾 영수증 — 사진첩과 따로, 이 기록 안에만 붙는다 (웹앱과 같은 칸 이름)
      if (_rcptId != null) 'rcptId': _rcptId,
      if (_rcptThumb != null) 'rcptThumb': _rcptThumb,
    });
    if (!mounted) return;
    if (id == null) {
      setState(() => _busy = false);
      /* ⚠️ 저장이 안 됐으면 **방금 올린 영수증을 도로 지운다.**
         안 지우면 아무 기록도 안 붙들고 있는 원본이 보관함에 남아 매달 요금이 나간다.
         (이 창은 새로 적는 자리라, 여기 있는 영수증은 늘 «방금 올린 것»이다) */
      final orphan = _rcptId;
      if (orphan != null) Store.i.dropPhotos([orphan]);
      setState(() {
        _rcptId = null;
        _rcptThumb = null;
      });
      return saveFailToast(context, '기록하지 못했어요 — 다시 눌러주세요');
    }
    _saved = true; // 이제 이 원본은 기록이 붙들고 있다 — 창이 닫혀도 지우면 안 된다
    Navigator.pop(context, true);
    toast(context, '지출 ${fmtWon(amount)}을 기록했어요');
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
            const Text('지출 기록하기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('회비를 받은 것은 「현황」 탭에서 회원별로 눌러 기록해요',
                style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              maxLength: 30,
              decoration: const InputDecoration(labelText: '어디에 썼나요', counterText: ''),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '금액', suffixText: '원'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final c in _outCats)
                  ChoiceChip(
                    // 적기는 웹과 같은 열쇠로, 보여 주기는 한글로
                    label: Text(Logic.catLabel(c) ?? c),
                    selected: _cat == c,
                    onSelected: (_) => setState(() => _cat = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: clampDate(_date, DateTime(2020), DateTime(2100)),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _date = d);
              },
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(ymd(_date)),
            ),
            const SizedBox(height: 12),
            /* 🧾 영수증 — 총무가 나중에 「이거 뭐였지」 할 때 찾는 자리.
               사진첩에는 안 올라간다(모임 사진들 사이에 영수증이 섞이면 안 된다). */
            _ReceiptPicker(
              thumb: _rcptThumb,
              photoId: _rcptId,
              busy: _rcptBusy,
              onPick: _pickReceipt,
              onRemove: _removeReceipt,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? '저장 중…' : '저장'),
            ),
          ],
        ),
      ),
    );
  }
}


/* 🏦 「회비 보내는 곳」 — 눌러서 복사한다.

   ⚠️ 없으면 아무것도 그리지 않는다 (빈 줄이 남으면 «뭔가 빠진 화면»으로 보인다).
   ⚠️ 복사한 뒤 반드시 말해 준다 — 눌렀는데 아무 일도 안 일어나면 안 된 줄 알고 또 누른다. */
class _AccountBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final acc =
        (((AppState.i.couple?['fee'] as Map?)?['account'] as String?) ?? '').trim();
    if (acc.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: acc));
          if (context.mounted) toast(context, '계좌를 복사했어요');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Text('🏦 ', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Text(acc,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Icon(Icons.copy, size: 16, color: Theme.of(context).hintColor),
            ],
          ),
        ),
      ),
    );
  }
}

/* 🧾 영수증 붙이는 자리 — 지출 기록 창 안에 들어간다.

   ⚠️ 사진첩(`type: 'photo'`)에는 안 올라간다. 장부 기록 «안»에 번호만 붙는다.
      모임 사진들 사이에 영수증이 섞이면 사진첩이 지저분해지고,
      영수증을 찾으려 사진첩을 뒤지게 된다 — 찾을 자리는 그 지출 기록 옆이다. */
class _ReceiptPicker extends StatelessWidget {
  final String? thumb;
  final String? photoId;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _ReceiptPicker({
    required this.thumb,
    required this.photoId,
    required this.busy,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final has = photoId != null;
    return Row(
      children: [
        if (has)
          // 눌러서 크게 보기는 ClubPhoto 가 이미 한다 — 총무가 금액을 다시 확인한다
          ClubPhoto(
            photoId: photoId,
            width: 56,
            height: 56,
            decodeWidth: 200,
            radius: BorderRadius.circular(8),
          ),
        if (has) const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : onPick,
            icon: busy
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.receipt_long, size: 18),
            // 왼쪽에 이미 그림표가 있다 — 글에 이모지를 또 넣으면 아이콘이 둘로 보인다
            label: Text(busy
                ? '올리는 중…'
                : has
                    ? '영수증 바꾸기'
                    : '영수증 사진 붙이기 (선택)'),
          ),
        ),
        if (has)
          IconButton(
            onPressed: busy ? null : onRemove,
            icon: const Icon(Icons.close),
            tooltip: '영수증 떼기',
          ),
      ],
    );
  }
}

/// 이 기록에 영수증이 붙어 있는가 — 썸네일이든 원본이든 하나만 있으면 «있다»
String? _receiptOf(Map<String, dynamic> item) {
  final thumb = item['rcptThumb'] as String?;
  if (thumb != null && thumb.isNotEmpty) return thumb;
  final id = item['rcptId'] as String?;
  return (id != null && id.isNotEmpty) ? id : null;
}

/* 🧾 내역 줄에 붙는 작은 영수증.

   ⚠️ 목록에서는 **썸네일을 먼저** 쓴다 — 원본을 받아오면 마흔 건이 뜰 때 마흔 장을 받는다.
      썸네일은 기록 «안»에 글자로 들어 있어 따로 받아올 것이 없다(웹앱도 그렇게 한다).
      썸네일이 없는 옛 기록만 원본으로 되돌아간다. */
class _ReceiptThumb extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ReceiptThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    final thumb = item['rcptThumb'] as String?;
    final id = item['rcptId'] as String?;
    final hasId = id != null && id.isNotEmpty;

    /* 원본이 있으면 `ClubPhoto` 에 맡긴다 — 목록에서는 작은 그림만 그리고,
       누르면 그것이 알아서 «원본»을 크게 보여 준다(영수증은 금액을 읽어야 한다).
       ⚠️ 아직 못 받아온 동안 보여 줄 것으로 **썸네일을 준다** — 빈 네모 대신
          영수증이 곧바로 보이고, 마흔 건이 떠도 원본을 마흔 장 받지 않는다. */
    if (hasId) {
      return ClubPhoto(
        photoId: id,
        width: 34,
        height: 34,
        decodeWidth: 140,
        radius: BorderRadius.circular(6),
        placeholder: (thumb != null && thumb.isNotEmpty)
            ? ClubPhoto.fromSrc(thumb, width: 34, height: 34, decodeWidth: 140)
            : null,
      );
    }

    // 원본 없이 썸네일만 있는 옛 기록 — 그것이라도 보여 준다
    return GestureDetector(
      onTap: () => showPhotoViewer(context, thumb!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 34,
          height: 34,
          child: ClubPhoto.fromSrc(thumb!, width: 34, height: 34, decodeWidth: 140),
        ),
      ),
    );
  }
}
