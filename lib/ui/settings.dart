import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../logic.dart';
import '../moderation.dart';
import '../push.dart';
import '../state.dart';
import '../store.dart';
import '../theme.dart';
import 'admin.dart';
import 'common.dart';
import 'owner_guide.dart';

/// ⚙️ 설정 — 내 정보, 모임 설정(방장), 알림, 꾸미기.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _versionTaps = 0;
  bool _retryBusy = false;

  /// 「다시 지워보기」 — 포기함에 있는 원본을 한 번 더 지워 본다.
  /// 누른 사람이 결과를 알아야 하므로 **몇 개가 남았는지**까지 말해 준다.
  Future<void> _retryLost() async {
    setState(() => _retryBusy = true);
    var n = 0;
    try {
      n = await Store.i.retryLost();
    } catch (e) {
      // 여기서 터져도 단추가 영영 잠기면 안 된다 — finally 에서 반드시 푼다
      debugPrint('다시 지워보기 실패: $e');
    } finally {
      if (mounted) setState(() => _retryBusy = false);
    }
    if (!mounted) return;
    final left = Store.i.lostCount();
    toast(
        context,
        left == 0
            ? '$n개를 모두 지웠어요 ✨'
            : '$n개를 다시 시도했는데 $left개는 아직 안 지워졌어요 — 나중에 다시 눌러주세요');
  }

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

  void _r() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final st = AppState.i;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          SectionCard(
            title: '🙋 내 정보',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(Store.i.myUid, size: 44),
                  title: Text(st.me?['name'] as String? ?? '나'),
                  subtitle: Text(
                    '${(st.me?['birth'] as String?)?.isNotEmpty == true ? '생년월일 ${st.me!['birth']}' : '생년월일 없음'}'
                    '${(st.me?['title'] as String?)?.isNotEmpty == true ? ' · ${st.me!['title']}' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _editMe,
                ),
                Text(
                  '생년월일을 적어두면 폰을 바꿔도 이름+생년월일로 바로 이어받을 수 있어요',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SectionCard(
            title: '🔔 알림',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  children: [
                    for (final m in Push.modes)
                      ChoiceChip(
                        label: Text(m[1]),
                        // 토큰이 없으면 「모두 받기」·「공지만」은 사실이 아니다 — 고른 것으로 보이면 안 된다
                        selected: Push.i.mode == m[0] &&
                            (m[0] == 'off' || Push.i.ready),
                        onSelected: (_) async {
                          if (m[0] != 'off') {
                            final ok = await Push.i.setup();
                            if (!ok && context.mounted) {
                              toast(context, Push.i.offReason(false));
                              return;
                            }
                          }
                          final saved = await Push.i.setMode(m[0]);
                          if (!context.mounted) return;
                          if (!saved) {
                            return toast(context, '알림 설정을 바꾸지 못했어요 — 잠시 후 다시 눌러주세요');
                          }
                          _r();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  !Push.i.ready && Push.i.mode != 'off'
                      ? '이 폰은 아직 알림을 켜지 않았어요 — 「모두 받기」나 「공지만」을 눌러주세요'
                      : Push.modes
                          .firstWhere((m) => m[0] == Push.i.mode, orElse: () => Push.modes.first)[2],
                  style: TextStyle(
                    fontSize: 12,
                    color: !Push.i.ready && Push.i.mode != 'off'
                        ? dangerText(context)
                        : Theme.of(context).hintColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (st.isAdmin) ...[
            SectionCard(
              title: '🏸 모임 설정',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('모임 이름'),
                    subtitle: Text(st.couple?['title'] as String? ?? '이름 없음'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _editTitle,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('월 회비'),
                    subtitle: Text(fmtWon(
                        ((st.couple?['fee'] as Map?)?['amount'] as num?)?.toInt() ?? 0)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _editFee,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('회비 보내는 곳'),
                    subtitle: Text(
                      _accountOf(st).isEmpty
                          ? '아직 없어요 — 적어두면 회원이 바로 복사해요'
                          : _accountOf(st),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _editAccount,
                  ),
                  if (st.isOwner)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('🎨 모임 꾸미기'),
                      subtitle: const Text('상징 이모지·사진, 크기와 회전'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _editEmblem,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          SectionCard(
            title: '🎨 테마',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in clubThemes)
                  GestureDetector(
                    onTap: st.isAdmin
                        ? () async {
                            final code = st.code;
                            if (code == null) return;
                            try {
                              await Store.i.setCouple(code, {'theme': t.key});
                            } catch (_) {
                              if (context.mounted) toast(context, '테마를 바꾸지 못했어요');
                              return;
                            }
                            _r();
                          }
                        : null,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: t.acc,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (st.couple?['theme'] as String? ?? 'sky') == t.key
                              ? Colors.black87
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!st.isAdmin)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('테마는 방장·운영진이 바꿀 수 있어요',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            ),
          const SizedBox(height: 12),

          /* 🗑 **못 지운 사진 원본** — 있을 때만 나온다.
             숫자를 안 보여 주면 아무도 모르는 채로 **매달 보관료만** 나간다.
             ⚠️ 여기 있는 것은 저절로 다시 시도하지 않는다(그러면 포기한 뜻이 없다) —
                사장님이 이 단추를 누를 때만 대기줄로 돌아간다. */
          if (Store.i.lostCount() > 0) ...[
            SectionCard(
              title: '🗑 못 지운 사진',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '못 지운 사진 원본이 ${Store.i.lostCount()}개 남아 있어요. '
                    '보이지는 않지만 보관 요금이 계속 나갑니다.',
                    style: const TextStyle(height: 1.6),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _retryBusy ? null : _retryLost,
                      child: Text(_retryBusy ? '지우는 중…' : '다시 지워보기'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          /* 🛡 회원 보호 — 스토어(애플 1.2)가 요구하는 넷 중 «차단 풀기»와 «운영자 연락처».
             신고·거르기는 글마다 붙어 있다(길게 누르기). */
          SectionCard(
            title: '🛡 안전',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.block),
                  title: const Text('차단한 회원'),
                  subtitle: Text(
                    Moderation.blocked().isEmpty
                        ? '차단한 사람이 없어요'
                        : '${Moderation.blocked().length}명 — 눌러서 풀 수 있어요',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openBlocked,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('운영자에게 연락'),
                  subtitle: const Text(Moderation.contactEmail, style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.copy, size: 18),
                  onTap: () async {
                    await Clipboard.setData(
                        const ClipboardData(text: Moderation.contactEmail));
                    if (context.mounted) toast(context, '주소를 복사했어요');
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_remove_outlined, color: dangerText(context)),
                  title: Text('모임 탈퇴 · 내 자료 지우기',
                      style: TextStyle(color: dangerText(context))),
                  subtitle: const Text('회원 자리와 내 개인정보를 지워요 (쓴 글은 모임 기록으로 남아요)',
                      style: TextStyle(fontSize: 12)),
                  onTap: _deleteMyData,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          /* 📖 방장 안내서 다시 보기 — 홈에서 닫은 뒤 되찾는 길.
             이 길이 없으면 한 번 닫은 안내서를 **영영 못 본다**(닫기가 곧 삭제가 된다). */
          if (st.isOwner)
            SectionCard(
              title: '📖 방장 안내서',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('방장 안내서 다시 보기'),
                subtitle: const Text('회원 부르기·직책·회비·일정·이용권 차례대로',
                    style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  OwnerGuideCard.reset();
                  toast(context, '홈 맨 위에 다시 나와요');
                },
              ),
            ),
          if (st.isOwner) const SizedBox(height: 20),

          SectionCard(
            title: '📋 모임 안내',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '회원이 들어오는 법: 이 모임 이름 「${st.couple?['title'] ?? ''}」을 알려주면 됩니다.\n'
                  '대소문자·띄어쓰기가 달라도 찾아와요.',
                  style: const TextStyle(height: 1.6),
                ),
                const SizedBox(height: 10),
                Text(
                  '폰을 바꿀 때: 새 폰에서 같은 이름과 생년월일로 들어오면 승인 없이 바로 이어받아요.',
                  style: TextStyle(height: 1.6, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 🤫 숨은 입구 — 버전 글씨를 5번 두드리면 총괄 콘솔 (화면 어디에도 흔적이 없다)
          Center(
            child: GestureDetector(
              onTap: () async {
                _versionTaps++;
                if (_versionTaps < 5) return;
                _versionTaps = 0;
                /* 🤫 이미 허락받은 기기면 아무것도 안 묻고 바로 연다.
                   처음이면 그때만 아이디·암호를 묻는다 (admin.dart 가 가린다). */
                await openAdminByTaps(context);
              },
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text('${Cfg.appName} ${Cfg.version}',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () async {
                final ok = await confirmSheet(
                  context,
                  st.isOwner && st.memberList.length > 1
                      ? '방장이신데 나가시겠어요?'
                      : '이 모임에서 나갈까요?',
                  st.isOwner && st.memberList.length > 1
                      ? '나가도 방장 자리는 그대로 남아, 가입 승인·설정을 할 사람이 없어져요.\n'
                          '먼저 회원 화면에서 👑 방장 넘기기를 해주세요.\n\n'
                          '이 폰에서만 나가는 거예요 — 알림도 더 오지 않아요. '
                          '같은 이름·생년월일로 다시 들어오면 그대로 이어받습니다.'
                      : '이 폰에서만 나가는 거예요 — 알림도 더 오지 않아요. '
                          '같은 이름·생년월일로 다시 들어오면 그대로 이어받습니다.',
                  okLabel: '나가기',
                  danger: true,
                );
                if (!ok) return;
                /* 🔕 이 폰으로는 «알림도» 그쳐야 한다.
                   서버의 회원 자리는 그대로 두되(다시 들어올 수 있게) **알림 받는 자리만** 비운다.
                   안 비우면 나간 모임의 대화 알림이 이 폰에 계속 오고,
                   눌러도 그 모임 화면이 없어 엉뚱한 데로 간다.
                   (탈퇴 처리는 처음부터 `push.$uid` 를 비웠는데 «스스로 나가기»만 빠져 있었다)
                   ⚠️ 못 비워도 나가기는 막지 않는다 — 신호가 없다고 못 나가면 더 나쁘다.
                      다시 들어오면 새 토큰이 그 자리를 덮는다. */
                final leaving = st.code;
                if (leaving != null) {
                  try {
                    await Store.i
                        .patchCouple(leaving, {'push.${Store.i.myUid}': null});
                  } catch (_) {/* 다음에 다시 들어올 때 덮인다 */}
                }
                Store.i.stopAll();
                await AppState.i.clearProfile();
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('모임에서 나가기', style: TextStyle(color: dangerText(context))),
            ),
          ),
        ],
      ),
    );
  }

  /// 🚫 차단한 회원 목록 — 눌러서 푼다
  Future<void> _openBlocked() async {
    final st = AppState.i;
    final code = st.code;
    if (code == null) return;
    final list = Moderation.blocked().toList();
    if (list.isEmpty) {
      return toast(context, '차단한 사람이 없어요');
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 6),
              child: Text('차단한 회원',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            for (final uid in list)
              ListTile(
                leading: Avatar(uid, size: 34),
                title: Text(st.nameOf(uid)),
                trailing: TextButton(
                  onPressed: () async {
                    final ok = await Store.i
                        .setBlocked(code, Moderation.nextBlocked(uid, false));
                    if (!c.mounted) return;
                    Navigator.pop(c);
                    if (mounted) {
                      toast(context, ok ? '차단을 풀었어요' : '풀지 못했어요 — 다시 시도해주세요');
                      setState(() {});
                    }
                  },
                  child: const Text('차단 풀기'),
                ),
              ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /* 🗑 모임 탈퇴 — 스토어가 요구하는 «앱 안에서의 계정 삭제»(애플 5.1.1(v)).

     ⚠️ 무엇이 지워지고 무엇이 남는지 **먼저 정직하게** 알린다.
        회비 장부와 대화는 «모임이 함께 쓴 기록»이라 한 사람이 나갔다고 지우지 않는다.
        옛 글의 글쓴이 이름·아바타도 남긴다 — 지우면 「알 수 없는 사람」이 되어
        지난 대화를 읽을 수 없다 (`Store.deleteMyData` 의 `former` 가 그 몫).
     ⚠️ 그러니 «이름·아바타를 지운다»고 적으면 **거짓말이 된다.**
        2026-08-25 실제로 그렇게 적혀 있었다 — 화면 글과 코드가 어긋나면
        스토어에 내는 «데이터 삭제» 신고까지 함께 거짓이 된다. */
  Future<void> _deleteMyData() async {
    final st = AppState.i;
    final code = st.code;
    if (code == null) return;
    /* 👑 방장도 그냥 나갈 수 있다 — 방장 자리는 **자동으로** 다음 사람에게 넘어간다
       (회장→총무→부회장→가입 순, Logic.nextOwnerUid).
       예전에는 「먼저 넘겨주세요」라며 탈퇴를 막았는데, 그 화면을 못 찾는 방장은
       앱을 지우는 걸로 «해결»했고 방은 주인 없는 채로 남았다.
       누구에게 가는지는 **누르기 전에** 알려 준다. */
    String handover = '';
    if (st.isOwner && st.memberList.length > 1) {
      final succ = Logic.nextOwnerUid(
          (st.couple?['members'] as Map?)?.cast<String, dynamic>() ?? {},
          Store.i.myUid);
      if (succ != null) {
        handover = '\n\n👑 방장 자리는 «${st.nameOf(succ)}»님에게 자동으로 넘어가요 '
            '(회장→총무→부회장→가입 순).';
      }
    }
    final ok = await confirmSheet(
      context,
      '이 모임에서 탈퇴할까요?',
      '지워지는 것: 이 모임의 회원 자리(더는 들어올 수 없어요), 생년월일, 알림 설정, 읽음·접속 기록.\n'
      '남는 것: 이미 쓴 대화·글·사진, 그리고 그 글에 «글쓴이»로 보이는 이름과 아바타 '
      '(모임이 함께 쓴 기록이라, 지우면 남의 대화에 구멍이 나고 누가 쓴 글인지 알 수 없게 돼요).\n'
      '그 글과 이름까지 모두 지우려면 설정의 「운영자에게 연락」으로 알려주세요.$handover',
      okLabel: '지우기',
      danger: true,
    );
    if (!ok || !mounted) return;
    final done = await Store.i.deleteMyData(code);
    if (!mounted) return;
    if (!done) return toast(context, '지우지 못했어요 — 연결을 확인하고 다시 해주세요');
    Store.i.stopAll();
    await st.clearProfile();
    if (!mounted) return;
    Navigator.pop(context);
    toast(context, '내 자료를 지웠어요');
  }

  Future<void> _editMe() async {
    final st = AppState.i;
    final nameC = TextEditingController(text: st.me?['name'] as String? ?? '');
    var emoji = (st.me?['emoji'] as String?) ?? defaultAvatar;
    /* 📷 지금 쓰는 아바타 사진 번호(없으면 null). 옛 모임은 `data:` 로 시작하는 그림 그 자체다. */
    String? photo = st.me?['photo'] is String ? st.me!['photo'] as String : null;
    /* 이번에 새로 고른 사진. **회원 칸에 넣지 않고** 저장할 때 보관함으로 올려 «번호»만 적는다.
       모임 문서는 회원 모두가 실시간으로 듣고 있어서, 그림을 통째로 넣으면
       누가 글씨만 쳐도 사진이 회원 수만큼 다시 내려간다. */
    Uint8List? picked;
    final birthStr = st.me?['birth'] as String?;
    DateTime? birth = birthStr != null && birthStr.length >= 10 ? DateTime.tryParse(birthStr) : null;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(c).viewInsets.bottom + 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('내 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                TextField(
                  controller: nameC,
                  maxLength: 12,
                  decoration: const InputDecoration(labelText: '내 이름', counterText: ''),
                ),
                const SizedBox(height: 10),
                /* 숫자 6자리(800125)로 바로 친다 — 가입 화면과 같은 칸.
                   폰을 바꿀 때 이 값으로 본인 확인을 하므로 여기서도 고칠 수 있어야 한다. */
                BirthInput(
                  initial: birth,
                  onChanged: (d) => setS(() => birth = d),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('아바타', style: TextStyle(color: Theme.of(c).hintColor)),
                ),
                const SizedBox(height: 6),
                /* 📷 자기 사진을 쓰는 사람이 많다 — 이모지 말고 앨범 사진도 고를 수 있게.
                   고르면 미리보기를 바로 보여 준다(저장 전에 어떤 얼굴이 되는지 알 수 있게). */
                Row(
                  children: [
                    if (picked != null || (photo != null && photo!.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ClipOval(
                          child: picked != null
                              ? Image.memory(picked!,
                                  width: 44, height: 44, fit: BoxFit.cover)
                              : photo!.startsWith('data:')
                                  ? Avatar(Store.i.myUid, size: 44)
                                  : ClubPhoto(
                                      photoId: photo,
                                      width: 44,
                                      height: 44,
                                      decodeWidth: 132),
                        ),
                      ),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final x = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 360,
                            // 세로도 함께 줄인다 — 긴 사진은 가로만 줄여선 여전히 크다
                            maxHeight: 360,
                            imageQuality: 80,
                          );
                          if (x == null) return;
                          final bytes = await x.readAsBytes();
                          setS(() => picked = bytes);
                        },
                        icon: const Icon(Icons.photo_outlined, size: 18),
                        label: const Text('앨범 사진'),
                      ),
                    ),
                    if (picked != null || (photo != null && photo!.isNotEmpty)) ...[
                      const SizedBox(width: 8),
                      /* 사진을 그만 쓰고 이모지로 돌아가는 길 — 없으면 한번 고른 사진을 못 뺀다.
                         (저장할 때 옛 원본도 같이 치운다 — 안 그러면 보관료만 계속 나간다) */
                      OutlinedButton(
                        onPressed: () => setS(() {
                          picked = null;
                          photo = null;
                        }),
                        child: const Text('이모지로'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 150,
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in allAvatars)
                          InkWell(
                            onTap: () => setS(() => emoji = e),
                            child: Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: e == emoji
                                      ? Theme.of(c).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Text(e, style: const TextStyle(fontSize: 21)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('저장'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    // ⚠️ 화면 값은 시트가 닫힌 «직후» 여기서 다 읽어 둔 뒤 입력칸을 치운다.
    //    (먼저 치우면 값을 못 읽고, 안 치우면 열 때마다 조금씩 쌓인다)
    final typedName = nameC.text.trim();
    nameC.dispose();
    if (saved != true) return;

    // ⚠️ 화면 값은 저장 전에 전부 읽어 둔다 — 저장 도중 시트가 닫혀 빈 값을 읽으면 설정이 되돌아간다
    final name = typedName.isEmpty ? (st.me?['name'] as String? ?? '나') : typedName;
    final birthOut = birth == null ? (st.me?['birth'] as String? ?? '') : ymd(birth!);

    // 같은 이름·같은 아바타가 생기면 서로 구분이 안 된다 (사진 아바타는 그 자체로 구분됨)
    // 내가 사진 아바타를 쓰면 나는 그 자체로 구분되므로 겹침이 아니다
    /* 사진 아바타는 그 자체로 구분되므로 겹침으로 안 센다.
       ⚠️ **지금 화면에서 고른 값**으로 따져야 한다 — 저장돼 있는 값(st.me)으로 보면
          방금 「이모지로」를 눌러 사진을 뺀 사람이 겹침 검사를 그냥 통과해,
          같은 이름·같은 이모지 두 사람이 생겨 채팅·출석에서 구분이 안 된다. */
    final willHavePhoto = picked != null || (photo != null && photo!.isNotEmpty);
    final clash = willHavePhoto
        ? null
        : Logic.avatarClash(st.memberList, name, emoji, skipUid: Store.i.myUid);
    if (clash != null) {
      if (mounted) toast(context, '같은 이름·같은 아바타의 회원이 있어요 — 아바타를 다르게 골라주세요');
      return;
    }

    final code = st.code;
    if (code == null) return;

    // 새로 고른 사진은 «보관함에 올리고 번호만» 회원 칸에 적는다 (모임 상징과 같은 방식)
    final oldPhoto = st.me?['photo'] is String ? st.me!['photo'] as String : null;
    if (picked != null) {
      final id = await Store.i.savePhoto(code, picked!);
      if (id == null) {
        if (mounted) toast(context, '사진을 올리지 못했어요 — 다시 눌러주세요');
        return;
      }
      photo = id;
    }
    final newPhoto = photo;

    try {
      // 칸을 통째로 덮으면 그 사이 방장이 바꾼 직책·권한과 부딪힌다 → 항목별로만 쓴다
      await Store.i.patchCouple(
          code,
          Store.memberPatch(Store.i.myUid, {
            'uid': Store.i.myUid,
            'name': name,
            'emoji': emoji,
            'birth': birthOut,
            /* 이모지로 돌아갔으면 번호를 «지운다»(null).
               그냥 두면 칸에 번호가 남고 그 원본도 아무도 안 치워
               **아무 데도 안 보이는 사진에 보관 요금만 계속 나간다.** */
            'photo': newPhoto,
          }));
      await st.saveProfile(code, Store.i.myUid, name);
      await st.saveLastMe(name: name, emoji: emoji, birth: birthOut);
      // 옛 원본을 치운다 — 새 사진으로 바꿨을 때, 그리고 이모지로 돌아갔을 때
      if (oldPhoto != null && oldPhoto != newPhoto) Store.i.dropPhotos([oldPhoto]);
      if (!mounted) return;
      toast(context, '저장했어요 ✨');
      _r();
    } catch (_) {
      /* 회원 칸에 못 적었으면 «방금 올린» 원본도 치운다 —
         안 그러면 아무도 못 보는 파일에 보관 요금만 매달 나간다.
         ⚠️ 「답이 없음」은 여기로 안 온다 — 그건 기기에 쌓였다가 연결되면 간다는 뜻이라 지우면 안 된다. */
      if (picked != null && newPhoto != null) Store.i.dropPhotos([newPhoto]);
      if (!mounted) return;
      saveFailToast(context, '저장하지 못했어요 — 다시 눌러주세요');
    }
  }

  Future<void> _editTitle() async {
    final st = AppState.i;
    final typed = await askText(
      context,
      title: '모임 이름',
      initial: st.couple?['title'] as String? ?? '',
      helper: '회원들이 이 이름으로 들어와요',
      maxLength: 14,
    );
    if (typed == null || typed.trim().isEmpty) return;
    final title = typed.trim();
    if (title == st.couple?['title']) return;
    /* 회원이 이름으로 들어오니 겹치면 안 된다.
       ⚠️ 이 검사는 «서버에 물어보는» 일이라 인터넷이 없으면 던진다 — 감싸지 않으면
       그 오류가 단추 밖으로 새어 나가 **눌러도 아무 일 없이 끝난다.** */
    try {
      final dup = (await Store.i.findClubByTitle(title)).where((x) => x['code'] != st.code);
      if (dup.isNotEmpty) {
        if (mounted) toast(context, '같은 이름의 모임이 이미 있어요 — 다르게 지어주세요');
        return;
      }
    } catch (_) {
      if (mounted) toast(context, '이름이 겹치는지 확인하지 못했어요 — 인터넷을 확인하고 다시 눌러주세요');
      return;
    }
    final code = st.code;
    if (code == null) return;
    try {
      await Store.i.setClubTitle(code, title);
      /* 총괄 목록(META)에도 반영하고 싶지만 **방장에게는 그 권한이 없다**(총괄 전용 문서).
         그래서 여기서는 시도하지 않는다 — 대신 총괄 콘솔이 방 문서에서 이름을 직접 읽어
         언제나 최신 이름을 보여준다. */
      if (!mounted) return;
      toast(context, '모임 이름을 바꿨어요');
      _r();
    } catch (_) {
      if (!mounted) return;
      saveFailToast(context, '저장하지 못했어요 — 다시 눌러주세요');
    }
  }

  /// 회비 보내는 곳 — 없으면 빈 글자
  static String _accountOf(AppState st) =>
      (((st.couple?['fee'] as Map?)?['account'] as String?) ?? '').trim();

  /* 🏦 회비 보내는 곳 — 「은행 계좌번호 예금주」를 한 줄로.

     ⚠️ 이게 없으면 회원은 «어디로 보내죠?»를 매번 묻고, 총무는 매번 계좌를 다시 쓴다.
        모임에서 가장 자주 오가는 말인데 앱에 자리가 없었다.
     ⚠️ 「내는 날」·금액 칸은 **건드리지 않는다** — set(merge:true)가 안쪽 묶음을 합쳐 주므로
        안 보낸 칸은 그대로 남는다. 같이 보내면 남이 방금 고친 값을 되돌린다
        (예전에 「내는 날」이 실제로 그렇게 되돌아갔다). */
  Future<void> _editAccount() async {
    final st = AppState.i;
    final typed = await askText(
      context,
      title: '회비 보내는 곳',
      initial: _accountOf(st),
      hint: '예) 우리 1002-123-456789 김총무',
      helper: '회원이 회비 화면에서 눌러 복사해요',
      maxLength: 60,
    );
    if (typed == null) return;
    final code = st.code;
    if (code == null) return;
    final v = typed.trim();
    try {
      await Store.i.setCouple(code, {
        'fee': {'account': v}
      });
      if (!mounted) return;
      toast(context, v.isEmpty ? '회비 보내는 곳을 지웠어요' : '회비 보내는 곳을 적어뒀어요');
      _r();
    } catch (_) {
      if (!mounted) return;
      saveFailToast(context, '저장하지 못했어요 — 연결을 확인해주세요');
    }
  }

  Future<void> _editFee() async {
    final st = AppState.i;
    final cur = ((st.couple?['fee'] as Map?)?['amount'] as num?)?.toInt() ?? -77;
    final typed = await askText(
      context,
      title: '월 회비',
      initial: cur == 0 ? '' : '\$cur',
      suffix: '원',
      helper: '0으로 두면 회비를 쓰지 않아요',
      maxLength: 12,
      keyboard: TextInputType.number,
    );
    if (typed == null) return;
    final amount = int.tryParse(typed.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    /* ⚠️ **우리 「다듬기」가 버릴 값은 저장하면 안 된다.**
       `Store.money` 는 1억을 넘는 값을 0으로 만든다(화면이 깨지지 않게).
       그대로 두면 「월 회비를 …원으로 정했어요」라고 말해 놓고,
       서버에서 돌아온 값은 **0원 = 회비를 안 걷는 모임**이 된다 —
       회원들의 밀린 달이 전부 사라지고 홈의 회비 카드도 통째로 없어진다.
       0은 일부러 두는 값이라(「회비를 쓰지 않아요」) 그대로 통과시킨다. */
    if (amount != Store.money(amount)) {
      if (mounted) toast(context, '회비가 너무 커요 — 자릿수를 다시 확인해주세요');
      return;
    }
    final code = st.code;
    if (code == null) return;
    try {
      /* 이 창이 고치는 건 «금액»뿐이다 — 「내는 날」까지 같이 보내면 안 된다.
         set(merge:true)는 안쪽 묶음을 **합쳐** 주므로 안 보낸 칸은 그대로 남는다.
         옛 코드는 화면이 들고 있던 «전에 본» 날짜를 같이 써서,
         웹앱(아이폰 회원)에서 방금 「매달 5일까지」로 바꿔 둔 것을 **되돌려 놓았다.**
         게다가 이 앱에는 「내는 날」을 고치는 칸이 아예 없어서,
         보이지도 않는 설정을 조용히 지우는 꼴이었다. */
      await Store.i.setCouple(code, {
        'fee': {'amount': amount}
      });
      if (!mounted) return;
      toast(context, amount == 0 ? '회비를 쓰지 않도록 했어요' : '월 회비를 ${fmtWon(amount)}으로 정했어요');
      _r();
    } catch (_) {
      if (!mounted) return;
      saveFailToast(context, '저장하지 못했어요 — 다시 눌러주세요');
    }
  }

  /// 🎨 모임 꾸미기 — 이모지나 폰 사진, 크기·회전.
  Future<void> _editEmblem() async {
    final st = AppState.i;
    final cur = (st.couple?['emblem'] as Map?)?.cast<String, dynamic>() ?? {};
    // 백업 복원·옛 버전에서 온 값이 글자가 아닐 수 있다 — 꾸미기 화면이 통째로 안 열리면 안 된다
    var kind = cur['kind'] is String ? cur['kind'] as String : 'emoji';
    var emoji = cur['emoji'] is String ? cur['emoji'] as String : '🏸';
    /* 지금 저장돼 있는 값 — 사진 번호이거나, 옛 모임이면 data: 로 시작하는 사진 그 자체다 */
    String? photo = cur['photo'] is String ? cur['photo'] as String : null;
    /* 이번에 새로 고른 사진. **문서에 넣지 않고** 저장할 때 사진 보관함으로 올린다.
       ⚠️ 예전에는 사진을 모임 문서에 통째로 적었는데, 그 문서는 회원 모두가 실시간으로 듣고 있어서
       누가 글씨만 쳐도(입력중 표시) **사진이 통째로 회원 수만큼 다시 내려갔다.** */
    Uint8List? picked;
    var size = ((cur['size'] as num?)?.toDouble() ?? 1).clamp(0.5, 2.0);
    var rot = ((cur['rot'] as num?)?.toDouble() ?? 0).clamp(-180.0, 180.0);

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('모임 꾸미기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                /* 미리보기는 «실제 화면과 같은 방식»이라야 한다.
                   ⚠️ 예전에는 `Transform.rotate`(그릴 때만 돌림) + 110px 고정 상자였다:
                     · 크기 2배면 글자 상자가 154px 이라 자리가 모자라 눌리거나 아래 슬라이더를 덮었다
                     · 기울여도 자리를 안 차지해, 여기서 맞춰 놓고 저장하면 홈에서 딴판으로 보였다
                   이제 상징과 같은 `RotateAndFit` 을 쓰고, 그린 만큼 자리를 내준다. */
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 110),
                  child: Center(
                    child: RotateAndFit(
                      angle: rot * 3.1415926535 / 180,
                      // 사진 값이 깨져 있어도 미리보기에서 앱이 죽지 않게 (웹앱에서 만든 옛 상징 대비)
                      // ⚠️ 크기·둥글기는 «홈과 같은 값»을 써야 보이는 대로 저장된다
                      child: kind == 'photo' && (picked != null || photo != null)
                          ? ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(emblemRadius(emblemBasePx)),
                              child: picked != null
                                  ? Image.memory(picked!,
                                      width: emblemBasePx * size,
                                      height: emblemBasePx * size,
                                      fit: BoxFit.cover)
                                  : photo!.startsWith('data:')
                                      ? ClubPhoto.fromSrc(photo,
                                          width: emblemBasePx * size,
                                          height: emblemBasePx * size)
                                      : ClubPhoto(
                                          photoId: photo,
                                          width: emblemBasePx * size,
                                          height: emblemBasePx * size,
                                          decodeWidth: (emblemBasePx * size * 3).round()),
                            )
                          : Text(emoji, style: TextStyle(fontSize: emblemBasePx * size)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final x = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 360,
                            // 세로도 함께 줄인다 — 긴 사진은 가로만 줄여선 여전히 크다
                            maxHeight: 360,
                            imageQuality: 80,
                          );
                          if (x == null) return;
                          final bytes = await x.readAsBytes();
                          setS(() {
                            picked = bytes;
                            kind = 'photo';
                          });
                        },
                        icon: const Icon(Icons.photo_outlined, size: 18),
                        label: const Text('폰 사진'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setS(() => kind = 'emoji'),
                        icon: const Icon(Icons.emoji_emotions_outlined, size: 18),
                        label: const Text('이모지'),
                      ),
                    ),
                  ],
                ),
                if (kind == 'emoji') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 110,
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final e in const [
                            '🏸','🎾','⚽','🏀','⚾','🏐','🏓','🥊','⛳','🎿','🏊','🚴',
                            '🏃','🧗','🥋','🛹','🎣','🎳','🏆','🥇','🎯','🎪','🎨','🎵',
                            '🌸','🌟','🔥','💎','🍀','🌈','☀','🌙',
                          ])
                            InkWell(
                              onTap: () => setS(() {
                                emoji = e;
                                kind = 'emoji';
                              }),
                              child: Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: e == emoji
                                        ? Theme.of(c).colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Text(e, style: const TextStyle(fontSize: 21)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text('크기 ${(size * 100).round()}%'),
                Slider(
                  value: size,
                  min: 0.5,
                  max: 2,
                  onChanged: (v) => setS(() => size = v),
                ),
                Text('회전 ${rot.round()}°'),
                Slider(
                  value: rot,
                  min: -180,
                  max: 180,
                  onChanged: (v) => setS(() => rot = v),
                ),
                const SizedBox(height: 8),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true), child: const Text('저장')),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true) return;
    final code = st.code;
    if (code == null) return;

    // 새로 고른 사진은 «보관함에 올리고 번호만» 문서에 적는다
    final old = photo;
    if (picked != null) {
      final id = await Store.i.savePhoto(code, picked!);
      if (id == null) {
        if (mounted) toast(context, '사진을 올리지 못했어요 — 다시 눌러주세요');
        return;
      }
      photo = id;
    }

    try {
      await Store.i.setCouple(code, {
        'emblem': {
          'kind': kind,
          'emoji': emoji,
          /* 이모지로 바꾸면 사진 번호를 «지운다»(null).
             ⚠️ 그냥 두면 문서에 번호가 남고 그 원본도 아무도 안 치워
                **아무 데도 안 보이는 사진에 보관 요금만 계속 나간다.**
                (웹앱도 이렇게 한다 — `photo: kind === 'photo' ? photo : null`) */
          'photo': kind == 'photo' ? photo : null,
          'size': size,
          'rot': rot,
        }
      });
      /* 옛 사진 원본을 치운다 (안 치우면 보관 요금만 계속 나간다):
           · 새 사진으로 바꿨을 때  · 사진을 그만 쓰고 이모지로 갔을 때
         `data:` 값은 문서 안에 그림이 든 옛 방식이라 지울 원본이 없다 —
         `dropPhotos` 가 들어오는 문에서 걸러 준다(144회차). */
      if (old != null && (picked != null || kind != 'photo')) {
        Store.i.dropPhotos([old]);
      }
      if (!mounted) return;
      toast(context, '모임 상징을 바꿨어요 🎨');
      _r();
    } catch (_) {
      /* 문서에 못 적었으면 «방금 올린» 원본도 치운다 —
         안 그러면 아무도 못 보는 파일에 보관 요금만 매달 나간다.
         (게시판·채팅은 이미 이렇게 하는데 여기만 빠져 있었다)
         ⚠️ 「답이 없음」은 여기로 안 온다 — settleVoid 가 조용히 넘긴다.
            그건 «기기에 쌓였다가 연결되면 간다»는 뜻이라 지우면 안 된다. */
      if (picked != null && photo != null) Store.i.dropPhotos([photo]);
      if (!mounted) return;
      saveFailToast(context, '저장하지 못했어요 — 다시 눌러주세요');
    }
  }
}
