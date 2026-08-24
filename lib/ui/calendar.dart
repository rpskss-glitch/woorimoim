import 'package:flutter/material.dart';

import '../logic.dart';
import '../state.dart';
import '../store.dart';
import 'common.dart';

const _repeatLabels = {
  'none': '반복 없음',
  'week': '매주',
  '2week': '2주마다',
  'month': '매달',
  'year': '매년',
};

/// 📅 일정 — 다가오는 모임과 지난 모임(출석 체크).
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});
  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  bool _showPast = false;
  /// 한 번에 보여줄 회차 수 — 말없이 자르지 않고 「더 보기」로 늘린다
  int _shown = 40;
  int _total = 0;

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

  /// 모든 모임을 회차로 펼쳐 날짜 순으로 늘어놓는다 (셈은 Logic 이 재어 둔다).
  List<({Map<String, dynamic> e, String date})> _rows({required bool past}) {
    final all = Logic.eventRows(past: past);
    _total = all.length; // 몇 개를 잘랐는지 알려주기 위해 전체 수를 기억한다
    return all.take(_shown).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows(past: _showPast);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: AppState.i.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: const Text('모임 만들기'),
            )
          : null,
      /* 화면에 보이는 것만 만든다.
         한꺼번에 다 만들면 「지난 모임」 40회차 × 회원 수만큼 칩이 한 번에 생겨
         회원이 많은 모임에서는 탭을 누르는 순간 화면이 멈칫한다. */
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: rows.length + 1 + (_total > rows.length ? 1 : 0),
        itemBuilder: (c, i) {
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('다가오는 모임')),
                    ButtonSegment(value: true, label: Text('지난 모임 · 출석')),
                  ],
                  selected: {_showPast},
                        onSelectionChanged: (s) => setState(() {
                    _showPast = s.first;
                    _shown = 40; // 탭을 바꾸면 처음부터
                  }),
                ),
                const SizedBox(height: 14),
                if (rows.isEmpty)
                  SectionCard(
                    child: Text(
                      _showPast ? '아직 지난 모임이 없어요' : '예정된 모임이 없어요',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ),
              ],
            );
          }
          if (i == rows.length + 1) {
            // 말없이 자르면 「지난 모임이 이것뿐인가?」로 오해한다 — 남은 수를 알리고 더 볼 수 있게
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton(
                onPressed: () => setState(() => _shown += 40),
                child: Text('이전 회차 ${_total - rows.length}개 더 보기'),
              ),
            );
          }
          final r = rows[i - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EventCard(
              event: r.e,
              date: r.date,
              past: _showPast,
              onChanged: _r,
              onEdit: () => _openForm(context, edit: r.e),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {Map<String, dynamic>? edit}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => _EventForm(edit: edit),
    );
    if (ok == true) _r();
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String date;
  final bool past;
  final VoidCallback onChanged;
  final VoidCallback onEdit;
  const _EventCard({
    required this.event,
    required this.date,
    required this.past,
    required this.onChanged,
    required this.onEdit,
  });

  Future<void> _vote(BuildContext context, String v) async {
    final code = AppState.i.code;
    if (code == null) return;
    final key = Logic.rkey(date, Store.i.myUid);
    // 트랜잭션은 서버에 닿아야만 된다 — 감싸지 않으면 실패했을 때 아무 말도 없이 끝난다
    var ok = false;
    try {
      ok = await Store.i.mutateItem(code, event['id'] as String, 'event', (cur) {
        final rsvp = Logic.asMap(cur['rsvp']);
        /* 폰을 바꾸기 «전» 번호로 찍은 표까지 함께 치운다 —
           안 그러면 껐는데 옛 표가 남아 **인원이 안 줄어든다.** */
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
    if (!ok) return toast(context, '투표를 저장하지 못했어요 — 다시 눌러주세요');
    onChanged();
  }

  Future<void> _toggleAttend(BuildContext context, String uid) async {
    final code = AppState.i.code;
    if (code == null) return;
    final key = Logic.rkey(date, uid);
    var ok = false;
    try {
      ok = await Store.i.mutateItem(code, event['id'] as String, 'event', (cur) {
        final att = Logic.asMap(cur['attend']);
        /* 끄는 쪽도 옛 번호를 이어야 한다 — 안 그러면 «출석 취소가 아예 안 된다»
           (옛 표시가 남아 배지·순위가 부풀려진 채 굳는다). */
        final his = Logic.markKeys(att, date, uid);
        final on = his.any((k) => att[k] == true);
        return {
          'attend': on ? {for (final k in his) k: Store.del} : {key: true}
        };
      });
    } catch (_) {
      ok = false;
    }
    if (!context.mounted) return;
    if (!ok) return toast(context, '출석을 저장하지 못했어요 — 다시 눌러주세요');
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final st = AppState.i;
    final cs = Theme.of(context).colorScheme;
    final my = Logic.myRsvp(event, date);
    final yes = Logic.rsvpCount(event, date, 'yes');
    final no = Logic.rsvpCount(event, date, 'no');
    final time = event['time'] as String?;
    final place = event['place'] as String?;
    final memo = event['memo'] as String?;
    final rep = (event['repeat'] as String?) ?? 'none';
    final attendN = st.memberList.where((m) => Logic.attended(event, date, m['uid'] as String)).length;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text((event['title'] as String?) ?? '모임',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (rep != 'none')
                Chip(
                  label: Text(_repeatLabels[rep] ?? rep, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
              if (st.isAdmin)
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') return onEdit();
                    if (v != 'del') return;
                    final ok = await confirmSheet(
                      context,
                      '이 모임을 지울까요?',
                      rep == 'none' ? '되돌릴 수 없어요' : '반복 모임 전체가 사라져요',
                      okLabel: '지우기',
                      danger: true,
                    );
                    if (!ok) return;
                    final code = AppState.i.code;
                    if (code == null) return;
                    final done =
                        await Store.i.deleteItem(code, event['id'] as String, 'event');
                    if (!context.mounted) return;
                    toast(context, done ? '모임을 지웠어요' : '지우지 못했어요 — 다시 시도해주세요');
                    if (done) onChanged();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('고치기')),
                    PopupMenuItem(value: 'del', child: Text('지우기')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${fmtDateFull(date)}${time == null || time.isEmpty ? '' : ' $time'}'
            '${place == null || place.isEmpty ? '' : ' · $place'}',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
          if (memo != null && memo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(memo, style: const TextStyle(height: 1.5)),
          ],
          const SizedBox(height: 12),
          if (!past)
            Row(
              children: [
                Expanded(
                  child: BusyButton(
                    onTap: () => _vote(context, 'yes'),
                    style: FilledButton.styleFrom(
                      backgroundColor: my == 'yes' ? cs.primary : null,
                      foregroundColor: my == 'yes' ? cs.onPrimary : null,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text('참석 $yes'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BusyButton(
                    onTap: () => _vote(context, 'no'),
                    style: FilledButton.styleFrom(
                      backgroundColor: my == 'no' ? Colors.grey.shade700 : null,
                      foregroundColor: my == 'no' ? Colors.white : null,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text('불참 $no'),
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Text('출석 $attendN명',
                    style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
                const Spacer(),
                if (st.isAdmin)
                  Text('이름을 눌러 출석 체크',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in st.memberList)
                  _AttendChip(
                    /* 🔑 «누구의» 칩인지 붙여 둔다 — 없으면 플러터가 «자리»로 짝짓는다.
                       도는 표시(_busy)는 칩이 들고 있는데, 누르는 «동안» 회원 목록이 바뀌면
                       (가입 승인·권한 바꿈·탈퇴로 차례가 달라진다) 그 표시가
                       **엉뚱한 사람에게 옮겨 붙어 그 사람 칩이 잠긴다.**
                       회차까지 넣는 것은, 같은 자리에 «다른 날 카드»가 와도 안 섞이게 하려는 것. */
                    key: ValueKey('${event['id']}|$date|${m['uid']}'),
                    uid: m['uid'] as String,
                    name: m['name'] as String? ?? '회원',
                    on: Logic.attended(event, date, m['uid'] as String),
                    onTap: st.isAdmin ? () => _toggleAttend(context, m['uid'] as String) : null,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendChip extends StatefulWidget {
  final String uid, name;
  final bool on;
  /// 눌렀을 때 «서버에 닿아야만» 되는 일 — 도는 동안 다시 눌리면 트랜잭션이 겹친다
  final Future<void> Function()? onTap;
  const _AttendChip(
      {super.key,
      required this.uid,
      required this.name,
      required this.on,
      this.onTap});

  @override
  State<_AttendChip> createState() => _AttendChipState();
}

class _AttendChipState extends State<_AttendChip> {
  bool _busy = false;

  Future<void> _run() async {
    final f = widget.onTap;
    if (_busy || f == null) return;
    setState(() => _busy = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final on = widget.on;
    return InkWell(
      onTap: widget.onTap == null || _busy ? null : _run,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: on ? cs.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: on ? cs.onPrimary : cs.primary),
                ),
              )
            else if (on)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.check, size: 14, color: cs.onPrimary),
              ),
            Text(widget.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: on ? cs.onPrimary : null,
                )),
          ],
        ),
      ),
    );
  }
}

/// 모임 만들기·고치기.
class _EventForm extends StatefulWidget {
  final Map<String, dynamic>? edit;
  const _EventForm({this.edit});
  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _memo = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay? _time;
  String _repeat = 'none';
  DateTime? _until;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _title.text = (e['title'] as String?) ?? '';
      _place.text = (e['place'] as String?) ?? '';
      _memo.text = (e['memo'] as String?) ?? '';
      _date = parseYmd(e['date'] as String?);
      _repeat = (e['repeat'] as String?) ?? 'none';
      // ⚠️ 이걸 안 불러오면, 고치기만 눌러도 정해둔 「끝나는 날」이 조용히 지워진다
      final u = e['until'] as String?;
      if (u != null && u.length >= 10) _until = DateTime.tryParse(u.substring(0, 10));
      final t = e['time'] as String?;
      if (t != null && t.contains(':')) {
        final p = t.split(':');
        _time = TimeOfDay(hour: int.tryParse(p[0]) ?? 19, minute: int.tryParse(p[1]) ?? 0);
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final title = _title.text.trim();
    if (title.isEmpty) return toast(context, '모임 이름을 적어주세요');
    final code = AppState.i.code;
    if (code == null) return;

    // 여기까지 와서도 앞뒤가 뒤집혀 있으면(옛 기록 등) 「계속」으로 본다 —
    // 회차가 0개인 모임은 화면에 아예 안 나와 손댈 수가 없다
    if (_until != null && _until!.isBefore(_date)) _until = null;

    final data = <String, dynamic>{
      'type': 'event',
      'title': title,
      'date': ymd(_date),
      'time': _time == null
          ? ''
          : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
      'place': _place.text.trim(),
      'memo': _memo.text.trim(),
      'repeat': _repeat,
      'until': _repeat == 'none' || _until == null ? null : ymd(_until!),
    };

    /* 출석·참석 투표는 「날짜_uid」로 적혀 있고, 목록·배지·순위는 «지금 회차 목록에 있는 날짜»만 센다.
       그래서 날짜뿐 아니라 **반복 주기·종료일만 바꿔도** 기록이 문서에 남은 채 화면에서 사라진다
       (매주 모임을 「반복 없음」으로 바꾸면 3년치 출석이 한 번에). 몇 건인지 세어서 미리 알린다. */
    final e = widget.edit;
    if (e != null) {
      final lost = Logic.recordsDropped(e, {...e, ...data});
      if (lost > 0) {
        final go = await confirmSheet(
          context,
          '출석·참석 기록 $lost건이 화면에서 사라져요',
          '이 모임의 회차가 달라져서, 그 날짜에 적힌 출석과 참석 투표가 어느 화면에도 '
              '안 나오게 됩니다 (배지와 순위에서도 빠져요). '
              '다시 원래대로 되돌리면 그대로 살아납니다. 그래도 고칠까요?',
          okLabel: '그래도 고치기',
          danger: true,
        );
        if (!go) return;
        if (!mounted) return;
      }
    }

    setState(() => _busy = true);

    try {
      if (widget.edit != null) {
        await Store.i.updateItem(code, widget.edit!['id'] as String, 'event', data);
      } else {
        // 만든 사람은 참석으로 시작
        data['rsvp'] = {Logic.rkey(ymd(_date), Store.i.myUid): 'yes'};
        final id = await Store.i.addItem(code, data);
        if (id == null) throw Exception('저장 실패');
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      toast(context, widget.edit != null ? '고쳤어요' : '모임을 만들었어요 📅');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      toast(context, '저장하지 못했어요 — 다시 시도해주세요');
    }
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
            Text(widget.edit != null ? '모임 고치기' : '모임 만들기',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              maxLength: 30,
              decoration: const InputDecoration(labelText: '모임 이름', counterText: ''),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate:
                            clampDate(_date, DateTime(2020), DateTime(2100)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d == null) return;
                      setState(() {
                        _date = d;
                        /* 시작 날을 «끝나는 날보다 뒤»로 옮기면 회차가 하나도 안 생겨
                           그 모임이 어느 목록에도 안 나온다 → 고칠 수도 지울 수도 없다.
                           그래서 끝나는 날을 「계속」으로 되돌린다 (끝나는 날 고르기도 시작 날부터만 고를 수 있다) */
                        if (_until != null && _until!.isBefore(_date)) _until = null;
                      });
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(ymd(_date)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: context, initialTime: _time ?? const TimeOfDay(hour: 19, minute: 0));
                      if (t != null) setState(() => _time = t);
                    },
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(_time == null
                        ? '시간'
                        : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _place,
              maxLength: 30,
              decoration: const InputDecoration(labelText: '장소', counterText: ''),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('반복', style: TextStyle(color: Theme.of(context).hintColor)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final e in _repeatLabels.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _repeat == e.key,
                    onSelected: (_) => setState(() => _repeat = e.key),
                  ),
              ],
            ),
            if (Logic.clampNote(_repeat, _date) != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '📌 ${Logic.clampNote(_repeat, _date)}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
              ),
            if (_repeat != 'none') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: clampDate(
                              _until ?? _date.add(const Duration(days: 180)),
                              _date,
                              DateTime(2100)),
                          firstDate: _date,
                          lastDate: DateTime(2100),
                          helpText: '언제까지 반복할까요?',
                        );
                        if (d != null) setState(() => _until = d);
                      },
                      icon: const Icon(Icons.event_repeat, size: 18),
                      label: Text(_until == null ? '끝나는 날 (안 정하면 계속)' : '${ymd(_until!)}까지'),
                    ),
                  ),
                  // 한 번 정한 끝나는 날을 다시 「계속」으로 되돌릴 길이 있어야 한다
                  if (_until != null)
                    IconButton(
                      tooltip: '끝나는 날 지우기',
                      onPressed: () => setState(() => _until = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _memo,
              maxLines: 3,
              // 이 모임 카드는 회원 전원의 화면에 뜬다 — 다른 칸처럼 길이를 막아 둔다
              maxLength: 500,
              decoration: const InputDecoration(labelText: '메모 (준비물 등)'),
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
