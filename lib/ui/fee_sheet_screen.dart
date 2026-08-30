import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../fee_sheet.dart';
import '../logic.dart';
import '../state.dart';
import '../store.dart';
import 'common.dart';

/* 📋 회비 납부 현황표 · 지출 표 — 총무가 종이에 그리던 그 표.

   ⚠️ **회장·총무만** 연다. 누가 몇 달 밀렸는지는 그 사람에게 부끄러울 수 있어서,
      아무나 열게 하면 회비 독촉이 모임 안의 다툼이 된다.
      (회원 각자는 회비 화면에서 «자기 것»만 본다 — 그건 그대로 둔다)

   ⚠️ 표를 «그림»으로 만들어 대화방에 올린다. 글로 옮기면 폰마다 줄이 어긋나 표가 깨진다.
      그림은 화면 «밖»에서 따로 그린다 — 화면에 보이는 것만 찍으면
      회원이 30명일 때 스크롤 밖이 통째로 빠진다. */
class FeeSheetScreen extends StatefulWidget {
  const FeeSheetScreen({super.key});
  @override
  State<FeeSheetScreen> createState() => _FeeSheetScreenState();
}

class _FeeSheetScreenState extends State<FeeSheetScreen> {
  int _months = 6;

  /* 📅 «직접 고른» 기간 (둘 다 있을 때만 쓴다).
     총무는 결산·감사 때 「작년 3월부터 8월까지」 같은 지난 자리를 봐야 한다 —
     「최근 N개월」만으로는 못 본다. */
  String? _fromYm, _toYm;
  int _tab = 0; // 0=회비 1=지출
  bool _busy = false;

  /* ⚠️ 열자마자 «이번 달»이 보여야 한다.
     달은 왼쪽(옛날) → 오른쪽(이번 달) 차례라, 그냥 두면 화면에는 옛 달만 보이고
     총무가 가장 보고 싶은 이번 달은 오른쪽 밖에 있다.
     2026-08-28 에뮬레이터에서 실제로 «텅 빈 표»처럼 보였다 — 값은 다 있었는데도. */
  final _hScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _toNow());
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  /* 📅 기간 직접 고르기 — 시작 달과 끝 달을 달력에서 고른다.

     ⚠️ 달력은 «날»을 고르게 돼 있지만 우리는 «달»만 쓴다 — 며칠을 골랐든 그 달로 본다.
        (`showDatePicker` 에 달만 고르는 모드가 없다. 회원에게는 「그 달의 아무 날」로 안내한다)
     ⚠️ 취소하면 아무것도 안 바꾼다 — 고르다 말았는데 표가 바뀌면 놀란다. */
  Future<void> _pickRange() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 10);
    final last = DateTime(now.year + 1, 12, 31);

    /* ⚠️ `initialDate` 는 **반드시 `clampDate` 를 거친다** — 범위 밖 값이 들어오면
       달력이 그 자리에서 터진다(assert). 지금은 «오늘»에서 만들어 안전하지만,
       나중에 저장된 값을 쓰게 되면 그때 터진다. 앱 전체가 이 규칙을 지킨다. */
    final a = await showDatePicker(
      context: context,
      initialDate: clampDate(DateTime(now.year, now.month), first, last),
      firstDate: first,
      lastDate: last,
      helpText: '시작 달 — 그 달의 아무 날이나',
    );
    // 취소하면 아무것도 안 바꾼다 — 고르다 말았는데 표가 바뀌면 놀란다
    if (a == null) return;
    if (!mounted) return;
    final b = await showDatePicker(
      context: context,
      initialDate: clampDate(now, first, last),
      firstDate: first,
      lastDate: last,
      helpText: '끝 달 — 그 달의 아무 날이나',
    );
    if (b == null) return;
    if (!mounted) return;

    setState(() {
      _fromYm = Logic.ymKey(Logic.ymOf(a));
      _toYm = Logic.ymKey(Logic.ymOf(b));
    });
    // 기간을 바꾸면 표를 «맨 끝»(가장 최근 달)으로 — 안 그러면 옛 달만 보인다
    WidgetsBinding.instance.addPostFrameCallback((_) => _toNow());
    if (!mounted) return;
    final n = FeeSheet.monthRange(_fromYm!, _toYm!).length;
    toast(context, '$_fromYm ~ $_toYm · $n개월을 봅니다');
  }

  /// 「최근 N개월」로 — 직접 고른 기간은 푼다(둘이 겹치면 어느 쪽인지 모른다)
  void _setMonths(int n) {
    setState(() {
      _months = n;
      _fromYm = null;
      _toYm = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _toNow());
  }

  /// 올해 1월부터 이번 달까지 — 결산할 때 제일 자주 보는 자리다
  void _setThisYear() {
    final now = DateTime.now();
    setState(() {
      _fromYm = '${now.year}-01';
      _toYm = Logic.ymKey(Logic.ymOf(now));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _toNow());
  }

  bool _isThisYear() {
    final now = DateTime.now();
    return _fromYm == '${now.year}-01' && _toYm == Logic.ymKey(Logic.ymOf(now));
  }

  void _toNow() {
    if (!_hScroll.hasClients) return;
    _hScroll.jumpTo(_hScroll.position.maxScrollExtent);
  }

  static const _headStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 13);
  static const _cellStyle = TextStyle(fontSize: 13);
  static const _headBg = Color(0xFFD8D2EC); // 종이 표와 같은 연보라 머리글
  static const _altBg = Color(0xFFF1EEF9);
  /* 🚫 «낼 까닭이 없던 달» — 가입 전, 나간 다음 달부터.
     빗금 대신 잿빛으로 눌러 둔다: 미납(−)이 있는 칸과 한눈에 갈린다.
     ⚠️ 글자로도 갈려 있어야 한다(빈칸 vs −) — 색만으로 가르면 흑백 인쇄에서 사라진다. */
  static const _outBg = Color(0xFFE4E4E7);
  static const _exemptBg = Color(0xFFDCF3E4); // 면제해 준 달 — 연한 풀빛
  static const _lineColor = Color(0xFFBFC7D2);

  @override
  Widget build(BuildContext context) {
    final months = (_fromYm != null && _toYm != null)
        ? FeeSheet.monthRange(_fromYm!, _toYm!)
        : FeeSheet.monthKeys(_months);
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? '회비 납부 현황' : '지출 내역'),

      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('회비')),
                ButtonSegment(value: 1, label: Text('지출')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) {
                setState(() => _tab = s.first);
                /* ⚠️ 탭을 바꿀 때도 «이번 달»로 옮겨야 한다.
                   회비 표는 좁아서 한 화면에 들어가 스크롤이 0인데, 지출 표는 칸이 넓어
                   넘친다 — 그대로 두면 지출로 바꾸는 순간 «텅 빈 옛 달»만 보인다
                   (2026-08-28 에뮬레이터에서 실제로 그랬다). */
                WidgetsBinding.instance.addPostFrameCallback((_) => _toNow());
              },
            ),
          ),
          /* 📅 «얼마 동안»을 볼지 — 회비·지출 줄 바로 옆에 둔다.
             예전에는 위쪽 달력 그림 안에 숨어 있어, 총무가 그런 것이 있는 줄 몰랐다. */
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('최근 6개월'),
                  selected: _fromYm == null && _months == 6,
                  onSelected: (_) => _setMonths(6),
                ),
                ChoiceChip(
                  label: const Text('올해'),
                  selected: _isThisYear(),
                  onSelected: (_) => _setThisYear(),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.date_range, size: 16),
                  label: Text(_fromYm != null && !_isThisYear()
                      ? '$_fromYm ~ $_toYm'
                      : '기간 설정'),
                  selected: _fromYm != null && !_isThisYear(),
                  onSelected: (_) => _pickRange(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
              child: _tab == 0 ? _feeTable(months) : _outTable(months),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
          /* ⚠️ «달리는 이름(heroTag)»을 안 주면 Flutter 가 모두 같은 이름을 쓴다.
             탭 다섯이 IndexedStack 으로 «동시에 살아 있어» 한 화면에 둥근 단추가 여럿이다.
             그러면 화면을 옮길 때 「같은 이름이 둘」이라며 **앱이 빨간 화면으로 터진다** —
             2026-08-29 설정에서 「월 회비」을 저장하는 순간 실제로 터졌고,
             이미 나간 판에도 그대로 들어 있었다. */
          heroTag: 'feesheet-share',  // 표 올리기
        onPressed: _busy ? null : () => _share(months),
        icon: _busy
            ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.send),
        label: Text(_busy ? '만드는 중…' : '대화방에 올리기'),
      ),
    );
  }

  // ── 표 그리기 ────────────────────────────────────────────────
  // 화면에 보이는 표와 대화방에 올라가는 그림을 **같은 코드**로 그린다.
  // 둘을 따로 그리면 「화면에선 맞는데 올린 그림은 다르다」가 반드시 생긴다.

  Widget _box(Widget child,
          {double w = 46, Color? bg, Alignment align = Alignment.center}) =>
      Container(
        width: w,
        height: 34,
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: _lineColor, width: 0.6),
        ),
        child: child,
      );

  /* 표 한 판을 그린다.

     ⚠️ **첫 칸(회원명·갈래)은 고정**한다. 옆으로 밀 때 이름까지 같이 밀려 나가면
        무슨 줄인지 알 수 없는 숫자판이 된다 — 2026-08-28 에뮬레이터에서 실제로 그랬다.
     ⚠️ 대화방에 올릴 그림은 `scroll: false` 로 그린다 — 스크롤 없이 통째로 그려야
        달이 12개여도 잘리지 않는다. */
  Widget _grid({
    required List<Widget> firstCol,
    required List<List<Widget>> monthRows,
    bool scroll = true,
  }) {
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final r in monthRows) Row(children: r)],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: firstCol),
        if (scroll)
          Flexible(
            child: SingleChildScrollView(
              controller: _hScroll,
              scrollDirection: Axis.horizontal,
              child: right,
            ),
          )
        else
          right,
      ],
    );
  }

  Widget _feeTable(List<String> months, {bool scroll = true}) {
    // 나갔어도 «밀린 것이 남았으면» 표에 남는다 — 안 그러면 받을 돈이 묻힌다
    final members = FeeSheet.rowMembers(months);
    return _grid(
      scroll: scroll,
      firstCol: [
        _box(const Text('회원명', style: _headStyle), w: 96, bg: _headBg),
        for (var i = 0; i < members.length; i++)
          _box(
            Text(
                '${i + 1}. ${members[i]['name'] ?? '회원'}'
                // 나간 사람인 줄 모르면 총무가 「왜 안 나오지」 하며 찾는다
                '${members[i]['left'] == true ? ' (탈퇴)' : ''}',
                style: _cellStyle, overflow: TextOverflow.ellipsis),
            w: 96,
            bg: members[i]['left'] == true
                ? _outBg
                : (i.isEven ? _altBg : null),
            align: Alignment.centerLeft,
          ),
        // 합계 줄 — 「이번 달 몇 명이 냈는지」가 총무가 가장 자주 보는 값이다
        _box(const Text('납부', style: _headStyle), w: 96, bg: _headBg),
      ],
      monthRows: [
        [
          for (final m in months)
            _box(Text(FeeSheet.monthLabel(m), style: _headStyle), bg: _headBg)
        ],
        for (var i = 0; i < members.length; i++)
          [
            for (final m in months) _feeCell(members[i], m, i.isEven)
          ],
        [
          for (final m in months)
            _box(Text('${FeeSheet.paidCount(members, m)}', style: _headStyle),
                bg: _headBg)
        ],
      ],
    );
  }

  /* 칸 하나 — 색으로 「셀 것이 있는 달인지」를 알려 주고, 눌러서 면제한다.

     ⚠️ 누르는 것은 **회비를 다루는 사람만**이다. 평회원이 눌러 봐야
        서버가 막으므로, 아예 안 눌리게 해서 헛수고를 없앤다. */
  Widget _feeCell(Map<String, dynamic> member, String month, bool even) {
    final uid = member['uid'] as String;
    final mk = FeeSheet.mark(uid, month);
    final bg = switch (mk) {
      FeeMark.before || FeeMark.after => _outBg,
      FeeMark.exempt => _exemptBg,
      _ => even ? _altBg : null,
    };
    final box = _box(Text(FeeSheet.cell(mk), style: _cellStyle), bg: bg);
    // 낸 달·회원이 아니던 달은 면제할 것이 없다
    final canTap = AppState.i.isTreasurer &&
        (mk == FeeMark.unpaid || mk == FeeMark.exempt);
    if (!canTap) return box;
    return InkWell(
      onTap: () => _toggleExempt(member, month, mk == FeeMark.exempt),
      child: box,
    );
  }

  /* 🙇 그 달만 면제하기 / 되돌리기.
     ⚠️ 되돌릴 때는 안 묻는다 — 잘못 눌러도 한 번 더 누르면 그만이라
        확인 창이 성가시기만 하다(돈이 오가는 일이 아니다). */
  Future<void> _toggleExempt(
      Map<String, dynamic> member, String month, bool on) async {
    final uid = member['uid'] as String;
    final name = (member['name'] as String?) ?? '회원';
    final label = FeeSheet.monthLabel(month);
    if (!on) {
      final ok = await confirmSheet(context, '$name님 $label 회비를 면제할까요?',
          '그 달만 «안 내도 되는 달»로 둡니다. 밀린 셈에서 빠지고, 표에는 「면」으로 남아요.',
          okLabel: '면제하기');
      if (!ok || !mounted) return;
    }
    final code = AppState.i.code;
    if (code == null) return;
    final next = FeeSheet.exemptMonths(uid).toList();
    if (on) {
      next.remove(month);
    } else if (!next.contains(month)) {
      next.add(month);
    }
    next.sort();
    /* 나간 사람은 `former` 쪽에 적힌다 — `members` 에 쓰면 아무 데도 안 남는다
       (다듬기가 없는 회원의 칸을 지운다). 밀린 돈을 정리하려면 여기가 있어야 한다. */
    final where = member['left'] == true ? 'former' : 'members';
    var done = true;
    try {
      await Store.i.patchCouple(code, {'$where.$uid.feeFree': next});
    } catch (_) {
      done = false;
    }
    if (!mounted) return;
    if (!done) return saveFailToast(context, '기록하지 못했어요 — 다시 눌러주세요');
    toast(context, on ? '$name님 $label 면제를 풀었어요' : '$name님 $label 회비를 면제했어요');
    setState(() {});
  }

  /// 만 원 단위로 짧게 — 표 칸에 원 단위를 다 적으면 가로가 두 배가 된다
  static String _won(int v) =>
      v == 0 ? '' : '${(v / 10000).toStringAsFixed(v % 10000 == 0 ? 0 : 1)}만';

  Widget _outTable(List<String> months, {bool scroll = true}) {
    final table = FeeSheet.outByCat(months);
    final cats = table.keys.toList()..sort();
    if (cats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('이 기간에 지출 기록이 없어요',
            style: TextStyle(color: Theme.of(context).hintColor)),
      );
    }
    return _grid(
      scroll: scroll,
      firstCol: [
        _box(const Text('갈래', style: _headStyle), w: 96, bg: _headBg),
        for (var i = 0; i < cats.length; i++)
          _box(Text(cats[i], style: _cellStyle),
              w: 96, bg: i.isEven ? _altBg : null, align: Alignment.centerLeft),
        _box(const Text('합계', style: _headStyle), w: 96, bg: _headBg),
      ],
      monthRows: [
        [
          for (final m in months)
            _box(Text(FeeSheet.monthLabel(m), style: _headStyle), w: 60, bg: _headBg)
        ],
        for (var i = 0; i < cats.length; i++)
          [
            for (final m in months)
              _box(Text(_won(table[cats[i]]?[m] ?? 0), style: _cellStyle),
                  w: 60, bg: i.isEven ? _altBg : null)
          ],
        [
          for (final m in months)
            _box(
                Text(_won(cats.fold<int>(0, (a, c) => a + (table[c]?[m] ?? 0))),
                    style: _headStyle),
                w: 60,
                bg: _headBg)
        ],
      ],
    );
  }

  // ── 대화방에 올리기 ───────────────────────────────────────────

  Future<void> _share(List<String> months) async {
    final code = AppState.i.code;
    if (code == null) return;
    final ok = await confirmSheet(
      context,
      '$_months개월 ${_tab == 0 ? "회비 현황" : "지출"} 표를 올릴까요?',
      '표를 그림으로 만들어 모임 대화방에 보냅니다. 회원 모두가 보게 돼요.',
      okLabel: '올리기',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final bytes = await _capture(_tab == 0
              ? _feeTable(months, scroll: false)
              : _outTable(months, scroll: false));
      if (bytes == null) {
        if (mounted) toast(context, '표를 그림으로 만들지 못했어요');
        return;
      }
      final photoId = await Store.i.savePhoto(code, bytes);
      if (photoId == null) {
        if (mounted) toast(context, '그림을 올리지 못했어요 — 연결을 확인해주세요');
        return;
      }
      final thumb = await Store.makeThumb(bytes);
      final span =
          '${FeeSheet.monthLabel(months.first)}~${FeeSheet.monthLabel(months.last)}';
      final id = await Store.i.addItem(code, {
        'type': 'msg',
        'kind': 'img',
        'photoId': photoId,
        'text': _tab == 0 ? '📋 회비 납부 현황 ($span)' : '💸 지출 내역 ($span)',
        if (thumb != null) 'thumb': thumb,
      });
      if (id == null) {
        // 글이 안 올라갔으면 그림도 남기지 않는다 — 아무도 못 보는 파일에 저장료만 나간다
        Store.i.dropPhotos([photoId]);
        if (mounted) saveFailToast(context, '대화방에 올리지 못했어요 — 다시 해주세요');
        return;
      }
      if (mounted) toast(context, '대화방에 올렸어요 📋');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* 위젯 하나를 «화면 밖에서» 그려 PNG 로 만든다.

     ⚠️ 화면에 붙인 `RepaintBoundary` 를 찍는 흔한 방법은 **스크롤 밖을 못 담는다** —
        회원 30명이면 화면에 보이는 예닐곱 줄만 찍혀 나간다.
        그래서 여기서는 그리기 나무를 손으로 세워 표 «전체»를 담는다. */
  Future<Uint8List?> _capture(Widget table) async {
    try {
      final boundary = RenderRepaintBoundary();
      final owner = PipelineOwner();
      final buildOwner = BuildOwner(focusManager: FocusManager());
      final root = RenderView(
        view: View.of(context),
        child: RenderPositionedBox(alignment: Alignment.topLeft, child: boundary),
        configuration: ViewConfiguration(
          logicalConstraints: const BoxConstraints(),
          devicePixelRatio: 3, // 폰에서 글자가 또렷하게
        ),
      );
      owner.rootNode = root;
      root.prepareInitialFrame();

      final element = RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Material(
              color: Colors.white,
              child: Padding(padding: const EdgeInsets.all(12), child: table),
            ),
          ),
        ),
      ).attachToRenderTree(buildOwner);

      buildOwner
        ..buildScope(element)
        ..finalizeTree();
      owner
        ..flushLayout()
        ..flushCompositingBits()
        ..flushPaint();

      final img = await boundary.toImage(pixelRatio: 3);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } catch (e) {
      debugPrint('표 그림 만들기 실패: $e');
      return null;
    }
  }
}

/// 회비 화면에서 이 표를 여는 길 — 회장·총무에게만 열린다.
Future<void> openFeeSheet(BuildContext context) async {
  if (!AppState.i.isTreasurer) {
    return toast(context, '회비 표는 회장·총무만 볼 수 있어요');
  }
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const FeeSheetScreen()),
  );
}
