# -*- coding: utf-8 -*-
"""흔들기 — 분석기를 «먼저» 돌려 잡히면 시험을 건너뛴다(빠르다).
   씨앗(seed)을 바꿔 가며 돌리면 매 회차 다른 자리를 볼 수 있다."""
import io, os, re, sys, glob, subprocess, random
F = r'C:\Users\asas3\flutter\bin\flutter.bat'
R = r'C:\Users\asas3\Desktop\woorimoim'
ISSUE = re.compile(r'^\s*(?:error|warning|info) - ', re.M)

def issues(out):
    """분석기가 «몇 개»를 말했는지 — 줄을 «정확히» 센다.
       ⚠️ 예전에는 ' - ' 를 세었는데 **한 줄에 두 번씩** 나온다
          (설명 안에도 있다) → 무엇이든 「분석기가 잡았다」로 나왔다(182회차)."""
    return len(ISSUE.findall(out))
CALL = re.compile(r'(Store\.i\.|AppState\.i\.|Push\.i\.|setState\(|Navigator\.|toast\()')
GUARD = re.compile(r'^\s*if \([^()]*(?:\([^()]*\))?[^()]*\)\s*return\b[^;]*;\s*$')
DFLT = re.compile(r"\?\?\s*(0\b|1\b|true\b|false\b|''|'[^']{1,12}')")

def flip(lit):
    """기본값을 «같은 갈래의 다른 값»으로 바꾼다 — 그 기본값이 정말 쓰이는지 본다."""
    if lit == '0': return '-77'
    if lit == '1': return '-77'
    if lit == 'true': return 'false'
    if lit == 'false': return 'true'
    if lit == "''": return "'ZZ'"
    return "'ZZ'"

COND1 = re.compile(r'^(\s*)if \(([^()]*(?:\([^()]*\))?[^()]*)\)\s+(\S.*;)\s*$')

def candidates():
    out = []
    for f in sorted(glob.glob('lib/**/*.dart', recursive=True)):
        lines = io.open(f, encoding='utf-8').read().split('\n')
        for i, l in enumerate(lines):
            t = l.strip()
            if t.startswith('//') or t.startswith('*'):
                continue
            if GUARD.match(l):
                out.append((f, i, 'guard-drop', t[:58]))
                if i + 1 < len(lines) and CALL.search(lines[i + 1]) and lines[i + 1].strip().endswith(';'):
                    out.append((f, i, 'swap', t[:30] + ' <-> ' + lines[i + 1].strip()[:30]))
            for d in DFLT.finditer(l):
                out.append((f, i, 'default:' + d.group(1), t[:58]))
            m = COND1.match(l)
            if m and CALL.search(m.group(3)) and 'return' not in m.group(3):
                out.append((f, i, 'cond-strip', t[:58]))
    return out

def apply(f, i, kind):
    lines = io.open(f, encoding='utf-8', newline='').read().split('\n')
    if kind.startswith('default:'):
        lit = kind.split(':', 1)[1]
        lines[i] = lines[i].replace('?? ' + lit, '?? ' + flip(lit), 1)
    elif kind == 'guard-drop':
        lines[i] = ''
    elif kind == 'swap':
        lines[i], lines[i + 1] = lines[i + 1], lines[i]
    else:
        m = COND1.match(lines[i])
        lines[i] = m.group(1) + m.group(3)
    io.open(f, 'w', encoding='utf-8', newline='').write('\n'.join(lines))

def run(cmd):
    p = subprocess.run([F] + cmd, cwd=R, capture_output=True, text=True,
                       encoding='utf-8', errors='replace')
    return (p.stdout or '') + (p.stderr or '')

if __name__ == '__main__':
    seed = int(sys.argv[1]); n = int(sys.argv[2])
    base = issues(run(['analyze']))   # «흠을 내기 전» 개수를 재 둔다 — 박아 두면 어긋난다
    print('바탕 분석기 지적: ' + str(base) + '개', flush=True)
    cands = candidates()
    random.seed(seed)
    pick = random.sample(cands, min(n, len(cands)))
    for f, i, kind, desc in pick:
        src = io.open(f, encoding='utf-8', newline='').read()
        try:
            apply(f, i, kind)
            a = run(['analyze'])
            if 'error -' in a:
                mark = '(안 세움)'
            elif issues(a) > base:
                mark = '   물림(분석기)'
            else:
                o = run(['test'])
                mark = '!! 안 물림' if 'All tests passed!' in o else '   물림(시험)  '
        finally:
            io.open(f, 'w', encoding='utf-8', newline='').write(src)
        name = f.replace(chr(92), '/').split('/')[-1]
        print(mark.ljust(16) + kind.ljust(11) + name.ljust(16) + str(i + 1).rjust(4) + '  ' + desc, flush=True)
