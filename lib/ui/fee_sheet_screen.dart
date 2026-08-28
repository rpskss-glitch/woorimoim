import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../fee_sheet.dart';
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
  int _tab = 0; // 0=회비 1=지출
  bool _busy = false;

  static const _headStyle = TextStyle(fontWeight: FontWeight.w700, fontSize: 13);
  static const _cellStyle = TextStyle(fontSize: 13);
  static const _headBg = Color(0xFFD8D2EC); // 종이 표와 같은 연보라 머리글
  static const _altBg = Color(0xFFF1EEF9);
  static const _lineColor = Color(0xFFBFC7D2);

  @override
  Widget build(BuildContext context) {
    final months = FeeSheet.monthKeys(_months);
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? '회비 납부 현황' : '지출 내역'),
        actions: [
          PopupMenuButton<int>(
            tooltip: '몇 달치를 볼지',
            initialValue: _months,
            onSelected: (v) => setState(() => _months = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 3, child: Text('최근 3개월')),
              PopupMenuItem(value: 6, child: Text('최근 6개월')),
              PopupMenuItem(value: 12, child: Text('최근 12개월')),
            ],
            icon: const Icon(Icons.date_range),
          ),
        ],
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
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
              // ⚠️ 표는 옆으로도 넘친다 — 가로 스크롤이 없으면 달이 많을 때 잘려 보인다
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _tab == 0 ? _feeTable(months) : _outTable(months),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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

  Widget _feeTable(List<String> months) {
    final members = AppState.i.memberList;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _box(const Text('회원명', style: _headStyle), w: 96, bg: _headBg),
          for (final m in months)
            _box(Text(FeeSheet.monthLabel(m), style: _headStyle), bg: _headBg),
        ]),
        for (var i = 0; i < members.length; i++)
          Row(children: [
            _box(
              Text('${i + 1}. ${members[i]['name'] ?? '회원'}',
                  style: _cellStyle, overflow: TextOverflow.ellipsis),
              w: 96,
              bg: i.isEven ? _altBg : null,
              align: Alignment.centerLeft,
            ),
            for (final m in months)
              _box(
                Text(FeeSheet.cell(FeeSheet.mark(members[i]['uid'] as String, m)),
                    style: _cellStyle),
                bg: i.isEven ? _altBg : null,
              ),
          ]),
        // 합계 줄 — 「이번 달 몇 명이 냈는지」가 총무가 가장 자주 보는 값이다
        Row(children: [
          _box(const Text('납부', style: _headStyle), w: 96, bg: _headBg),
          for (final m in months)
            _box(Text('${FeeSheet.paidCount(members, m)}', style: _headStyle), bg: _headBg),
        ]),
      ],
    );
  }

  /// 만 원 단위로 짧게 — 표 칸에 원 단위를 다 적으면 가로가 두 배가 된다
  static String _won(int v) =>
      v == 0 ? '' : '${(v / 10000).toStringAsFixed(v % 10000 == 0 ? 0 : 1)}만';

  Widget _outTable(List<String> months) {
    final table = FeeSheet.outByCat(months);
    final cats = table.keys.toList()..sort();
    if (cats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('이 기간에 지출 기록이 없어요',
            style: TextStyle(color: Theme.of(context).hintColor)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _box(const Text('갈래', style: _headStyle), w: 96, bg: _headBg),
          for (final m in months)
            _box(Text(FeeSheet.monthLabel(m), style: _headStyle), w: 60, bg: _headBg),
        ]),
        for (var i = 0; i < cats.length; i++)
          Row(children: [
            _box(Text(cats[i], style: _cellStyle),
                w: 96, bg: i.isEven ? _altBg : null, align: Alignment.centerLeft),
            for (final m in months)
              _box(Text(_won(table[cats[i]]?[m] ?? 0), style: _cellStyle),
                  w: 60, bg: i.isEven ? _altBg : null),
          ]),
        Row(children: [
          _box(const Text('합계', style: _headStyle), w: 96, bg: _headBg),
          for (final m in months)
            _box(
              Text(_won(cats.fold<int>(0, (a, c) => a + (table[c]?[m] ?? 0))),
                  style: _headStyle),
              w: 60,
              bg: _headBg,
            ),
        ]),
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
      final bytes = await _capture(_tab == 0 ? _feeTable(months) : _outTable(months));
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
        if (mounted) toast(context, '대화방에 올리지 못했어요 — 다시 해주세요');
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
