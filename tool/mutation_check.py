# -*- coding: utf-8 -*-
"""검사기가 «정말 우는지» 본다 — 소스에 일부러 흠을 내고 전체 시험을 돌린다.
   흠을 냈는데 전부 통과하면 그 자리는 «아무도 안 보고 있는» 곳이다."""
import io, os, subprocess, sys
FLUTTER = r'C:\Users\asas3\flutter\bin\flutter.bat'
ROOT = r'C:\Users\asas3\Desktop\woorimoim'

MUTS = [
  # (이름, 파일, 옛 글자, 새 글자, 잡혀야 하나)
  ('[대조] 사진 세로 줄이기 빼기', 'lib/ui/chat.dart',
   '.pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 82)',
   '.pickMultiImage(maxWidth: 1600, imageQuality: 82)', True),
  ('[대조] 회비장부 지우기 문지기 하나만', 'lib/ui/wallet.dart',
   'if (AppState.i.isTreasurer &&\n              Logic.canDeleteItem(item, Store.i.myUid))',
   'if (AppState.i.isTreasurer)', True),

  ('대화 지우기 — 남의 말도 지우게', 'lib/ui/chat.dart',
   'final canDelete = mine || AppState.i.isAdmin;',
   'final canDelete = true;', None),
  ('게시판 지우기 — 운영진 아니어도', 'lib/ui/board.dart',
   'if (mine || st.isAdmin)', 'if (true)', None),
  ('방 들어갈 때 옛 구독 안 끊기', 'lib/main.dart',
   '    Store.i.stopAll();\n    /* 방을 옮기면', '    /* 방을 옮기면', None),
  ('프로필 지울 때 방 기억 안 비우기', 'lib/state.dart',
   '    resetRoom();', '    // resetRoom();', None),
  ('대화 창 크기 200 → 3', 'lib/store.dart',
   'static const msgWindow = 200;', 'static const msgWindow = 3;', None),
  ('출석 셈에서 옛 번호 잇기 빼기(전체)', 'lib/logic.dart',
   "      final uid = liveUid(k.substring(11));\n        if (!seen.add('${e['id']}|$day|$uid')) return;",
   "      final uid = k.substring(11);\n        if (!seen.add('${e['id']}|$day|$uid')) return;", None),
  ('탈퇴 처리 때 아바타 원본 안 치우기', 'lib/ui/members.dart',
   "      Store.i.dropPhotos([m['photo'] as String?]);", '      // 안 치움', None),
  ('가입 신청을 통째로 덮어쓰기', 'lib/ui/onboarding.dart',
   "        'pending': {\n          uid: {", "        'pending2': {\n          uid: {", None),
  ('회비 기록 문서이름 고정 빼기', 'lib/ui/wallet.dart',
   '      docId: Store.feeDocId(code, uid, feeMonths.first),', '', None),
  ('돈 다듬기에서 위쪽 한도 빼기', 'lib/store.dart',
   'return (n > 0 && n <= 100000000) ? n : 0;', 'return n > 0 ? n : 0;', None),
]

def run():
    p = subprocess.run([FLUTTER, 'test'], cwd=ROOT, capture_output=True, text=True,
                       encoding='utf-8', errors='replace')
    out = (p.stdout or '') + (p.stderr or '')
    return ('All tests passed!' in out), out

results = []
for name, rel, old, new, expect in MUTS:
    path = os.path.join(ROOT, rel)
    src = io.open(path, encoding='utf-8', newline='').read()
    if src.count(old) != 1:
        results.append((name, 'SKIP', f'글자를 {src.count(old)}번 찾음'))
        print(f'SKIP  {name}  (글자를 {src.count(old)}번 찾음)', flush=True)
        continue
    io.open(path, 'w', encoding='utf-8', newline='').write(src.replace(old, new, 1))
    try:
        passed, out = run()
    finally:
        io.open(path, 'w', encoding='utf-8', newline='').write(src)
    if passed:
        results.append((name, 'SURVIVED', ''))
        print(f'!! 안 물림  {name}', flush=True)
    else:
        fails = [l.strip() for l in out.splitlines() if l.strip().startswith('C:/')]
        results.append((name, 'CAUGHT', fails[0] if fails else ''))
        print(f'   물림     {name}   ← {fails[0].split(": ")[-1] if fails else ""}', flush=True)

print('\n===== 요약 =====', flush=True)
for n, s, d in results:
    print(f'{s:9} {n}  {d}', flush=True)
