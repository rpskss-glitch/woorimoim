# -*- coding: utf-8 -*-
import io, os, subprocess
FLUTTER = r'C:\Users\asas3\flutter\bin\flutter.bat'
ROOT = r'C:\Users\asas3\Desktop\woorimoim'
L, S, A, W, C = 'lib/logic.dart', 'lib/store.dart', 'lib/ui/admin.dart', 'lib/ui/wallet.dart', 'lib/ui/calendar.dart'

MUTS = [
 ('[대조] 돈 다듬기 위쪽 한도 빼기', S, 'return (n > 0 && n <= 100000000) ? n : 0;', 'return n > 0 ? n : 0;'),
 ('[대조] 방마다 두는 값 하나 안 비우기', S, '    _hasMore = false;\n    _noMoreOlder = false;\n  }', '    _noMoreOlder = false;\n  }'),

 # ── 회비 셈 ──
 ('회비: 가입 «전» 달도 밀린 것으로', L, '      if (ym < joinedYm) continue;', ''),
 ('회비: 거슬러 보는 달 12 → 3', L, 'static List<String> unpaidMonths(String uid, {int maxBack = 12})',
                                   'static List<String> unpaidMonths(String uid, {int maxBack = 3})'),
 ('회비: 안 걷는 모임도 밀린 것으로', L, '    if (amount <= 0) return const [];', ''),
 ('회비 받기: 이미 낸 달에 또 얹기', L, '      if (paidIn(uid, key)) continue;', ''),
 ('선납: 빈 달에서 안 멈추기', L, '      if (!paidIn(uid, ymKey(nowYm + i))) break;', '      if (!paidIn(uid, ymKey(nowYm + i))) continue;'),
 ('회비 표: 나간 돈도 「낸 것」으로', L, "      if (x['kind'] != 'in') continue;", ''),
 ('회비 표: 폰 바꾼 사람 옛 기록 안 잇기', L, '      final payer = liveUid(raw);', '      final payer = raw;'),

 # ── 일정 반복 ──
 ('매달 모임: 31일이 영영 밀리게', L, '        return _monthsAfter(start, n);',
                                    '        return DateTime(start.year, start.month + n, start.day);'),
 ('반복: 끝나는 날을 안 보기', L, '      if (until != null && cur.isAfter(until)) break;', ''),
 ('한 번뿐인 먼 모임: 20년 → 400일', L, '          ? DateTime(now.year + 20, now.month, now.day)',
                                       '          ? now.add(const Duration(days: 400))'),
 ('출석: true 아닌 값도 출석으로', L, "        if (v != true || k.length < 12) return;", '        if (k.length < 12) return;'),

 # ── 총괄 콘솔 ──
 ('콘솔: 방 만들 때 «끝난 것 확인» 빼기', A, '      }, true);', '      });'),
 ('콘솔: 목록에 못 적어도 되돌리지 않기', A, '          await Store.i.deleteCouple(code);\n        } catch (_) {', '        } catch (_) {'),
 ('콘솔: 못 읽은 방을 «없어진 방»으로', A, '      if (identical(d, readFailed)) {', '      if (false) {'),
 ('콘솔: 방장 자리 표시 안 남기기', A, "          'ownerReleased': DateTime.now().millisecondsSinceEpoch,", ''),
 ('콘솔: 기록보다 방 문서를 먼저 지우기', A, '      final n = await Store.i.purgeClubData(', '      await Store.i.deleteCouple(code);\n      final n = await Store.i.purgeClubData('),

 # ── 그 밖 ──
 ('답 기다리는 시간 6초 → 0', S, 'static const _settleWait = Duration(seconds: 6);', 'static const _settleWait = Duration(seconds: 0);'),
 ('지우기 권한: 운영진 → 방장만', L, '    return AppState.i.isAdmin;\n  }', '    return AppState.i.isOwner;\n  }'),
 ('회비 기록에 「어느 달치」 안 적기', W, "        'feeMonths': feeMonths,", ''),
 ('일정 만들 때 반복 주기 안 적기', C, "      'repeat': _repeat,", ''),
]

def run():
    p = subprocess.run([FLUTTER, 'test'], cwd=ROOT, capture_output=True, text=True,
                       encoding='utf-8', errors='replace')
    out = (p.stdout or '') + (p.stderr or '')
    return ('All tests passed!' in out), out

res = []
for name, rel, old, new in MUTS:
    path = os.path.join(ROOT, rel)
    src = io.open(path, encoding='utf-8', newline='').read()
    if src.count(old) != 1:
        res.append(('SKIP', name, f'글자를 {src.count(old)}번 찾음'))
        print(f'SKIP      {name}  (글자를 {src.count(old)}번 찾음)', flush=True)
        continue
    io.open(path, 'w', encoding='utf-8', newline='').write(src.replace(old, new, 1))
    try:
        ok, out = run()
    finally:
        io.open(path, 'w', encoding='utf-8', newline='').write(src)
    if ok:
        res.append(('SURVIVED', name, ''))
        print(f'!! 안 물림  {name}', flush=True)
    else:
        f = [l.strip() for l in out.splitlines() if l.strip().startswith('C:/')]
        d = f[0].split(': ')[-1] if f else ''
        res.append(('CAUGHT', name, d))
        print(f'   물림     {name}   ← {d}', flush=True)

print('\n===== 요약 =====', flush=True)
for s, n, d in res:
    print(f'{s:9} {n}  {d}', flush=True)
print(f"\n안 물린 것: {sum(1 for s,_,_ in res if s=='SURVIVED')} / {len(res)}", flush=True)
