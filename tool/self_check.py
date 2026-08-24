# -*- coding: utf-8 -*-
import io, re, glob, os
LIB = re.compile(r'\b(Logic|Store|Push|AppState|Cfg)\.(\w+)')
QUOTES = set(list(chr(39) + chr(34)))

def args_of(src, at):
    d = 0; i = at; parts = []; cur = []; instr = None
    while i < len(src):
        c = src[i]
        if instr is not None:
            cur.append(c)
            if c == chr(92):
                i += 1
                if i < len(src): cur.append(src[i])
            elif c == instr:
                instr = None
            i += 1; continue
        if c in QUOTES:
            instr = c; cur.append(c); i += 1; continue
        if c in '([{':
            d += 1
            if d > 1: cur.append(c)
            i += 1; continue
        if c in ')]}':
            d -= 1
            if d == 0:
                parts.append(''.join(cur)); return parts
            cur.append(c); i += 1; continue
        if c == ',' and d == 1:
            parts.append(''.join(cur)); cur = []; i += 1; continue
        cur.append(c); i += 1
    return parts

SKIP_B = {'isTrue','isFalse','isNull','isNotNull','isEmpty','isNotEmpty'}
hits = []
for f in sorted(glob.glob('test/*.dart')):
    s = io.open(f, encoding='utf-8').read()
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    s = re.sub(r'//.*', '', s)
    for m in re.finditer(r'\bexpect\s*\(', s):
        parts = args_of(s, m.end() - 1)
        if len(parts) < 2: continue
        a = ' '.join(parts[0].split()); b = ' '.join(parts[1].split())
        if not a or not b or b.startswith('reason:'): continue
        if a == b:
            hits.append((f, 'AA 똑같은 식', a[:70])); continue
        sa = set(LIB.findall(a)); sb = set(LIB.findall(b))
        common = sa & sb
        if common and b not in SKIP_B and not b[0].isdigit():
            names = ','.join(x + '.' + y for x, y in sorted(common))
            hits.append((f, '양쪽에 같은 이름', a[:44] + '  <->  ' + b[:44] + '  [' + names + ']'))

print('찾은 자리: ' + str(len(hits)) + '\n')
for f, why, d in hits:
    print(os.path.basename(f).ljust(26) + why.ljust(18) + d)
