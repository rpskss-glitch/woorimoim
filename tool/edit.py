"""Dart 파일을 안전하게 고치는 도구.

왜 필요한가: 이 프로젝트의 Dart 파일은 줄 끝이 CRLF다.
파이썬으로 여러 줄 문자열을 넣을 때 `\n`이 **진짜 줄바꿈**으로 들어가
Dart 문자열이 깨진다(점검 루프에서 회차마다 되풀이해 겪었다).

쓰는 법:
    import sys; sys.path.insert(0, 'tool')
    from edit import patch, NL
    patch('lib/ui/x.dart', [(옛것, 새것)])

새것 안에서 Dart 문자열의 줄바꿈이 필요하면 NL 을 이어 붙인다.
"""
import io

NL = "\\" + "n"   # Dart 소스에 들어갈 두 글자 (진짜 줄바꿈이 아니다)


def patch(path, pairs):
    s = io.open(path, encoding='utf-8', newline='').read()
    for old, new in pairs:
        if old not in s:
            raise SystemExit('%s: 못 찾음 -> %s' % (path, old[:70]))
        s = s.replace(old, new, 1)
    _check(path, s)
    io.open(path, 'w', encoding='utf-8', newline='').write(s)
    print(path, 'OK')


def _check(path, s):
    """따옴표가 한 줄 안에서 안 닫힌 곳을 미리 잡는다 (문자열이 깨진 채 저장되는 것 방지)."""
    for n, line in enumerate(s.split('\n'), 1):
        t = line.rstrip('\r')
        if t.lstrip().startswith('//') or "r'" in t or 'r"' in t:
            continue
        if t.count("'") % 2 == 1 and not t.rstrip().endswith("'"):
            raise SystemExit('%s:%d 따옴표가 안 닫혔다 -> %s' % (path, n, t.strip()[:60]))
