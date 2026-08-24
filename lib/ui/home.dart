import 'package:flutter/material.dart';

import '../config.dart';
import '../logic.dart';
import '../push.dart';
import '../state.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';

/// 🏠 홈 — 오늘 필요한 것만 위에서부터.
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
     이 함수는 «오래 걸리는 일이 끝난 뒤»(사진 지우기·기록 지우기) 자식 화면이 불러 주는데,
     그 사이 모임에서 빠지거나 방이 없어져 화면이 사라졌을 수 있다.
     없어진 화면을 고치려 하면 Flutter 가 터진다(분석기는 setState 를 안 본다 — 183회차). */
  void _r() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final st = AppState.i;
    final cs = Theme.of(context).colorScheme;
    final next = Logic.nextEvent();
    final myAttend = Logic.attendStats()[Store.i.myUid] ?? 0;
    final rank = Logic.monthRank();
    final badges = Logic.badgesOf(myAttend);
    final nextBadge = Logic.nextBadge(myAttend);
    final unpaid = Logic.unpaidMonths(Store.i.myUid);
    final prepaid = Logic.prepaidLeft(Store.i.myUid);
    final feeAmount = ((st.couple?['fee'] as Map?)?['amount'] as num?)?.toInt() ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // 모임 상징 + 이름
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            child: Column(
              children: [
                const Emblem(basePx: emblemBasePx, capScale: 2),
                const SizedBox(height: 10),
                Text(
                  (st.couple?['title'] as String?) ?? Cfg.appName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text('회원 ${st.memberList.length}명',
                    style: TextStyle(color: Theme.of(context).hintColor)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 다음 모임 + 참석 투표
        if (next != null) ...[
          SectionCard(
            title: '📅 다가오는 모임',
            child: _NextEventCard(event: next.event, date: next.date, onChanged: _r),
          ),
          const SizedBox(height: 12),
        ],

        // 내 회비 상태 — 일반 회원은 자기 것만 본다.
        // 회비를 안 걷는 모임에서는 아예 안 보여준다 (안 그러면 "회비 깨끗해요"가 떠서 헷갈린다)
        if (feeAmount > 0) ...[
        SectionCard(
          title: '💰 내 회비',
          trailing: Text(
            unpaid.isEmpty
                ? '깨끗해요'
                : '${unpaid.length}달${Logic.unpaidTruncated(Store.i.myUid) ? ' 이상' : ''} 밀림',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: unpaid.isEmpty ? cs.primary : moneyOut(context),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (unpaid.isEmpty)
                Text(
                  prepaid > 0
                      ? '밀린 회비가 없어요. 앞으로 $prepaid달치가 미리 채워져 있어요 👍'
                      : '밀린 회비가 없어요 👍',
                  style: const TextStyle(height: 1.5),
                )
              else
                Text('아직 안 낸 달: ${unpaid.join(', ')}',
                    style: const TextStyle(height: 1.5)),
              if (!st.isTreasurer) ...[
                const SizedBox(height: 6),
                Text('입금은 총무님께 하시면 총무님이 기록해요',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        ],

        // 내 출석과 배지
        SectionCard(
          title: '✅ 내 출석',
          trailing: Text('$myAttend번',
              style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final b in badges)
                    Chip(
                      label: Text('${b.$2} ${b.$3}'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (badges.isEmpty)
                    Text('아직 배지가 없어요 — 첫 출석이 첫 배지예요',
                        style: TextStyle(color: Theme.of(context).hintColor)),
                ],
              ),
              if (nextBadge != null) ...[
                const SizedBox(height: 8),
                Text(
                    '다음 배지 ${nextBadge.$2} ${nextBadge.$3}까지 ${nextBadge.$1 - myAttend}번 남았어요',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 이번 달 출석 순위
        if (rank.isNotEmpty) ...[
          SectionCard(
            title: '🏅 이번 달 출석 순위',
            child: Column(
              children: [
                for (final e in rank.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Avatar(e.key, size: 30),
                        const SizedBox(width: 10),
                        Expanded(child: Text(st.nameOf(e.key))),
                        Text('${e.value}번',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 알림 권유 — 아직 안 켰을 때만
        /* 「기록이 있는지」가 아니라 «토큰이 있는지»를 본다 —
           설정에서 범위만 골라 두면 기록은 생기지만 토큰은 없을 수 있고,
           그때 이 카드가 사라져 회원은 켠 줄 알고 한 통도 못 받는다. */
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
                    toast(context, ok ? '알림을 켰어요 🔔' : '알림 권한을 허용해야 받을 수 있어요');
                  },
                  child: const Text('알림 켜기'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 다음 모임 한 장 — 참석 투표를 여기서 바로.
class _NextEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String date;
  final VoidCallback onChanged;
  const _NextEventCard({required this.event, required this.date, required this.onChanged});

  Future<void> _vote(BuildContext context, String v) async {
    final code = AppState.i.code;
    if (code == null) return;
    final key = Logic.rkey(date, Store.i.myUid);
    /* 투표는 반드시 트랜잭션으로 — 통째로 덮어쓰면 그 사이 남이 한 투표가 사라진다.
       ⚠️ 트랜잭션은 **서버에 닿아야만** 된다(연결이 끊기면 실패한다).
       감싸지 않으면 그때 아무 말도 없이 끝나 «눌렀는데 아무 일도 안 일어나는» 단추가 된다. */
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final my = Logic.myRsvp(event, date);
    final yes = Logic.rsvpCount(event, date, 'yes');
    final no = Logic.rsvpCount(event, date, 'no');
    final time = event['time'] as String?;
    final place = event['place'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (event['title'] as String?) ?? '모임',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${fmtDateFull(date)}${time == null || time.isEmpty ? '' : ' $time'}'
          '${place == null || place.isEmpty ? '' : ' · $place'}',
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: BusyButton(
                onTap: () => _vote(context, 'yes'),
                style: FilledButton.styleFrom(
                  backgroundColor: my == 'yes' ? cs.primary : null,
                  foregroundColor: my == 'yes' ? cs.onPrimary : null,
                  minimumSize: const Size.fromHeight(46),
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
                  minimumSize: const Size.fromHeight(46),
                ),
                child: Text('불참 $no'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
