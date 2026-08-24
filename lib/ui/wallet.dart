import 'package:flutter/material.dart';

import '../logic.dart';
import '../state.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';

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
      floatingActionButton: st.isTreasurer
          ? FloatingActionButton.extended(
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
            ],
          ),
        )
      ];
    }

    // 총무·방장 — 전원 납부 명단
    return [
      SectionCard(
        title: '회원별 납부 현황',
        trailing: Text('월 ${fmtWon(amount)}',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        child: Column(
          children: [
            for (final m in AppState.i.memberList) _MemberFeeRow(member: m, onChanged: _r),
          ],
        ),
      )
    ];
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
  const _MemberFeeRow({required this.member, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final uid = member['uid'] as String;
    final unpaid = Logic.unpaidMonths(uid);
    final prepaid = Logic.prepaidLeft(uid);
    final cs = Theme.of(context).colorScheme;

    return Padding(
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
  }

  /// 1/3/6/12개월 선납 — 받은 달은 이미 받은 다음 달부터 자동으로 이어진다.
  Future<void> _receive(BuildContext context, String uid, String name) async {
    final fee = (AppState.i.couple?['fee'] as Map?)?.cast<String, dynamic>();
    final amount = (fee?['amount'] as num?)?.toInt() ?? 0;
    if (amount <= 0) return toast(context, '설정에서 월 회비 금액을 먼저 정해주세요');

    final pick = await chooseSheet(
      context,
      '$name님 회비 받기',
      '몇 달치를 받으셨나요? (월 ${fmtWon(amount)})',
      [
        ['1', '1개월 · ${fmtWon(amount)}'],
        ['3', '3개월 · ${fmtWon(amount * 3)}'],
        ['6', '6개월 · ${fmtWon(amount * 6)}'],
        ['12', '12개월 · ${fmtWon(amount * 12)}'],
      ],
    );
    if (pick == null) return;
    final months = int.parse(pick);

    // 메울 달 = 아직 안 낸 달부터 차례로 (이미 낸 달은 건너뛴다)
    final feeMonths = Logic.feeMonthsToFill(uid, months);
    final code = AppState.i.code;
    if (code == null) return;
    if (!context.mounted) return;
    // 메울 달이 하나도 없다 = 앞으로 아주 멀리까지 이미 채워져 있다.
    // 아무 말 없이 끝내면 「눌렀는데 아무 일도 안 일어나는 단추」가 된다
    if (feeMonths.isEmpty) {
      return toast(context, '앞으로 낼 달이 이미 다 채워져 있어요 — 더 받을 달이 없습니다');
    }
    /* 총무 둘이 «거의 동시에» 눌렀을 때를 막는 것은 아래의 «고정 문서 이름»이다.
       여기서 `paidIn` 을 한 번 더 묻는 코드가 있었는데, 바로 위 `feeMonthsToFill` 이
       이미 낸 달을 건너뛰고 고른 값이라 **절대 걸리지 않는 죽은 검사**였다.
       (그 사이에 기다리는 곳이 없어 남의 기록이 끼어들 틈도 없다)
       진짜 막이는 `docId: Store.feeDocId(...)` 하나뿐이니 그걸 지워선 안 된다. */
    final id = await Store.i.addItem(
      code,
      {
        'type': 'ledger',
        'kind': 'in',
        'title': months == 1 ? '$name 회비' : '$name 회비 $months개월',
        'amount': amount * months,
        'payer': uid,
        'months': months,
        'feeMonths': feeMonths,
        'date': ymd(DateTime.now()),
      },
      // 총무 둘이 동시에 눌러도 같은 달이 두 번 기록되지 않게 이름을 고정한다
      docId: Store.feeDocId(code, uid, feeMonths.first),
    );
    if (!context.mounted) return;
    // 저장에 실패했는데 「기록했어요」라고 하면 총무는 받은 줄 알고 넘어가고 회원은 미납으로 남는다
    if (id == null) return toast(context, '기록하지 못했어요 — 다시 눌러주세요');
    toast(context,
        '$name님 회비 ${fmtWon(amount * months)}을 기록했어요 💵 (${Logic.feeSpan(feeMonths)})');
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
          Text('${isIn ? '+' : '-'}${fmtWon(amount)}',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isIn ? moneyIn(context) : moneyOut(context))),
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

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
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
    });
    if (!mounted) return;
    if (id == null) {
      setState(() => _busy = false);
      return toast(context, '기록하지 못했어요 — 다시 눌러주세요');
    }
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
