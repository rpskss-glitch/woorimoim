import 'package:flutter/material.dart';

import '../config.dart';
import '../logic.dart';
import '../state.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';

/// 👥 회원 — 승인 대기, 회원 목록, 직책·권한, 탈퇴 처리.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});
  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  @override
  void initState() {
    super.initState();
    AppState.i.addListener(_r);
    _sweepOwnerSeat();
  }

  @override
  void dispose() {
    AppState.i.removeListener(_r);
    super.dispose();
  }

  void _r() {
    if (mounted) setState(() {});
  }

  Future<void> _approve(Map<String, dynamic> p) async {
    final st = AppState.i;
    final uid = p['uid'] as String;
    // 같은 이름은 허용하되, 아바타까지 똑같으면 서로 구분이 안 되니 승인하지 않는다
    final clash = st.memberList.any((m) =>
        Store.normTitle(m['name'] as String?) == Store.normTitle(p['name'] as String?) &&
        m['photo'] == null &&
        ((m['emoji'] as String?) ?? defaultAvatar) == ((p['emoji'] as String?) ?? defaultAvatar));
    if (clash) {
      return toast(context, '같은 이름·같은 아바타의 회원이 있어요 — 거절하고 다른 아바타로 다시 신청받아주세요');
    }
    final code = st.code;
    if (code == null) return;
    try {
      await Store.i.patchCouple(code, {
        'members.$uid': {
          'name': p['name'] ?? '회원',
          'emoji': p['emoji'] ?? defaultAvatar,
          'uid': uid,
          'birth': p['birth'] ?? '', // 생년월일도 옮겨야 폰 바꿀 때 자동 이어받기가 된다
          'role': 'member',
          'joinedAt': DateTime.now().millisecondsSinceEpoch,
        },
        'pending.$uid': null,
        'former.$uid': null, // 재가입이면 탈퇴 기록은 지운다
      });
      if (!mounted) return;
      toast(context, '${p['name'] ?? '회원'}님을 승인했어요 🎉');
    } catch (_) {
      if (!mounted) return;
      toast(context, '승인하지 못했어요 — 다시 눌러주세요');
    }
  }

  Future<void> _reject(Map<String, dynamic> p) async {
    final ok = await confirmSheet(
        context, '${p['name'] ?? '이 신청'}을 거절할까요?', '거절해도 다시 신청할 수 있어요',
        okLabel: '거절');
    if (!ok) return;
    final code = AppState.i.code;
    if (code == null) return; // 묻는 사이에 모임에서 빠졌을 수 있다
    try {
      await Store.i.patchCouple(code, {'pending.${p['uid']}': null});
      if (!mounted) return;
      toast(context, '신청을 거절했어요');
    } catch (_) {
      if (!mounted) return;
      toast(context, '처리하지 못했어요 — 다시 눌러주세요');
    }
  }

  Future<void> _kick(Map<String, dynamic> m) async {
    final name = m['name'] as String? ?? '회원';
    final ok = await confirmSheet(
      context,
      '$name님을 탈퇴 처리할까요?',
      '바로 앱을 쓸 수 없게 되고, 남긴 글·기록은 그대로 남아요. 다시 신청하면 재승인할 수 있어요.',
      okLabel: '탈퇴 처리',
      danger: true,
    );
    if (!ok) return;
    final uid = m['uid'] as String;
    final code = AppState.i.code;
    if (code == null) return;
    try {
      await Store.i.patchCouple(code, {
        'members.$uid': null,
        'push.$uid': null,
        'former.$uid': {
          'uid': uid,
          'name': name,
          'emoji': m['emoji'] ?? defaultAvatar,
          'leftAt': DateTime.now().millisecondsSinceEpoch,
        },
      });
      // 탈퇴 기록(former)에는 사진을 안 남기므로, 그 사람 아바타 원본은 아무도 못 찾는다 → 치운다
      Store.i.dropPhotos([m['photo'] as String?]);
      if (!mounted) return;
      toast(context, '$name님을 탈퇴 처리했어요');
    } catch (_) {
      if (!mounted) return;
      toast(context, '처리하지 못했어요 — 다시 눌러주세요');
    }
  }

  Future<void> _setTitle(Map<String, dynamic> m) async {
    final uid = m['uid'] as String;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      /* ⚠️ 직책은 «몇 개일지 정해져 있지 않다» — 미리 넣어둔 12개에 더해
         방장이 직접 적은 직책이 쓰이는 만큼 늘어난다(`Logic.allTitles`).
         그냥 쌓아 두면 화면을 넘겨 **아래쪽 직책을 아예 못 고른다**
         (2026-08-22 실측: 직접 입력 18개가 쌓이면 **보통 글자에서도 198px**,
          글자 1.6배면 800px 넘침). 그래서 넘치면 밀어 볼 수 있게 한다. */
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
          child: SingleChildScrollView(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${m['name']}님의 직책',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('직책은 권한과 별개예요. 운영진 권한은 아래에서 따로 줍니다.',
                  style: TextStyle(fontSize: 12, color: Theme.of(c).hintColor)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in Logic.allTitles())
                    ActionChip(label: Text(t), onPressed: () => Navigator.pop(c, t)),
                  /* ✏️ 미리 넣어둔 12개에 없는 직책 — 모임마다 부르는 이름이 다르다
                     (「총무님」·「살림이」·「기획」…). 직접 적을 길이 없으면
                     방장은 비슷한 것을 골라 두고 실제와 다르게 쓴다. */
                  ActionChip(
                    avatar: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('직접 입력'),
                    onPressed: () async {
                      final t = await askText(c,
                          title: '직책 직접 입력',
                          hint: '예) 기획이사',
                          helper: '회장·총무로 적으면 운영진 권한도 함께 붙어요',
                          maxLength: 10,
                          okLabel: '정하기');
                      final v = (t ?? '').trim();
                      if (v.isEmpty || !c.mounted) return;
                      Navigator.pop(c, v);
                    },
                  ),
                  ActionChip(
                    label: const Text('직책 없음'),
                    onPressed: () => Navigator.pop(c, ''),
                  ),
                ],
              ),
            ],
          ),
            ),
          ),
        ),
      ),
    );
    if (picked == null) return;
    final code = AppState.i.code;
    if (code == null) return;
    /* ⚠️ 쓰기가 «둘»일 수 있다 — 직책 먼저, 그다음 「권한도 드릴까요?」.
       앞이 됐는데 뒤가 실패했을 때 「저장하지 못했어요」라고만 하면 **거짓말이다.**
       직책은 이미 붙어서 «회비 장부가 열렸는데» 방장은 아무 일도 없었다고 믿는다. */
    var titleDone = false;
    try {
      await Store.i.patchCouple(code, {
        'members.$uid.title': picked.isEmpty ? null : picked,
      });
      titleDone = true;
      if (!mounted) return;
      var nowStaff = m['role'] != 'member';
      /* 👑 **회장·총무는 묻지 않고 바로 운영진.**
         이 둘은 모임을 실제로 굴리는 자리라, 권한 없이 직책만 주면
         회원 승인도 일정 관리도 못 해 «이름뿐인 직책»이 된다.
         방장이 매번 「네」를 눌러야 했는데, 안 누르면 그 사실을 아무도 모른 채
         그 사람만 아무것도 못 하고 있었다. (2026-08-30 사장님 결정)
         ⚠️ 나머지 직책(부회장·경기이사 등)은 **지금처럼 물어본다** — 모임마다 다르다. */
      if (picked.isNotEmpty && m['role'] == 'member') {
        if (autoStaffTitles.contains(picked)) {
          await Store.i.patchCouple(code, {'members.$uid.role': 'admin'});
          nowStaff = true;
          if (mounted) toast(context, '$picked 이라 운영진 권한도 함께 드렸어요');
        } else if (adminTitles.contains(picked)) {
          final give = await confirmSheet(
            context,
            '$picked 직책이네요',
            '운영진 권한(회원 승인·일정 관리)도 같이 드릴까요?',
            okLabel: '권한도 주기',
          );
          if (give) {
            await Store.i.patchCouple(code, {'members.$uid.role': 'admin'});
            nowStaff = true;
          }
        }
      }
      if (!mounted) return;
      /* 💰 이 직책은 **권한과 상관없이** 회비 장부를 연다 — 방장이 모르고 주면 안 된다.
         ⚠️ 권한을 «내릴» 때는 이미 알려 주고 있었다(「직책이 있으면 권한과 상관없이 …」).
            **주는 쪽만 아무 말이 없어 짝이 안 맞았다.**
            게다가 「총무보·회계」는 위의 「권한도 드릴까요?」조차 안 묻는 직책이라
            (adminTitles 에 없다) 방장은 회비 장부를 넘겼다는 사실을 알 길이 아예 없었다.
         이미 방장·운영진이면 권한으로도 열리니 새삼 알릴 것이 없다. */
      final opensMoney = !nowStaff && Logic.keepsMoneyByTitle(picked);
      toast(
          context,
          picked.isEmpty
              ? '직책을 지웠어요'
              : opensMoney
                  ? '$picked(으)로 정했어요 — 이 직책은 회비 장부를 쓰고 고칠 수 있어요'
                  : '$picked(으)로 정했어요');
    } catch (_) {
      if (!mounted) return;
      toast(
          context,
          titleDone
              ? '직책은 「$picked」(으)로 정해졌는데 운영진 권한은 주지 못했어요 — '
                  '권한은 다시 눌러주세요 (이 직책만으로도 회비 장부는 열려요)'
              : '저장하지 못했어요 — 다시 눌러주세요');
    }
  }

  Future<void> _setRole(Map<String, dynamic> m, String role) async {
    final uid = m['uid'] as String;
    final code = AppState.i.code;
    if (code == null) return;
    final title = m['title'] as String?;
    /* ⚠️ 여기도 쓰기가 «둘»일 수 있다 — 권한 먼저, 그다음 「직책도 뗄까요?」.
       뒤가 실패했는데 「저장하지 못했어요」라고만 하면 방장은 아무 일도 없었다고 믿는다.
       실제로는 **권한은 내려갔는데 직책이 남아 회비 장부는 그대로 열려 있다** —
       바로 아래 주석이 막으려던 그 상황이 이 catch 로 그대로 새던 셈이다. */
    var roleDone = false;
    try {
      await Store.i.patchCouple(code, {'members.$uid.role': role});
      roleDone = true;
      if (!mounted) return;
      /* ⚠️ 권한을 내려도 «직책»은 그대로 남는데, 서버는 직책만 보고도 회비 장부를 열어 준다.
         올릴 때는 「권한도 같이 드릴까요?」를 묻고 있으니 내릴 때도 짝을 맞춘다.
         안 그러면 방장은 뗐다고 믿는데 그 사람은 회비를 계속 쓰고 고칠 수 있다. */
      if (role == 'member' && Logic.keepsMoneyByTitle(title)) {
        final drop = await confirmSheet(
          context,
          '「$title」 직책은 아직 남아 있어요',
          '$title 직책이 있으면 권한과 상관없이 회비 장부를 쓰고 고칠 수 있어요. 직책도 같이 뗄까요?',
          okLabel: '직책도 떼기',
        );
        if (!mounted) return;
        if (drop) {
          await Store.i.patchCouple(code, {'members.$uid.title': null});
          if (!mounted) return;
          return toast(context, '일반 회원으로 바꾸고 「$title」 직책도 뗐어요');
        }
        return toast(context, '일반 회원으로 바꿨어요 — 「$title」 직책이 남아 회비는 그대로 다룰 수 있어요');
      }
      toast(context, role == 'admin' ? '운영진으로 올렸어요' : '일반 회원으로 바꿨어요');
    } catch (_) {
      if (!mounted) return;
      toast(
          context,
          roleDone
              ? '권한은 내렸는데 「$title」 직책을 떼지 못했어요 — '
                  '직책이 남아 있으면 회비 장부를 그대로 쓸 수 있어요. 다시 눌러주세요'
              : '저장하지 못했어요 — 다시 눌러주세요');
    }
  }

  /// 👑 방장 넘기기 — 넘긴 사람은 운영진으로 내려온다.
  Future<void> _handOver(Map<String, dynamic> m) async {
    final name = m['name'] as String? ?? '회원';
    final ok = await confirmSheet(
      context,
      '$name님에게 방장을 넘길까요?',
      '넘기면 사장님은 운영진이 되고, 되돌리려면 새 방장이 다시 넘겨줘야 해요',
      okLabel: '방장 넘기기',
      danger: true,
    );
    if (!ok) return;
    final me = Store.i.myUid;
    final to = m['uid'] as String;
    final code = AppState.i.code;
    if (code == null) return;
    var done = false;
    try {
      done = await Store.i.mutateCouple(code, (cur) {
        final members = (cur['members'] as Map?)?.cast<String, dynamic>() ?? {};
        if (members[to] == null) return null;
        return {
          'members': {
            me: {'role': 'admin'},
            to: {'role': 'owner'},
          }
        };
      });
    } catch (_) {
      done = false;
    }
    if (!mounted) return;
    toast(context, done ? '$name님이 새 방장이 되었어요 👑' : '넘기지 못했어요 — 다시 시도해주세요');
  }

  /// 방장이 없는 방에서 회원이 스스로 방장을 맡는다 (총괄이 자리를 비웠을 때).
  Future<void> _claimOwner() async {
    final ok = await confirmSheet(
      context,
      '내가 방장을 맡을까요?',
      '지금 이 모임에는 방장이 없어요. 맡으면 회원 승인·일정·설정을 관리하게 됩니다.',
      okLabel: '방장 맡기',
    );
    if (!ok) return;
    final code = AppState.i.code;
    if (code == null) return;
    var done = false;
    try {
      done = await Store.i.mutateCouple(code, (cur) {
        final members = (cur['members'] as Map?)?.cast<String, dynamic>() ?? {};
        final hasOwner = members.values.whereType<Map>().any((m) => m['role'] == 'owner');
        if (hasOwner) return null; // 그 사이 누가 먼저 맡음
        return {
          'members': {
            Store.i.myUid: {'role': 'owner'}
          }
        };
      });
    } catch (_) {
      done = false;
    }
    if (done) {
      /* 🔒 「자리가 비었다」는 표시(ownerReleased)를 **반드시 지운다.**
         서버 규칙은 그 표시가 있는 동안 «회원이 스스로 방장이 되는 것»을 허용한다.
         안 지우면 새 방장이 앉은 뒤에도 그 문이 영영 열려 있어,
         아무 회원이나 언제든 방장 자리를 가로챌 수 있다.

         한 번에 같이 못 지운다 — 맡는 순간에는 아직 평회원이라
         규칙이 「제 칸만」으로 좁혀 놓기 때문이다. 맡고 «난 뒤»에 방장 자격으로 지운다. */
      try {
        await Store.i.patchCouple(code, {'ownerReleased': null});
      } catch (_) {
        // 못 지웠으면 다음에 이 화면을 열 때 다시 지운다 (_sweepOwnerSeat)
      }
    }
    if (!mounted) return;
    toast(context, done ? '이제 사장님이 방장이에요 👑' : '맡지 못했어요 — 다시 눌러주세요');
  }

  /// 방장인데 「자리가 비었다」는 표시가 남아 있으면 지운다.
  /// (맡을 때 지우기에 실패했거나, 총괄이 비운 뒤 예전 방장이 그대로 돌아온 경우)
  Future<void> _sweepOwnerSeat() async {
    final st = AppState.i;
    final code = st.code;
    if (code == null || !st.isOwner) return;
    if (!(st.couple?.containsKey('ownerReleased') ?? false)) return;
    try {
      await Store.i.patchCouple(code, {'ownerReleased': null});
    } catch (_) {/* 다음에 다시 */}
  }

  @override
  Widget build(BuildContext context) {
    final st = AppState.i;
    final pending = Logic.pendingList(); // 먼저 신청한 사람이 위
    final hasOwner = st.memberList.any((m) => m['role'] == 'owner');
    final canClaim = Logic.canClaimOwner(st.couple, Store.i.myUid);
    final stats = Logic.attendStats();

    return Scaffold(
      appBar: AppBar(title: Text('회원 ${st.memberList.length}명')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (!hasOwner && st.approved) ...[
            SectionCard(
              title: '👑 방장이 없어요',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  /* 서버는 «자리가 열려 있을 때»만(총괄이 열어 둔 방) 스스로 방장이 되게 한다.
                     그걸 안 보고 단추부터 띄우면 눌러도 거절당해, 회원은 몇 번을 눌러도
                     「맡지 못했어요」만 보는 **죽은 단추**가 된다. 열려 있지 않으면 «무엇을 해야 하는지»를 알려준다. */
                  Text(
                      canClaim
                          ? '이 모임에는 지금 방장이 없습니다. 맡아주실 분이 눌러주세요.'
                          : '이 모임에는 지금 방장이 없습니다. 총괄 관리자에게 「방장 자리 열기」를 부탁하시면 '
                              '여기서 바로 맡으실 수 있어요.',
                      style: TextStyle(color: Theme.of(context).hintColor, height: 1.5)),
                  if (canClaim) ...[
                    const SizedBox(height: 10),
                    FilledButton.tonal(
                        onPressed: _claimOwner, child: const Text('내가 방장 맡기')),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (st.isAdmin && pending.isNotEmpty) ...[
            SectionCard(
              title: '⏳ 승인 대기 ${pending.length}명',
              child: Column(
                children: [
                  for (final p in pending)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Avatar(null, size: 34, emojiOverride: p['emoji'] as String?),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['name'] as String? ?? '회원',
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  [
                                    if ((p['birth'] as String?)?.isNotEmpty == true)
                                      '생년월일 ${p['birth']}',
                                    // 오래 기다린 사람이 눈에 띄게 — 「며칠」은 날짜로 센다
                                    ?Logic.waitedFor(p['requestedAt'], DateTime.now()),
                                  ].join(' · '),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).hintColor),
                                ),
                              ],
                            ),
                          ),
                          TextButton(onPressed: () => _reject(p), child: const Text('거절')),
                          const SizedBox(width: 4),
                          FilledButton(
                            onPressed: () => _approve(p),
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(64, 38), visualDensity: VisualDensity.compact),
                            child: const Text('승인'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SectionCard(
            title: '회원',
            child: Column(
              children: [
                for (final m in st.memberList)
                  _MemberRow(
                    member: m,
                    attendCount: stats[m['uid']] ?? 0,
                    onTitle: st.isOwner ? () => _setTitle(m) : null,
                    onRole: st.isOwner && m['role'] != 'owner'
                        ? () => _setRole(m, m['role'] == 'admin' ? 'member' : 'admin')
                        : null,
                    // 탈퇴 처리 경계: 방장은 방장 아닌 누구나, 운영진은 **일반 회원만**.
                    // (운영진이 서로를 자를 수 있으면 운영진끼리 다투다 방이 무너진다)
                    onKick: m['uid'] != Store.i.myUid &&
                            m['role'] != 'owner' &&
                            (st.isOwner || (st.isAdmin && m['role'] == 'member'))
                        ? () => _kick(m)
                        : null,
                    onHandOver:
                        st.isOwner && m['uid'] != Store.i.myUid ? () => _handOver(m) : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final Map<String, dynamic> member;
  final int attendCount;
  final VoidCallback? onTitle, onRole, onKick, onHandOver;
  const _MemberRow({
    required this.member,
    required this.attendCount,
    this.onTitle,
    this.onRole,
    this.onKick,
    this.onHandOver,
  });

  @override
  Widget build(BuildContext context) {
    final role = member['role'] as String?;
    final title = member['title'] as String?;
    final cs = Theme.of(context).colorScheme;
    final canMenu = onTitle != null || onRole != null || onKick != null || onHandOver != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Avatar(member['uid'] as String?, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(member['name'] as String? ?? '회원',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (role == 'owner') const Text(' 👑', style: TextStyle(fontSize: 13)),
                    /* ⚠️ 직책 딱지도 «자리를 나눠 갖게» 한다.
                       이름은 이미 줄어들지만(ellipsis), 딱지가 자리를 안 양보하면
                       딱지째로 오른쪽으로 밀려 나간다 — 「경기이사 겸 총무보조」처럼
                       긴 직책은 동호회에 흔하다. 2026-08-29 실측: 회원 40명·긴 이름·
                       좁은 폰(360px)·글자 2배에서 117픽셀 넘쳤다. */
                    if (title != null && title.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: .55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${role == 'owner' ? '방장' : role == 'admin' ? '운영진' : '회원'} · 출석 $attendCount번',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          if (canMenu)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'title') onTitle?.call();
                if (v == 'role') onRole?.call();
                if (v == 'kick') onKick?.call();
                if (v == 'owner') onHandOver?.call();
              },
              itemBuilder: (_) => [
                if (onTitle != null) const PopupMenuItem(value: 'title', child: Text('직책 정하기')),
                if (onRole != null)
                  PopupMenuItem(
                      value: 'role',
                      child: Text(member['role'] == 'admin' ? '운영진 해제' : '운영진으로')),
                if (onHandOver != null)
                  const PopupMenuItem(value: 'owner', child: Text('👑 방장 넘기기')),
                if (onKick != null)
                  PopupMenuItem(
                      value: 'kick',
                      child: Text('탈퇴 처리', style: TextStyle(color: dangerText(context)))),
              ],
            ),
        ],
      ),
    );
  }
}
