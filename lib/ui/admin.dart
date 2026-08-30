import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../store.dart';
import '../theme.dart';
import 'common.dart';

/// 🔑 총괄 관리자 콘솔 — 화면 어디에도 버튼이 없다.
/// 입구는 두 곳: ①가입 화면의 모임 이름 칸에 비밀번호 ②설정의 버전 글씨 5번 두드리기.
///
/* 🔑 총괄 관리자 로그인 — **아이디 · 이름 · 생년월일**을 서버가 확인한다.

   ⚠️ 비밀은 **앱에 두지 않는다.** 앱에 적은 값은 비밀이 아니다 —
      설치 파일을 뜯으면 글자가 그대로 보인다. 서버(시크릿)만 안다.

   ⚠️ 기기를 **여러 대** 허락한다. 예전에는 한 대에 묶어 두었는데,
      그 폰을 잃으면 «해제할 기기»가 없어 **아무 데서도 못 들어갔다.**
      이제 어느 기기에서든 아이디·이름·생년월일로 들어오고,
      잃어버린 기기는 콘솔에서 뺀다.

   ⚠️ 여러 번 틀리면 서버가 잠근다 — 아이디만 맞히고 나머지를 계속 넣어 보는 것을 막는다. */
const _metaDoc = 'META';

/* 🔑 이 기기가 «이미 허락받은 총괄 기기»인가.

   한 번 들어온 기기는 서버의 «허락받은 기기 목록»에 남아 있다.
   그러면 다시 물어볼 까닭이 없다 — 곧장 콘솔을 연다.
   ⚠️ 못 읽으면(연결 끊김·규칙) **거짓으로 본다.** 그래야 물어보는 길로 가서
      적어도 들어갈 수는 있다. 참으로 보면 아무나 콘솔이 열린다. */
Future<bool> alreadyAdminDevice() async {
  try {
    final meta = await Store.i.getCouple(_metaDoc);
    if (meta == null) return false;
    final me = Store.i.myUid;
    if (me.isEmpty) return false;
    final list = meta['adminUids'];
    if (list is List && list.contains(me)) return true;
    return meta['adminUid'] == me; // 옛 방식으로 묶인 기기
  } catch (_) {
    return false;
  }
}

/* 🤫 숨은 입구 — 어디서든 «다섯 번 두드리면» 총괄 콘솔.

   ⚠️ **이미 허락받은 기기면 아무것도 안 묻는다.** 모임 안에 들어와 있어도 마찬가지다.
      사장님은 늘 같은 기기로 쓰는데 들어갈 때마다 암호 둘을 치는 것은 성가시기만 하고,
      어깨너머로 보는 사람에게 암호를 노출할 기회만 늘린다.
   ⚠️ 처음 기기이거나 목록에서 빠졌으면 그때만 «아이디 → 암호 둘»을 묻는다.
   ⚠️ 화면 어디에도 흔적을 남기지 않는다 — 눌러도 아무 일이 없어야 모르는 사람은 모른다. */
Future<void> openAdminByTaps(BuildContext context) async {
  if (await alreadyAdminDevice()) {
    if (!context.mounted) return;
    await Navigator.push(
        context, MaterialPageRoute<void>(builder: (_) => const AdminConsole()));
    return;
  }
  if (!context.mounted) return;
  final id = await askText(
    context,
    title: '총괄 관리자',
    hint: '아이디',
    maxLength: 20,
    okLabel: '다음',
  );
  if (id == null || id.trim().isEmpty || !context.mounted) return;
  await tryAdminLogin(context, id: id.trim());
}

Future<void> tryAdminLogin(BuildContext context, {String? id}) async {
  // 아이디는 «모임 이름 칸»에 적은 값을 그대로 받는다 (화면 어디에도 흔적이 없다)
  final myId = id ?? '';
  if (myId.isEmpty) return;

  /* 🔐 물어보는 말에 «무엇을 넣는지» 적지 않는다.
     예전에는 「이름」·「생년월일 8자리」라고 적혀 있었다 — 숨은 입구인데
     어깨너머로 보는 사람에게 **무엇을 알아내야 하는지 그대로 알려 주는 셈**이었다.
     아는 사람은 순서를 알고, 모르는 사람은 알 길이 없어야 한다. */
  final name = await askText(
    context,
    title: '총괄 관리자',
    hint: '첫 번째 암호',
    maxLength: 20,
    obscure: true,
    okLabel: '다음',
  );
  if (name == null || name.trim().isEmpty || !context.mounted) return;

  final birth = await askText(
    context,
    title: '총괄 관리자',
    hint: '두 번째 암호',
    keyboard: TextInputType.number,
    maxLength: 10,
    obscure: true,
    okLabel: '들어가기',
  );
  if (birth == null || birth.trim().isEmpty || !context.mounted) return;

  final why = await Store.i.adminLogin(id: myId, name: name, birth: birth);
  if (!context.mounted) return;
  if (why != null) return toast(context, why);
  await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminConsole()));
}

class AdminConsole extends StatefulWidget {
  const AdminConsole({super.key});
  @override
  State<AdminConsole> createState() => _AdminConsoleState();
}

class _AdminConsoleState extends State<AdminConsole> {
  Map<String, dynamic> _clubs = {};
  bool _loading = true;
  String? _busyText;   // 오래 걸리는 일(방 지우기)이 도는 동안 보여줄 안내
  /* 목록을 못 읽었을 때 보여줄 말. **이게 없으면 도는 표시가 참인 채로 남아
     총괄 콘솔이 «영원히 뱅뱅 도는 화면»이 된다** — 앱을 죽이는 것 말고는 빠져나올 길이 없다. */
  String? _loadErr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? meta;
    try {
      meta = await Store.i.getCouple(_metaDoc);
    } catch (_) {
      if (!mounted) return;
      return setState(() {
        _loading = false;
        _loadErr = '모임 목록을 불러오지 못했어요 — 인터넷을 확인하고 다시 눌러주세요';
      });
    }
    final clubs = (meta?['clubs'] as Map?)?.cast<String, dynamic>() ?? {};

    /* 목록에 적힌 이름은 낡아 있을 수 있다 — 방장이 이름을 바꿔도
       총괄 목록은 방장 권한으로 못 고치기 때문이다.
       그래서 **방 문서에서 지금 이름을 직접 읽어** 보여준다.
       (방을 여는 일이 잦지 않아 이 정도 조회는 부담이 안 된다) */
    /* ⏱ 방을 «한꺼번에» 물어본다. 차례로 물으면 방 하나마다 한 번씩 서버를 오가서
       방이 늘수록 그만큼 느려진다 (왕복 300ms·방 20개면 6초 넘게 흰 화면).
       읽는 횟수는 똑같고 기다리는 시간만 줄어든다. */
    final entries = clubs.entries.toList();
    /* ⚠️ 「방이 없다」와 「못 읽었다」를 반드시 갈라야 한다.
       잠깐 안 읽힌 방을 「없어진 방」으로 보여주면, 멀쩡한 방을 목록에서 지워 버릴 수 있다.
       못 읽은 것은 목록에 적힌 대로 그냥 보여준다. */
    const readFailed = Object();
    final docs = await Future.wait(entries.map((e) async {
      try {
        return await Store.i.getCouple(e.key) ?? const {}; // 빈 묶음 = 정말 없는 방
      } catch (_) {
        return readFailed;
      }
    }));
    final fresh = <String, dynamic>{};
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final row = (e.value as Map?)?.cast<String, dynamic>() ?? {};
      final d = docs[i];
      if (identical(d, readFailed)) {
        fresh[e.key] = row; // 못 읽음 — 목록에 적힌 대로 (없어진 방으로 몰지 않는다)
        continue;
      }
      final c = (d as Map).cast<String, dynamic>();
      if (c.isEmpty) {
        fresh[e.key] = {...row, 'gone': true}; // 방이 없어진 자리 (목록에만 남은 것)
        continue;
      }
      fresh[e.key] = {
        ...row,
        'title': c['title'] ?? row['title'],
        'members': (c['members'] as Map?)?.length ?? 0,
      };
    }
    if (!mounted) return;
    setState(() {
      _clubs = fresh;
      _loading = false;
      _loadErr = null;
    });
  }

  /// 방 코드 — 사람이 받아 적기 쉬우라고 헷갈리는 글자(0,O,1,I)는 뺀다.
  String _newCode({int salt = 0}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final n = DateTime.now().microsecondsSinceEpoch + salt * 7919;
    var v = n;
    final b = StringBuffer();
    for (var idx = 0; idx < 6; idx++) {
      b.write(chars[v % chars.length]);
      v = v ~/ chars.length + idx * 7;
    }
    return b.toString();
  }

  Future<void> _create() async {
    final name = await _askText('새 모임 만들기', '모임 이름 (방장이 바꿀 수 있어요)');
    if (name == null || name.trim().isEmpty) return;
    final title = name.trim();

    /* ⚠️ 겹침 검사와 빈 코드 찾기는 «서버에 물어보는» 일이라 인터넷이 없으면 던진다.
       감싸지 않으면 그 오류가 단추 밖으로 새어 나가 **눌러도 아무 일 없는 「새 모임」**이 된다. */
    String? code;
    try {
      // 회원이 "이름"으로 들어오기 때문에 겹치면 안 된다
      final dup = await Store.i.findClubByTitle(title);
      if (dup.isNotEmpty) {
        if (mounted) toast(context, '같은 이름의 모임이 이미 있어요 — 다르게 지어주세요');
        return;
      }
      // 코드가 이미 쓰이고 있으면 그 방을 덮어써 버린다 — 빈 코드가 나올 때까지 다시 뽑는다
      for (var i = 0; i < 12; i++) {
        final c = _newCode(salt: i);
        if (await Store.i.getCouple(c) == null) {
          code = c;
          break;
        }
      }
    } catch (_) {
      if (mounted) toast(context, '서버에 연결하지 못했어요 — 잠시 후 다시 눌러주세요');
      return;
    }
    if (code == null) {
      if (mounted) toast(context, '코드를 만들지 못했어요 — 잠시 후 다시 눌러주세요');
      return;
    }
    var roomMade = false;
    try {
      /* 여기는 «끝난 것을 확인해야만» 넘어가야 한다(sure: true).
         총괄은 이 코드를 방장에게 «말이나 문자로» 전한다 — 실제로는 안 들어갔는데
         「만들었어요」가 뜨면 **방장이 그 코드로 못 들어오고**, 총괄은 왜인지 모른다.
         목록(META)에 못 적는 것도 마찬가지다: 아래 되돌리기가 도는 것을 보고
         「안 만들어졌다」고 정직하게 말해야 한다. */
      await Store.i.setClubTitle(code, title, {
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'theme': 'sky',
        'members': <String, dynamic>{},
        // 총괄이 만든 방은 «이용료 면제»다 (사장님 방침) — 몇 개를 만들든 무료
        'free': true,
      }, true);
      roomMade = true;
      await Store.i.patchCouple(
          _metaDoc,
          {
            'clubs.$code': {
              'title': title,
              'createdAt': DateTime.now().millisecondsSinceEpoch
            }
          },
          sure: true);
    } catch (_) {
      /* 방은 만들어졌는데 목록에 못 적었다면 그 방은 **콘솔에 안 보이는 방**이 된다.
         이름도 이미 차지해서 같은 이름으로 다시 만들 수도 없다 → 만든 것을 되돌린다. */
      if (roomMade) {
        try {
          await Store.i.deleteCouple(code);
        } catch (_) {/* 이것마저 안 되면 다음에 같은 이름으로 못 만든다고 알린다 */}
      }
      // 안 만들어졌는데 코드를 보내면 방장이 못 들어와 한참 헤맨다
      if (mounted) toast(context, '방을 만들지 못했어요 — 다시 눌러주세요');
      return;
    }
    await _load();
    if (mounted) {
      toast(context, '"$title" 방을 만들었어요 — 🔑 코드를 방장 맡을 분에게 보내세요');
    }
  }

  Future<void> _rename(String code, String cur) async {
    final name = await _askText('모임 이름 바꾸기', '새 이름', initial: cur);
    if (name == null || name.trim().isEmpty) return;
    final title = name.trim();
    try {
      final dup = (await Store.i.findClubByTitle(title)).where((x) => x['code'] != code);
      if (dup.isNotEmpty) {
        if (mounted) toast(context, '같은 이름의 모임이 이미 있어요');
        return;
      }
    } catch (_) {
      if (mounted) toast(context, '서버에 연결하지 못했어요 — 잠시 후 다시 눌러주세요');
      return;
    }
    /* ⚠️ 쓰기가 «둘»이다 — 방 문서와 콘솔 목록.
       앞이 됐는데 뒤가 실패했을 때 그냥 「못 바꿨어요」라고 하면 **거짓말이 된다.**
       회원은 «방 이름»으로 가입하므로, 총괄이 옛 이름을 계속 알려주면
       그 이름으로는 아무도 못 들어온다. 어디까지 됐는지 갈라서 말한다. */
    var roomDone = false;
    try {
      await Store.i.setClubTitle(code, title);
      roomDone = true;
      await Store.i.patchCouple(_metaDoc, {'clubs.$code.title': title});
    } catch (_) {
      // 목록은 «방 문서에서 이름을 직접 읽으므로», 다시 읽으면 지금 사실이 보인다
      await _load();
      if (mounted) {
        toast(
            context,
            roomDone
                ? '이름은 "$title"(으)로 바뀌었어요 — 목록에만 못 적었으니 회원에게는 새 이름으로 알려주세요'
                : '이름을 바꾸지 못했어요 — 다시 눌러주세요');
      }
      return;
    }
    await _load();
    if (mounted) toast(context, '이름을 바꿨어요');
  }

  Future<void> _delete(String code, String title) async {
    final ok = await confirmSheet(
      context,
      '"$title" 방을 지울까요?',
      '대화·사진·회비 기록이 모두 사라지고 되돌릴 수 없어요.\n'
      '기록이 많으면 몇 분 걸릴 수 있어요 — 그동안 앱을 닫지 말아주세요.',
      okLabel: '방 지우기',
      danger: true,
    );
    if (!ok) return;
    // 물어보는 사이에 콘솔을 닫았을 수 있다 — 없어진 화면을 고치려 하면 터진다
    if (!mounted) return;
    setState(() => _busyText = '기록을 지우는 중…');
    try {
      // ⚠️ 반드시 기록을 먼저 — 방 문서를 먼저 지우면 규칙상 아무도 그 기록에 손댈 수 없어 영영 남는다
      final n = await Store.i.purgeClubData(
        code,
        onProgress: (d) {
          if (mounted) setState(() => _busyText = '기록을 지우는 중… $d건');
        },
      );
      await Store.i.deleteCouple(code);
      await Store.i.patchCouple(_metaDoc, {'clubs.$code': null});
      if (mounted) toast(context, '방과 기록 $n건을 지웠어요');
    } catch (_) {
      if (mounted) toast(context, '지우다가 멈췄어요 — 다시 눌러주세요 (지운 것까지는 그대로예요)');
    } finally {
      if (mounted) setState(() => _busyText = null);
    }
    await _load();
  }

  /// 방장이 폰을 잃어버렸을 때의 구제 — 방장 자리를 비우면 회원이 「내가 방장 맡기」를 누를 수 있다.
  Future<void> _releaseOwner(String code, String title) async {
    final ok = await confirmSheet(
      context,
      '"$title"의 방장 자리를 비울까요?',
      '지금 방장은 운영진으로 내려오고, 회원 아무나 「내가 방장 맡기」를 눌러 이어받을 수 있어요',
      okLabel: '방장 해제',
    );
    if (!ok) return;
    var done = false;
    try {
      done = await Store.i.mutateCouple(code, (cur) {
        final members = (cur['members'] as Map?)?.cast<String, dynamic>() ?? {};
        final owner = members.entries
            .where((e) => (e.value as Map?)?['role'] == 'owner')
            .firstOrNull;
        /* 방장이 «이미 없는» 방에서도 표시는 반드시 남긴다.
           서버 규칙은 이 표시가 있을 때만 회원이 스스로 방장이 되게 허락한다.
           예전처럼 그냥 돌아가면 그 방은 **방장을 다시 세울 길이 영영 없다** —
           회원 화면의 「내가 방장 맡기」는 거절당하고, 총괄의 이 단추도 아무 일을 안 한다. */
        return {
          if (owner != null)
            'members': {
              owner.key: {'role': 'admin'}
            },
          'ownerReleased': DateTime.now().millisecondsSinceEpoch,
        };
      });
    } catch (_) {
      done = false;
    }
    if (mounted) {
      toast(context,
          done ? '방장 자리를 열었어요 — 회원이 「내가 방장 맡기」를 누를 수 있어요' : '자리를 열지 못했어요 — 다시 눌러주세요');
    }
  }

  /* 📱 허락받은 기기 목록 — 잃어버린 폰을 여기서 뺀다.

     ⚠️ 예전에는 「이 기기의 등록을 푼다」 하나뿐이었다. 그러면 폰을 잃었을 때
        풀 기기가 없어 **아무 데서도 총괄에 못 들어갔다.**
        이제 여러 기기를 허락하고, 다른 기기에서 잃어버린 것을 뺀다.
     ⚠️ 마지막 한 대는 서버가 못 빼게 막는다 — 다 빼면 되돌릴 길이 좁아진다. */
  Future<void> _devices() async {
    /* ⚠️ 서버에서 읽어 오는 일은 **던진다** — 연결이 끊겼거나 규칙이 막으면.
       받아 내지 않으면 콘솔이 그 자리에서 빨간 화면이 된다. */
    List<String> list;
    try {
      final meta = await Store.i.getCouple(_metaDoc);
      final raw = meta?['adminUids'];
      list = raw is List ? raw.whereType<String>().toList() : <String>[];
      /* ⚠️ **옛 방식(기기 한 대)으로 묶인 기기도 보여 준다.**
         안 보여 주면 그 기기는 목록에 없어 **뺄 길이 없다** — 잃어버린 폰이 영영 남는다.
         (서버도 옛 값을 함께 본다 — 한쪽만 고치면 어긋난다) */
      final old = meta?['adminUid'];
      if (old is String && old.isNotEmpty && !list.contains(old)) list.add(old);
    } catch (_) {
      if (mounted) toast(context, '기기 목록을 받아오지 못했어요 — 연결을 확인해주세요');
      return;
    }
    final me = Store.i.myUid;
    if (!mounted) return;

    if (list.isEmpty) {
      return toast(context, '허락받은 기기가 아직 없어요');
    }
    final pick = await chooseSheet(
      context,
      '허락받은 기기 ${list.length}대',
      '뺄 기기를 골라주세요 (이 기기는 «지금 쓰는 것»이에요)',
      [
        for (final u in list)
          [u, u == me ? '이 기기 (지금 쓰는 것)' : '다른 기기 · ${_short(u)}'],
      ],
    );
    if (pick == null || !mounted) return;

    final isMe = pick == me;
    final ok = await confirmSheet(
      context,
      isMe ? '이 기기를 뺄까요?' : '이 기기를 뺄까요?',
      isMe
          ? '빼면 이 기기에서는 총괄 콘솔이 닫혀요.\n'
              '다시 들어오려면 아이디·이름·생년월일을 넣으면 돼요.'
          : '그 기기에서는 총괄 콘솔이 닫혀요.\n폰을 잃어버렸을 때 쓰는 기능이에요.',
      okLabel: '빼기',
      danger: true,
    );
    if (!ok || !mounted) return;

    final why = await Store.i.adminDropDevice(pick);
    if (!mounted) return;
    if (why != null) return toast(context, why);
    toast(context, '기기를 뺐어요');
    if (isMe) Navigator.pop(context); // 내 기기를 뺐으면 콘솔을 닫는다
  }

  /// 기기 번호는 길다 — 앞뒤만 보여 구분한다
  static String _short(String uid) =>
      uid.length <= 10 ? uid : '${uid.substring(0, 4)}…${uid.substring(uid.length - 4)}';

  /* ✏️ 한 줄 물어보기 — 그릇은 «창이» 들고 있는 공용 창을 쓴다.
     여기서 그릇을 만들어 창이 닫힌 뒤 버리면, 닫히는 몇 프레임 동안
     아직 살아 있는 입력칸이 죽은 그릇을 읽어 앱이 터진다(2026-08-29 실제로 터졌다). */
  Future<String?> _askText(String title, String label, {String initial = ''}) =>
      askText(context,
          title: title, initial: initial, hint: label, maxLength: 14, okLabel: '확인');



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('총괄 관리자'),
        actions: [
          IconButton(
            tooltip: '허락받은 기기',
            onPressed: _devices,
            icon: const Icon(Icons.devices_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
          /* ⚠️ «달리는 이름(heroTag)»을 안 주면 Flutter 가 모두 같은 이름을 쓴다.
             탭 다섯이 IndexedStack 으로 «동시에 살아 있어» 한 화면에 둥근 단추가 여럿이다.
             그러면 화면을 옮길 때 「같은 이름이 둘」이라며 **앱이 빨간 화면으로 터진다** —
             2026-08-29 설정에서 「월 회비」을 저장하는 순간 실제로 터졌고,
             이미 나간 판에도 그대로 들어 있었다. */
          heroTag: 'admin-new',  // 총괄 새 모임
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('새 모임'),
      ),
      body: _busyText != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 14),
                  Text(_busyText!),
                ],
              ),
            )
          : _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadErr != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_loadErr!, textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    FilledButton.tonal(
                      onPressed: () {
                        setState(() {
                          _loading = true; // 부른 함수가 받아 낸다
                          _loadErr = null;
                        });
                        _load();
                      },
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                SectionCard(
                  title: '🔑 두 가지 열쇠',
                  child: Text(
                    '방장 코드: 빈 방에 코드로 처음 들어온 사람이 그 방의 방장이 됩니다. 방장 맡을 분에게만 보내세요.\n'
                    '모임 이름: 회원들에게 알려주는 열쇠입니다. 이름으로는 방장이 되지 않고 가입 신청만 됩니다.',
                    style: TextStyle(height: 1.6, color: Theme.of(context).hintColor),
                  ),
                ),
                const SizedBox(height: 12),
                if (_clubs.isEmpty)
                  const SectionCard(
                    child: Text('아직 만든 모임이 없어요.\n오른쪽 아래 [새 모임]으로 방을 만들고 코드를 방장에게 보내세요.',
                        style: TextStyle(height: 1.6)),
                  ),
                for (final e in _clubs.entries) ...[
                  Builder(builder: (_) {
                    final row = (e.value as Map?)?.cast<String, dynamic>() ?? {};
                    final name = row['title'] as String? ?? '이름 없음';
                    return _ClubCard(
                      code: e.key,
                      title: name,
                      members: row['members'] as int?,
                      gone: row['gone'] == true,
                      onRename: row['gone'] == true ? null : () => _rename(e.key, name),
                      onDelete: () => _delete(e.key, name),
                      onRelease: () => _releaseOwner(e.key, name),
                    );
                  }),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _ClubCard extends StatelessWidget {
  final String code, title;
  /// 그 방 회원 수 (못 읽었으면 null)
  final int? members;
  /// 목록에는 있는데 방 문서가 없어진 자리
  final bool gone;
  /// 없어진 방은 이름을 바꿀 수 없다 — 바꾸면 빈 방이 **되살아나** 코드가 다시 살아난다
  final VoidCallback? onRename;
  final VoidCallback onDelete, onRelease;
  const _ClubCard({
    required this.code,
    required this.title,
    required this.onRename,
    required this.onDelete,
    required this.onRelease,
    this.members,
    this.gone = false,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gone ? '$title (없어진 방)' : title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: gone ? dangerText(context) : null,
                        )),
                    if (members != null)
                      Text(
                        members == 0 ? '아직 아무도 안 들어옴 — 코드를 방장에게 보내세요' : '회원 $members명',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'rename') onRename?.call();
                  if (v == 'delete') onDelete();
                  if (v == 'release') onRelease();
                },
                itemBuilder: (_) => [
                  if (!gone) const PopupMenuItem(value: 'rename', child: Text('이름 바꾸기')),
                  if (!gone)
                    const PopupMenuItem(value: 'release', child: Text('👑 방장 자리 비우기')),
                  PopupMenuItem(
                      value: 'delete', child: Text(gone ? '목록에서 지우기' : '방 지우기')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  toast(context, '방장 코드를 복사했어요 — 방장 맡을 분에게만 보내세요');
                },
                icon: const Icon(Icons.key_outlined, size: 18),
                label: Text('🔑 $code'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: title));
                  toast(context, '모임 이름을 복사했어요 — 회원들에게 알려주세요');
                },
                icon: const Icon(Icons.group_outlined, size: 18),
                label: const Text('👥 회원용 이름'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
