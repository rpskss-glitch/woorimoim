import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🔐 «모임 문서에 무엇을 쓰는가» ↔ 서버 규칙이 «평회원에게 허락한 칸».

   규칙(firestore.rules)의 memberScopeOnly 는 평회원이 바꿀 수 있는 최상위 칸을
   딱 몇 개로 못박는다. 그 밖의 칸을 평회원이 닿을 수 있는 자리에서 쓰면
   서버가 거절해 **눌러도 안 되는 단추**가 된다(161회차 회비 장부와 같은 갈래).

   그래서 이 시험은 세 가지를 한다.
     ① 규칙 파일에서 허락된 칸 목록을 «직접 읽어» 온다 (규칙이 바뀌면 알려준다).
     ② 앱이 모임 문서에 쓰는 최상위 칸을 «빠짐없이 세어» 새 칸이 생기면 알려준다.
     ③ 허락 밖의 칸을 쓰는 파일마다 «방장·운영진 문지기»가 있는지 본다. */
void main() {
  const rulesPath = r'C:\Users\asas3\Desktop\데이트장부\firestore.rules';

  String bare(String p) => File(p)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  /// 모임 문서에 쓰는 부름 하나에서 «최상위» 칸 이름만 뽑는다
  Set<String> keysWritten(String src) {
    final out = <String>{};
    for (final m
        in RegExp(r'(?:patchCouple|setCouple|mutateCouple)\(').allMatches(src)) {
      var depth = 0, i = m.end - 1;
      for (; i < src.length; i++) {
        if (src[i] == '(') depth++;
        if (src[i] == ')') { depth--; if (depth == 0) break; }
      }
      final blk = src.substring(m.end, i);
      // 묶음 안쪽 칸까지 다 잡히지만, 점 앞만 취하고 아래에서 «아는 칸»으로 걸러 본다
      for (final k in RegExp(r"'([A-Za-z_][\w.\$]*)'\s*:").allMatches(blk)) {
        out.add(k[1]!.split('.').first);
      }
    }
    return out;
  }

  test('규칙이 평회원에게 허락한 칸을 «규칙 파일에서» 읽어 온다', () {
    final f = File(rulesPath);
    if (!f.existsSync()) return;
    final m = RegExp(r"hasOnly\(\[([^\]]*)\]\)").allMatches(f.readAsStringSync())
        .map((x) => x[1]!)
        .firstWhere((x) => x.contains('lastRead'), orElse: () => '');
    final allowed = RegExp(r"'(\w+)'").allMatches(m).map((x) => x[1]!).toSet();
    expect(allowed, {'members', 'push', 'lastRead', 'lastSeen', 'typing'},
        reason: '평회원이 고칠 수 있는 칸이 바뀌었다 — '
            '앱의 문지기(무엇을 방장·운영진만 하게 할지)도 같이 다시 봐야 한다');
  });

  /// 앱이 모임 문서에 쓰는 «허락 밖» 칸 → 그것이 왜 괜찮은지
  ///   isAdmin  : 화면이 방장·운영진에게만 보여 준다
  ///   isSuper  : 총괄 콘솔 — 들어오는 것 자체가 문지기
  ///   join     : 규칙이 «회원이 아닌 사람»에게 열어 둔 세 갈래
  ///              (가입 신청 / 빈 방 첫 방장 / 폰 바꿔 내 자리 이어받기)
  const guarded = <String, String>{
    'lib/ui/settings.dart': 'isAdmin', // 테마·회비 금액·모임 상징
    'lib/ui/members.dart': 'isAdmin', // 승인·탈퇴·방장 자리
    'lib/ui/admin.dart': 'isSuper', // 총괄 콘솔
    'lib/ui/onboarding.dart': 'join', // 가입·이어받기
    'lib/store.dart': 'isSuper', // setClubTitle — 총괄·방장만 부른다
  };

  /* 평회원이 그대로 써도 되는 칸 (규칙이 허락한 것 + 묶음 «안쪽» 이름).
     ⚠️ `title` 은 여기 들어 있다 — 회원의 «직책»이기도 해서 최상위 칸과 구별이 안 된다.
        모임 이름을 고치는 것은 옆에 늘 붙는 `titleKey` 로 잡힌다. */
  const innocent = {
    'members', 'push', 'lastRead', 'lastSeen', 'typing',
    'uid', 'name', 'emoji', 'birth', 'role', 'title', 'joinedAt', 'photo',
    'token', 'at', 'mute', 'leftAt', 'movedTo', 'requestedAt', 'amount',
    'kind', 'rot', 'size', 'createdAt', 'isMeta',
  };

  test('허락 밖의 칸을 쓰는 파일이 «늘어나면» 알려준다', () {
    final found = <String, Set<String>>{};
    for (final f in [
      ...Directory('lib/ui').listSync().whereType<File>(),
      File('lib/store.dart'),
      File('lib/push.dart'),
      File('lib/state.dart'),
    ]) {
      final p = f.path.replaceAll(r'\', '/');
      final extra = keysWritten(bare(p)).difference(innocent);
      if (extra.isNotEmpty) found[p] = extra;
    }
    expect(found.keys.toSet(), guarded.keys.toSet(),
        reason: '모임 문서의 «허락 밖» 칸을 쓰는 곳이 달라졌다 — '
            '평회원이 닿을 수 있는 자리면 눌러도 안 되는 단추가 된다. 찾은 것: $found');
  });

  test('그 파일마다 «방장·운영진» 문지기가 있다', () {
    for (final e in guarded.entries) {
      final s = bare(e.key);
      if (e.value == 'isAdmin') {
        expect(RegExp(r'\bis(Admin|Owner)\b').hasMatch(s), isTrue,
            reason: '${e.key} 가 모임 설정을 고치면서 방장·운영진을 안 가린다');
      }
    }
  });

  test('설정 화면의 테마·회비·상징이 «운영진 안»에 들어 있다', () {
    final s = bare('lib/ui/settings.dart');
    final at = s.indexOf('if (st.isAdmin)');
    expect(at, greaterThan(0), reason: '설정 화면의 운영진 문지기가 사라졌다');
    // 문지기 «뒤»에 나와야 한다 — 앞에 있으면 평회원에게도 보인다
    for (final k in ["'theme'", "'fee'", "'emblem'"]) {
      final k2 = s.indexOf(k);
      expect(k2, greaterThan(at),
          reason: '$k 을(를) 고치는 자리가 운영진 문지기 «앞»에 있다 — '
              '평회원에게 보이면 눌러도 서버가 거절한다');
    }
  });

  test('가입 화면이 기대는 «예외 세 갈래»가 규칙에 아직 있다', () {
    final f = File(rulesPath);
    if (!f.existsSync()) return;
    final r = f.readAsStringSync();
    for (final fn in ['onlyJoining', 'claimsEmptyClub', 'claimsOwnSeat']) {
      expect(r, contains(fn),
          reason: '규칙에서 $fn 갈래가 사라졌다 — '
              '가입 화면이 쓰는 pending·former·claimFrom 이 전부 거절당한다');
    }
  });
}
