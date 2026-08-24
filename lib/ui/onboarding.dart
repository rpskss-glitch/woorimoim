import 'package:flutter/material.dart';

import '../config.dart';
import '../demo.dart';
import '../fee.dart';
import '../logic.dart';
import '../state.dart';
import '../store.dart';
import 'admin.dart';
import 'common.dart';

/// 가입 화면 — 두 가지 열쇠로 들어온다.
///  · 모임 이름 (회원용): 방장에게 들은 이름을 그대로 적으면 됨 (대소문자·띄어쓰기 무시)
///  · 코드 (방장 초대 전용): 총괄 관리자가 방장 맡을 분에게만 주는 열쇠.
///    "코드로" 빈 방에 제일 먼저 들어온 사람이 그 방의 방장이 된다.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onJoined;
  const OnboardingScreen({super.key, required this.onJoined});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _codeC = TextEditingController();
  final _nameC = TextEditingController();
  DateTime? _birth;
  String _emoji = allAvatars.first;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 전에 쓰던 이름·아바타·생년월일을 채워둔다 — 폰을 바꿨을 때 다시 적지 않게
    final last = AppState.i.lastMe();
    if (last['name'] is String) _nameC.text = last['name'] as String;
    if (last['emoji'] is String) _emoji = last['emoji'] as String;
    // 모임 «이름»만 채운다 — 코드는 방장 것이라 회원 화면에 뜨면 안 된다
    if (last['club'] is String) _codeC.text = last['club'] as String;
    // 다른 칸들처럼 «글자일 때만» 쓴다 — 숫자가 들어 있으면 가입 화면이 통째로 안 뜬다
    final b = last['birth'];
    if (b is String && b.length >= 10) _birth = DateTime.tryParse(b);
  }

  /* 🏸 **모임 이름 칸은 언제나 보여준다.**
     예전에는 「방이 서버에 하나뿐이면」 칸을 숨기고 그 방으로 자동 지정했다(189회차).
     그때는 앞산 배드민턴 한 곳만 쓰는 앱이었기 때문이다.
     ⚠️ 이제는 **누구나 자기 모임을 만드는 앱**이다. 그대로 두면
        스토어에서 받은 사람이 «남의 모임»으로 자동 안내되거나,
        방이 하나일 때 새 모임을 만들려는 사람이 이름을 적을 칸을 못 찾는다.
     (총괄 콘솔 입구는 로고 5번 두드리기로 따로 있으니 이 칸이 없어도 되던 문제도 함께 사라졌다) */

  /* 🤫 숨은 입구 — 로고를 5번 두드리면 총괄 콘솔.
     모임 이름 칸이 숨으면 그 칸(=예전 입구)이 사라지므로 입구를 여기로도 둔다. */
  int _logoTaps = 0;

  Future<void> _tapLogo() async {
    if (++_logoTaps < 5) return;
    _logoTaps = 0;
    await tryAdminLogin(context);
  }

  @override
  void dispose() {
    _codeC.dispose();
    _nameC.dispose();
    super.dispose();
  }

  String? get _birthStr => _birth == null ? null : ymd(_birth!);

  /* 👀 가입 없이 둘러보기 — 샘플 모임을 이 폰 안에 세우고 그대로 들어간다.
     ⚠️ 서버에는 아무것도 오가지 않는다(`Demo` 가 Store 의 모든 읽기·쓰기를 가로챈다).
        기기에도 남기지 않는다 — 앱을 껐다 켜면 다시 이 화면이다. */
  Future<void> _lookAround() async {
    final ok = await confirmSheet(
      context,
      '가입 없이 둘러볼까요?',
      '샘플 모임으로 앱을 미리 볼 수 있어요.\n'
          '이 폰에만 있고 실제 모임에는 아무 영향이 없어요.\n\n'
          '위쪽 [나가기]를 누르면 이 화면으로 돌아와요.',
      okLabel: '둘러보기',
    );
    if (!ok || !mounted) return;
    Demo.start();
    widget.onJoined();
  }

  /* ➕ 새 모임 만들기 — 누구나 자기 동호회를 열 수 있다(만든 사람이 방장).

     ⚠️ 이용료는 **모임을 만든 사람**이 낸다(월 이용권). 총괄이 만든 방과 사장님이 면제해 준 방은
        `free: true` 라 묻지 않는다. 여기서 만든 방은 면제가 아니므로 `Fee.locked` 가 곧 잠근다.
     ⚠️ 이름이 겹치면 안 된다 — 회원은 «모임 이름»으로 찾아 들어오기 때문에,
        같은 이름이 둘이면 엉뚱한 방으로 신청이 간다. */
  Future<void> _newClub() async {
    if (_busy) return;
    final title = _codeC.text.trim();
    final name = _nameC.text.trim();
    final birth = _birthStr;
    if (title.isEmpty) return toast(context, '만들 모임 이름을 위 칸에 적어주세요');
    if (title.length > 14) return toast(context, '모임 이름은 14자까지예요');
    if (name.isEmpty) return toast(context, '내 이름을 입력해주세요');
    if (birth == null) {
      return toast(context, '생년월일을 골라주세요 — 폰을 바꿀 때 본인 확인에 쓰여요');
    }
    final ok = await confirmSheet(
      context,
      '「$title」 모임을 만들까요?',
      '만든 사람이 방장이 되고, 회원은 이 이름으로 가입 신청을 해요.\n\n'
          '모임 이용권은 월 ${Fee.wonText}이고 **방장만** 냅니다 (회원은 무료).\n'
          '먼저 만들어 보시고, 회원을 부르기 전에 결제하시면 돼요.',
      okLabel: '모임 만들기',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      // 같은 이름이 이미 있는지 — 있으면 회원이 어느 방인지 못 고른다
      final dup = await Store.i.findClubByTitle(title);
      if (dup.isNotEmpty) {
        if (mounted) toast(context, '「$title」 이름이 이미 있어요 — 다르게 지어주세요');
        return;
      }
      final code = await Store.i.freeCode();
      if (code == null) {
        if (mounted) toast(context, '모임을 만들지 못했어요 — 잠시 후 다시 눌러주세요');
        return;
      }
      final uid = Store.i.myUid;
      final now = DateTime.now();
      final made = await Store.i.createClub(code, {
        'code': code,
        'title': title,
        'titleKey': Store.normTitle(title),
        'createdAt': now.millisecondsSinceEpoch,
        'startDate': ymd(now),
        'theme': 'sky',
        'members': {
          uid: {
            'uid': uid,
            'name': name,
            'emoji': _emoji,
            'birth': birth,
            'role': 'owner',
            'joinedAt': now.millisecondsSinceEpoch,
          }
        },
        'pending': <String, dynamic>{},
      });
      if (!made) {
        if (mounted) toast(context, '모임을 만들지 못했어요 — 연결을 확인하고 다시 눌러주세요');
        return;
      }
      await AppState.i.saveLastMe(name: name, emoji: _emoji, club: title, birth: birth);
      await AppState.i.saveProfile(code, uid, name);
      if (!mounted) return;
      widget.onJoined();
      toast(context, '「$title」 모임을 만들었어요 — 이제 회원을 부르세요 🏸');
    } catch (e) {
      if (mounted) toast(context, '서버에 연결하지 못했어요 — 잠시 후 다시 눌러주세요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join({bool loginOnly = false}) async {
    if (_busy) return;
    final raw = _codeC.text.trim();

    // 🤫 숨은 입구 — 모임 이름 칸에 총괄 비밀번호를 넣으면 콘솔로 (화면 어디에도 흔적이 없다)
    if (raw.isNotEmpty && raw == Cfg.adminPass) {
      _codeC.clear();
      if (!mounted) return;
      await tryAdminLogin(context);
      return;
    }

    final name = _nameC.text.trim();
    if (name.isEmpty) return toast(context, '이름을 입력해주세요');
    final birth = _birthStr;
    if (birth == null) {
      return toast(context, '생년월일을 골라주세요 — 폰을 바꿀 때 본인 확인에 쓰여요');
    }
    if (raw.isEmpty) return toast(context, '모임 이름을 입력해주세요');

    setState(() => _busy = true);
    try {
      await _doJoin(raw, name, birth, loginOnly: loginOnly);
    } catch (e) {
      if (mounted) toast(context, '서버에 연결하지 못했어요 — 잠시 후 다시 눌러주세요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* 🔑 **로그인** — 이미 승인된 내 자리로 «들어가기만» 한다.
     새 신청을 만들지 않고, 방장이 되지도 않는다.
     폰을 바꿔도 이름+생년월일이 맞으면 그 자리를 그대로 이어받는다
     (승인 없이 바로 — 서버 규칙이 이름·생년월일을 대조해 남의 자리는 막는다). */
  Future<void> _doJoin(String raw, String name, String birth,
      {bool loginOnly = false}) async {
    Store.i.stopAll(); // 이전 구독이 남아 있으면 가입 중간에 끼어든다
    final uid = Store.i.myUid;
    Map<String, dynamic>? c;
    var viaCode = false;

    final up = raw.toUpperCase();
    if (RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(up)) {
      // 감싸짐: _join 이 이 함수 전체를 try 로 받아 회원에게 말해 준다
      final d = await Store.i.getCouple(up);
      if (d != null && d['isMeta'] != true) {
        c = d;
        viaCode = true;
      }
    }
    if (c == null) {
      // 감싸짐: _join 이 이 함수 전체를 try 로 받는다
      final list = await Store.i.findClubByTitle(raw);
      if (list.length > 1) {
        if (!mounted) return;
        final pick = await chooseSheet(
          context,
          '같은 이름의 모임이 여러 개예요',
          '어느 모임인가요?',
          list.map((x) {
            final owner = (x['members'] as Map?)
                ?.values
                .whereType<Map>()
                .where((m) => m['role'] == 'owner')
                .firstOrNull;
            final n = (x['members'] as Map?)?.length ?? 0;
            return [
              x['code'] as String,
              '${x['title']} — ${owner == null ? '방장 없음' : '방장 ${owner['name']}'} · $n명'
            ];
          }).toList(),
        );
        if (pick == null) return;
        c = list.firstWhere((x) => x['code'] == pick);
      } else {
        c = list.isEmpty ? null : list.first;
      }
    }

    if (c == null) {
      if (mounted) {
        toast(context, '그 이름의 모임을 찾지 못했어요 — 방장에게 정확한 이름을 확인해주세요');
      }
      return;
    }

    final code = c['code'] as String;
    // 이름·아바타는 다음에 다시 적지 않게 미리 기억해 둔다 (이건 이 기기에만 남는 값)
    await AppState.i.saveLastMe(
        name: name, emoji: _emoji, club: c['title'] as String?, birth: birth);

    // ⚠️ 「내가 이 모임 사람이다」는 표시는 서버에 실제로 들어간 뒤에만 남긴다.
    //    먼저 남기면, 저장이 실패하거나 아바타가 겹쳐 되돌아갔을 때도 남아서
    //    다음에 앱을 열 때 "모임 이용이 중지됐어요"라고 잘못 알린다.
    Future<void> enter() async {
      await AppState.i.saveProfile(code, uid, name);
      widget.onJoined();
    }

    final members = (c['members'] as Map?)?.cast<String, dynamic>() ?? {};
    final empty = members.isEmpty;

    // 🔑 코드로 들어온 첫 사람만 방장 — 이름으로는 절대 방장이 되지 않는다
    // 감싸짐: _join 이 이 함수 전체를 try 로 받아 회원에게 말해 준다
    if (empty && viaCode && !loginOnly) {
      await Store.i.patchCouple(code, {
        'members.$uid': {
          'name': name,
          'emoji': _emoji,
          'uid': uid,
          'birth': birth,
          'role': 'owner',
          'joinedAt': DateTime.now().millisecondsSinceEpoch,
        }
      });
      if (mounted) {
        toast(context, '"${c['title'] ?? '모임'}"의 방장이 되었어요 👑 설정에서 이름·꾸미기를 바꿀 수 있어요');
      }
      await enter();
      return;
    }

    // 이미 승인된 회원이면(같은 기기 재설치 등) 바로 입장
    if (members.containsKey(uid)) {
      if (mounted) toast(context, '다시 만나서 반가워요! 🏸');
      await enter();
      return;
    }
    if (empty && mounted) {
      toast(context, '아직 방장이 들어오지 않은 모임이에요 — 신청은 방장이 온 뒤에 승인돼요');
    }

    /* 같은 이름 처리 —
       · 기존 회원에게 생년월일이 있고 지금 적은 것과 같으면: 묻지 않고 바로 이어받는다 (본인 확실)
       · 생년월일이 있는데 다르면: 다른 사람으로 본다 (남의 이름으로 자격을 가로채지 못하게)
       · 생년월일이 아직 없는 옛 회원이면: 예전처럼 물어본다 */
    final sameName = members.values
        .whereType<Map>()
        .where((m) =>
            (m['uid'] as String?)?.isNotEmpty == true &&
            Store.normTitle(m['name'] as String?) == Store.normTitle(name))
        .toList();
    // 같은 이름이 여럿이면 **생년월일이 맞는 사람**을 먼저 본다.
    // 그냥 첫 사람을 잡으면 동명이인 때문에 정작 본인이 이어받지 못한다
    final dup = sameName.where((m) => m['birth'] == birth).firstOrNull ??
        sameName.firstOrNull;

    if (dup != null) {
      String? pick;
      final dupBirth = dup['birth'] as String?;
      /* ⚠️ 옛 자리에 «생년월일이 없으면» 서버가 이어받기를 **막는다.**
         규칙(claimsOwnSeat)이 「새 자리의 생년월일 == 옛 자리의 생년월일」을 요구하는데
         옛 자리에 그 칸이 없으면 견줄 수가 없기 때문이다. 2026-08-22 실서버로 확인:
         생년월일이 같으면 통과, 없던 자리는 **403**.
         그런데 앱은 「혹시 본인이신가요?」라고 묻고 있었다 → 「네」를 누르면 막히고,
         화면에는 「서버에 연결하지 못했어요」라고만 떠서 **몇 번을 눌러도 안 됐다.**
         (막는 것 자체는 옳다 — 이름만 알면 남의 자리를 가로챌 수 있으니까)
         그래서 묻지 않고, 왜 안 되는지 알려준 뒤 보통 가입 신청으로 보낸다. */
      if (dupBirth != null && dupBirth.isNotEmpty) {
        pick = dupBirth == birth ? 'claim' : 'other';
      } else {
        pick = 'other';
        if (mounted && !loginOnly) {
          toast(context,
              '"${dup['name']}"님 자리는 생년월일이 없어 바로 이어받을 수 없어요 — 가입 신청을 보낼게요 (방장이 승인해줍니다)');
        }
      }

      if (pick == 'claim') {
        final oldUid = dup['uid'] as String;
        Map<String, dynamic>? old;
        // 승인 없이 즉시 이전 — 트랜잭션이라 두 기기가 동시에 눌러도 한 명만 이어받는다
        // 감싸짐: _join 이 이 함수 전체를 try 로 받는다
        final took = await Store.i.mutateCouple(code, (cur) {
          /* ⚠️ 부딪히면 이 덩어리가 **다시 돈다** — 앞 시도에서 담아둔 옛 자리를 반드시 지운다.
             안 지우면 «다른 기기가 먼저 이어받았는데도» 「이어받았어요」라고 알리고
             그대로 들어가, 회원은 영문도 모른 채 승인 대기 화면에 놓인다. */
          old = null;
          final o = (cur['members'] as Map?)?[oldUid] as Map?;
          if (o == null) return null; // 이미 다른 기기가 먼저 이어받음
          old = o.cast<String, dynamic>();
          return {
            'members': {
              oldUid: Store.del,
              uid: {
                ...o.cast<String, dynamic>(),
                'uid': uid,
                'emoji': _emoji,
                'birth': (o['birth'] as String?)?.isNotEmpty == true ? o['birth'] : birth,
              },
            },
            'former': {
              oldUid: {
                'uid': oldUid,
                'name': o['name'],
                'emoji': o['emoji'] ?? defaultAvatar,
                'movedTo': uid,
                'leftAt': DateTime.now().millisecondsSinceEpoch,
              }
            },
            'push': {oldUid: Store.del}, // 옛 기기 푸시는 끊는다
            'pending': {uid: Store.del},
            // 「누구 자리를 이어받는지」를 적어 둔다 — 서버가 이름·생년월일이 맞는지 확인하는 데 쓴다
            // (이게 없으면 서버는 남의 자리를 빼앗는 것과 구분할 수 없어 아예 막아야 한다)
            'claimFrom': oldUid,
          };
        });
        // 「썼는지」는 트랜잭션이 돌려준 값이 사실이다 — 밖에 담아둔 값만 믿으면 안 된다
        if (!took || old == null) {
          if (mounted) {
            toast(context, '이미 다른 기기에서 연결을 이어받았어요 — 본인이 아니면 방장에게 알려주세요');
          }
          return;
        }
        final moved = await Store.i.migrateFeePayer(code, oldUid, uid);
        /* 「어디까지 읽었는지」도 이어받는다.
           ⚠️ 이 값은 **기기마다 따로** 있어 새 폰에서는 0이다. 그대로 두면
              창 안의 남의 대화가 전부 안읽음으로 잡혀, 폰을 바꾸자마자
              **「안읽음 200」**이 뜬다 — 옛 폰에서 이미 다 읽은 것인데도.
              서버에는 옛 번호의 읽음 표시(`lastRead[옛번호]`)가 그대로 남아 있으니 그걸 쓴다.
              (이어받기 트랜잭션은 `lastRead` 를 안 건드린다) */
        final read = (c['lastRead'] as Map?)?[oldUid];
        if (read is num) AppState.i.lastSeenChat = read.toInt();
        if (mounted) {
          final t = old!['title'];
          toast(
            context,
            '${dupBirth != null ? '생년월일이 확인돼 ' : ''}새 기기로 이어받았어요 🔁'
            '${t == null ? '' : ' $t 그대로'}${moved > 0 ? ' · 회비 기록 $moved건 포함' : ''}',
          );
        }
        await enter();
        return;
      }

      /* 🔑 로그인인데 이어받지 못했다면 «여기서» 끝낸다.
         아래는 «새로 신청하는» 길이라, 그대로 흘려보내면 로그인을 눌렀는데
         「아바타가 똑같아요 — 다시 신청해주세요」 같은 엉뚱한 안내가 뜬다.
         (웹앱에서 실제로 그랬다 — 2026-08-24 브라우저로 확인) */
      if (loginOnly) {
        if (!mounted) return;
        toast(
            context,
            dupBirth != null && dupBirth.isNotEmpty
                ? '"$name"님 자리는 생년월일이 달라요 — 생년월일을 다시 확인해주세요'
                : '"${dup['name']}"님 자리는 생년월일이 없어 로그인으로 이어받을 수 없어요 — '
                    '「가입 신청하기」를 눌러주세요 (방장이 승인해줍니다)');
        return;
      }

      // 동명이인 — 아바타가 같으면 서로 구분이 안 되니 다른 아바타를 고르게 한다
      // (같은 이름이 여럿일 수 있으므로 «전부» 훑는다 — Logic.avatarClash)
      final clash = Logic.avatarClash(
          sameName.map((m) => m.cast<String, dynamic>()), name, _emoji);
      if (clash != null) {
        if (mounted) {
          toast(context, '"${clash['name']}"님과 아바타가 똑같아요 — 다른 아바타를 고른 뒤 다시 신청해주세요 (이름은 같아도 돼요)');
        }
        return;
      }
    }

    /* 🔑 로그인은 여기서 끝난다 — **신청을 만들지 않는다.**
       만들어 버리면 「로그인」을 눌렀는데 승인 대기 화면에 놓여, 회원은 자기가
       이미 가입돼 있는 줄 알고 오지 않을 승인을 계속 기다린다.
       왜 안 됐는지 «구분해서» 말해 준다 — 안 그러면 이름을 잘못 적었는지
       아직 승인이 안 난 것인지 알 길이 없다. */
    if (loginOnly) {
      if (!mounted) return;
      final waiting = (c['pending'] as Map?)?.values
          .whereType<Map>()
          .any((p) => Store.normTitle(p['name'] as String?) == Store.normTitle(name));
      // 여기 오는 것은 «같은 이름의 회원이 아예 없는» 경우뿐이다 (있으면 위에서 끝났다)
      toast(
          context,
          waiting == true
              ? '아직 승인 전이에요 — 방장이 승인하면 그때 로그인할 수 있어요'
              : '그 이름으로 등록된 회원이 없어요 — 아래 「가입 신청하기」를 먼저 눌러주세요');
      return;
    }

    // 대기 중인 같은 이름과도 아바타가 겹치면 구분이 안 된다 (여기도 «전부» 훑는다)
    final pendingClash = Logic.avatarClash(
        ((c['pending'] as Map?)?.values ?? const [])
            .whereType<Map>()
            .map((p) => p.cast<String, dynamic>()),
        name,
        _emoji,
        skipUid: uid);
    if (pendingClash != null) {
      if (mounted) toast(context, '같은 이름·같은 아바타의 신청이 이미 있어요 — 다른 아바타를 골라주세요');
      return;
    }

    // 가입 신청 — 내 신청만 보낸다 (통째로 보내면 그 사이 승인·거절된 남의 신청이 되살아난다)
    try {
      await Store.i.setCouple(code, {
        'pending': {
          uid: {
            'name': name,
            'emoji': _emoji,
            'uid': uid,
            'birth': birth,
            'requestedAt': DateTime.now().millisecondsSinceEpoch,
          }
        }
      });
    } catch (_) {
      // 신청이 안 갔는데 「신청했어요」라고 하면 회원은 오지 않을 승인을 계속 기다린다
      if (mounted) toast(context, '가입 신청을 보내지 못했어요 — 다시 눌러주세요');
      return;
    }
    await enter(); // 대기 화면으로 넘어간다
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _tapLogo,
                    child: const Text('🏸', style: TextStyle(fontSize: 52)),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(Cfg.appName,
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w900, color: cs.primary)),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text('모임 소식과 기록을 한 곳에',
                      style: TextStyle(color: Theme.of(context).hintColor)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: const [
                    _Pill('💬 단체 채팅'),
                    _Pill('📅 일정 · 참석 투표'),
                    _Pill('💰 회비 장부'),
                    _Pill('✅ 출석 체크'),
                    _Pill('📸 사진첩'),
                  ],
                ),
                const SizedBox(height: 24),
                _Label('모임 이름',
                    hint: '들어갈 모임 이름 · 새로 만들 이름 · 받은 코드'),
                TextField(
                  controller: _codeC,
                  maxLength: 14,
                  decoration: const InputDecoration(
                      hintText: '예) 수요일 딩크반', counterText: ''),
                ),
                const SizedBox(height: 14),
                _Label('내 이름', hint: '실명이나 부르는 이름'),
                TextField(
                  controller: _nameC,
                  maxLength: 12,
                  decoration: const InputDecoration(hintText: '예) 김민수', counterText: ''),
                ),
                const SizedBox(height: 14),
                _Label('생년월일', hint: '폰을 바꿔도 이름+생년월일로 바로 이어받아요'),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: clampDate(_birth ?? DateTime(1990, 1, 1),
                          DateTime(1920), DateTime(2020, 12, 31)),
                      firstDate: DateTime(1920),
                      lastDate: DateTime(2020, 12, 31),
                      helpText: '생년월일을 골라주세요',
                    );
                    if (d != null) setState(() => _birth = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(),
                    child: Text(
                      _birthStr ?? '눌러서 고르기',
                      style: TextStyle(
                          color: _birth == null ? Theme.of(context).hintColor : null,
                          fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _Label('내 아바타', hint: '같은 이름이면 아바타로 구분해요'),
                _AvatarPicker(
                  selected: _emoji,
                  onPick: (e) => setState(() => _emoji = e),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : _join,
                  child: _busy
                      ? const SizedBox(
                          width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('🏸 가입 신청하기'),
                ),
                const SizedBox(height: 10),
                /* 🔑 이미 승인된 회원이 «들어오는» 길.
                   폰을 바꿨을 때 「가입 신청하기」를 누르면 또 승인을 기다려야 하는 줄 알기 쉽다 —
                   그래서 들어오는 길을 따로 보이게 둔다. 아바타는 안 본다(이미 자기 것이 있다). */
                OutlinedButton(
                  onPressed: _busy ? null : () => _join(loginOnly: true),
                  child: const Text('🔑 로그인하기'),
                ),
                const SizedBox(height: 8),
                Text(
                  '이미 승인된 회원이면 이름·생년월일로 바로 들어와요 — 폰을 바꿔도 그대로예요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: 14),
                /* 👀 가입 없이 둘러보기 — 샘플 모임으로 앱 전체를 볼 수 있다.
                   새 회원이 「어떤 앱인지」 보고 정할 수 있고, 스토어 심사원도 승인을 기다리지 않고 볼 수 있다
                   (승인 대기 화면에서 막히면 애플이 2.1 「미완성」으로 반려한다). */
                OutlinedButton(
                  onPressed: _busy ? null : _lookAround,
                  child: const Text('👀 가입 없이 둘러보기'),
                ),
                const SizedBox(height: 8),
                Text(
                  '샘플 모임으로 앱을 미리 볼 수 있어요 — 이 폰에만 있고 실제 모임과 섞이지 않아요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: 10),
                /* ➕ 누구나 자기 동호회를 열 수 있다 — 위 칸에 «만들 이름»을 적고 누르면 된다.
                   (이 길이 없으면 스토어에서 받은 사람은 쓸 수가 없어 「미완성 앱」으로 보인다) */
                OutlinedButton(
                  onPressed: _busy ? null : _newClub,
                  child: const Text('➕ 새 모임 만들기'),
                ),
                const SizedBox(height: 8),
                Text(
                  '위 칸에 만들 모임 이름을 적고 눌러주세요 · 만든 사람이 방장이 돼요\n'
                  '모임 이용권은 월 ${Fee.wonText}(방장만 · 회원은 무료)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: 14),
                Text(
                  '신청하면 그 모임의 방장·운영진이 승인한 뒤부터 쓸 수 있어요\n모임마다 공간이 완전히 분리돼 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final String? hint;
  const _Label(this.text, {this.hint});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (hint != null) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Text(hint!,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
            ),
          ],
        ],
      ),
    );
  }
}

/// 아바타 고르기 — 무리별로 묶어서 스크롤.
class _AvatarPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onPick;
  const _AvatarPicker({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .5)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          for (final g in avatarGroups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 4),
              child: Text(g.key,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).hintColor)),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in g.value)
                  InkWell(
                    onTap: () => onPick(e),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: e == selected ? cs.primary.withValues(alpha: .18) : null,
                        border: Border.all(
                          color: e == selected ? cs.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
