# -*- coding: utf-8 -*-
import io, os, subprocess
F=r'C:\Users\asas3\flutter\bin\flutter.bat'; R=r'C:\Users\asas3\Desktop\woorimoim'
CH,ST,SE,ON='lib/ui/chat.dart','lib/store.dart','lib/ui/settings.dart','lib/ui/onboarding.dart'
M=[
 ('[대조] 대화 지우기 문지기 빼기', CH, 'final canDelete = mine || AppState.i.isAdmin;', 'final canDelete = true;'),
 ('[대조] 사진 세로 줄이기 빼기', CH, '.pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 82)',
                                    '.pickMultiImage(maxWidth: 1600, imageQuality: 82)'),
 # ── 대화방 ──
 ('입력중 창 4초 → 0', CH, 'const typingWindow = 4000;', 'const typingWindow = 0;'),
 ('입력중: 나도 「입력 중」에 넣기', CH, '    if (uid == myUid || !isMember(uid)) return;', '    if (!isMember(uid)) return;'),
 ('입력중: 탈퇴한 사람도 넣기', CH, '    if (uid == myUid || !isMember(uid)) return;', '    if (uid == myUid) return;'),
 ('모르는 갈래 말풍선 안내 빼기', CH, "  return kind.isEmpty ? '' : '📄 이 앱에서는 볼 수 없는 메시지예요';", "  return '';"),
 ('말풍선 «내 것» 판정 뒤집기', CH, "    final mine = Logic.isMe(msg['by'] as String?, Store.i.myUid);",
                                  "    final mine = !Logic.isMe(msg['by'] as String?, Store.i.myUid);"),
 ('창 밖으로 밀려난 대화 안 붙들기', ST, '        final fell = fellOutOfWindow(_recent, next);\n        if (fell.isNotEmpty) _older = [..._older, ...fell];', ''),
 ('옛 대화: 지운 것 안 빼기', ST, "    if (fresh == null) return older.where((m) => m['id'] != id).toList();", '    if (fresh == null) return older;'),
 ('옛 대화: 창 안인지 안 보고 늘 서버에 묻기', ST, "    if (!_older.any((m) => m['id'] == id)) return;", ''),
 # ── 설정 ──
 ('상징: 이모지로 바꿔도 사진 번호 남기기', SE, "          'photo': kind == 'photo' ? photo : null,", "          'photo': photo,"),
 ('상징: 옛 사진 원본 안 치우기', SE, "      if (old != null && (picked != null || kind != 'photo')) {\n        Store.i.dropPhotos([old]);\n      }", ''),
 ('나가기: 알림 자리 안 비우기', SE, "                        .patchCouple(leaving, {'push.\${Store.i.myUid}': null});", '                        .patchCouple(leaving, {});'),
 ('회비 저장: 다른 칸까지 같이 보내기', SE, "        'fee': {'amount': amount}", "        'fee': {'amount': amount, 'day': null}"),
 ('내 정보 고치기: 한 칸 문 안 쓰기', SE, '          Store.memberPatch(Store.i.myUid, {', '          <String, dynamic>{'),
 # ── 가입·이어받기 ──
 ('이어받기: 누구 자리인지 안 적기', ON, "            'claimFrom': oldUid,", ''),
 ('이어받기: 옛 자리 안 지우기', ON, '              oldUid: Store.del,', ''),
 ('이어받기: 회비 주인 안 옮기기', ON, '        final moved = await Store.i.migrateFeePayer(code, oldUid, uid);',
                                    '        final moved = 0;'),
 ('이어받기: 읽음 표시 안 이어받기', ON, '        if (read is num) AppState.i.lastSeenChat = read.toInt();', ''),
 ('가입: 같은 이름·아바타 겹침 검사 빼기(회원)', ON, '      final clash = Logic.avatarClash(', '      final clash = null ?? Logic.avatarClash('),
]
def run(only=None):
    a=[F,'test']+([only] if only else [])
    p=subprocess.run(a,cwd=R,capture_output=True,text=True,encoding='utf-8',errors='replace')
    o=(p.stdout or '')+(p.stderr or ''); return ('All tests passed!' in o), o
res=[]
for name, rel, old, new in M:
    p=os.path.join(R,rel); src=io.open(p,encoding='utf-8',newline='').read()
    if src.count(old)!=1:
        print(f'SKIP      {name}  (글자를 {src.count(old)}번 찾음)', flush=True); res.append(('SKIP',name,'')); continue
    io.open(p,'w',encoding='utf-8',newline='').write(src.replace(old,new,1))
    try: ok,out=run()
    finally: io.open(p,'w',encoding='utf-8',newline='').write(src)
    if ok:
        print(f'!! 안 물림  {name}', flush=True); res.append(('SURVIVED',name,''))
    else:
        f=[l.strip() for l in out.splitlines() if l.strip().startswith('C:/')]
        d=f[0].split(': ')[-1] if f else ''
        print(f'   물림     {name}   ← {d}', flush=True); res.append(('CAUGHT',name,d))
print('\n===== 요약 =====', flush=True)
for s,n,d in res: print(f'{s:9} {n}  {d}', flush=True)
print(f"\n안 물린 것: {sum(1 for s,_,_ in res if s=='SURVIVED')} / {len(res)}", flush=True)
