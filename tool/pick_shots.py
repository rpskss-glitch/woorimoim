"""📸 찍어 둔 그림 더미에서 «화면마다 한 장»을 골라낸다.

앱은 12초마다 탭을 넘기고, 워크플로는 2초마다 계속 찍는다.
이어지는 «똑같은 그림»은 한 화면에 머문 구간이다. 구간마다 가운데 한 장을 고르면
시각을 맞추지 않고도 다섯 화면이 정확히 한 장씩 나온다.

⚠️ 시각을 맞추는 방식(「25초에 홈, 35초에 대화」)은 쓰지 않는다 —
   앱이 서는 시간이 판마다 달라 몇 초만 어긋나면 같은 화면이 두 장 찍힌다.
"""
import hashlib
import os
import shutil

RAW, OUT = 'raw', 'shots'
NAMES = ['01_home', '02_chat', '03_calendar', '04_wallet', '05_board']

runs, prev = [], None
for f in sorted(os.listdir(RAW)):
    h = hashlib.md5(open(os.path.join(RAW, f), 'rb').read()).hexdigest()
    if h == prev:
        runs[-1].append(f)
    else:
        runs.append([f])
        prev = h

print('머문 구간 길이:', [len(r) for r in runs])
# 두 장 미만은 «넘어가는 중»(움직이는 그림)이라 버린다
runs = [r for r in runs if len(r) >= 2]
print('쓸 만한 구간:', len(runs))

# 앞쪽에 «가입 화면·첫 그리기» 같은 군더더기가 있을 수 있으니 뒤에서 다섯 덩이를 쓴다
picked = runs[-len(NAMES):] if len(runs) >= len(NAMES) else runs
os.makedirs(OUT, exist_ok=True)
for name, r in zip(NAMES, picked):
    shutil.copy(os.path.join(RAW, r[len(r) // 2]), os.path.join(OUT, name + '.png'))
print('고른 것:', sorted(os.listdir(OUT)))
