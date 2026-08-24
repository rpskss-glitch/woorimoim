// «거절되면 던지는» 서버 쓰기가 받아 주는 곳 없이 남아 있지 않은지.
//
// Store 의 쓰기는 두 갈래다:
//  · 값을 돌려주는 것 (addItem·deleteItem·savePhoto…) → 부르는 쪽이 결과를 보면 된다
//  · **던지는 것** (setCouple·patchCouple·updateItem·mutateItem·mutateCouple)
//    → 받지 않으면 오류가 그대로 새어 나가, 화면은 «아무 말도 없이» 끝난다.
//      회원 눈에는 «눌렀는데 아무 일도 안 일어나는 단추»로 보인다.
//
// 47·75·76회차에 이 갈래를 하나씩 찾았다(참석 투표 / 알림 준비 / 알림 범위) — 그래서 기계로 막는다.
//
// 부르는 쪽이 감싸는 경우(예: onboarding 의 _doJoin 은 _join 이 받는다)는
// 글로는 알 수 없으니 그 자리에 «감싸짐: 누가» 라고 적어 두면 넘어간다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 거절되면 «던지는» 쓰기.
const _throwing = ['setCouple', 'patchCouple', 'updateItem', 'mutateItem', 'mutateCouple'];

/// 거절되면 «던지는» 읽기. (`getPhoto` 는 안에서 다 받아내므로 여기 없다 — 81회차 실측)
const _throwingReads = ['getCouple', 'findClubByTitle', 'purgeClubData'];

/// 줄마다 «그 줄이 끝났을 때의 괄호 깊이».
List<int> _depths(List<String> lines) {
  var d = 0;
  return [
    for (final l in lines) ...[
      () {
        final code = l.replaceAll(RegExp(r"'[^']*'"), '').split('//').first;
        for (final ch in code.split('')) {
          if (ch == '{') d++;
          if (ch == '}') d--;
        }
        return d;
      }()
    ]
  ];
}

/// at 줄이 «try 덩어리 안»에 있는가 — 괄호를 실제로 세어 판단한다.
bool _insideTry(List<String> lines, List<int> depth, int at) {
  for (var j = at - 1; j >= 0; j--) {
    if (!lines[j].contains('try {')) continue;
    final inner = depth[j]; // try 를 연 뒤의 깊이
    // j+1 부터 at 까지 깊이가 한 번도 inner 밑으로 안 내려갔다면 아직 그 안이다
    var still = true;
    for (var k = j + 1; k <= at; k++) {
      if (depth[k] < inner) {
        still = false;
        break;
      }
    }
    if (still) return true;
  }
  return false;
}

/// 이름이 who 인 함수의 «몸통» — 여는 괄호부터 짝이 맞는 닫는 괄호까지.
String _bodyOf(String src, String who) {
  final at = src.indexOf('$who(');
  if (at < 0) return '';
  /* ⚠️ 곧바로 다음 «{» 를 잡으면 안 된다 — `_join({bool loginOnly = false})` 처럼
     **이름 있는 인자 괄호**가 먼저 나오면 그것을 본문으로 착각해,
     try 로 잘 받고 있는 함수도 「안 받는다」고 잘못 일러바친다.
     먼저 서명의 «)» 를 찾아 넘긴 뒤 본문 «{» 를 잡는다. */
  var d0 = 0, sig = at;
  for (var i = src.indexOf('(', at); i < src.length; i++) {
    if (src[i] == '(') d0++;
    if (src[i] == ')') {
      d0--;
      if (d0 == 0) { sig = i; break; }
    }
  }
  final open = src.indexOf('{', sig);
  if (open < 0) return '';
  var d = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '{') d++;
    if (src[i] == '}') {
      d--;
      if (d == 0) return src.substring(open, i);
    }
  }
  return src.substring(open);
}

void main() {
  test('던지는 쓰기·읽기는 모두 «받아 주는 곳» 안에 있다', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('store.dart')) continue; // 여기가 그 함수들을 «만드는» 곳이다
      final name = f.path.split(RegExp(r'[\/]')).last;
      final lines = f.readAsLinesSync();
      final depth = _depths(lines);

      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        final risky = [..._throwing, ..._throwingReads]
            .any((w) => l.contains('Store.i.$w('));
        if (!risky) continue;
        if (_insideTry(lines, depth, i)) continue;
        // 부르는 쪽이 받아 준다고 적어 둔 자리
        final above = lines.sublist((i - 6).clamp(0, i), i).join('\n');
        if (above.contains('감싸짐:')) continue;
        // `.catchError` 로 받는 방식도 인정한다
        final near = lines.sublist(i, (i + 6).clamp(0, lines.length)).join('\n');
        if (near.contains('.catchError')) continue;
        bad.add('$name:${i + 1}  ${l.trim()}');
      }
    }
    expect(bad, isEmpty,
        reason: '거절되면 오류가 새어 나가 «아무 말도 없이» 끝난다:\n  ${bad.join('\n  ')}');
  });

  test('«감싸짐:» 이라고 적은 자리는 정말로 감싸는 사람이 있다', () {
    // 적어만 두고 실제로는 안 받으면 검사기가 헛돈다 — 적힌 함수 이름이 파일에 있는지 본다.
    final mark = RegExp(r'감싸짐:\s*(\w+)');
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in mark.allMatches(src)) {
        final who = m.group(1)!;
        expect(src.contains('$who('), isTrue,
            reason: '${f.path} — «$who» 라는 함수가 없다');
        expect(_bodyOf(src, who).contains('try {'), isTrue,
            reason: '${f.path} — «$who» 가 try 로 받지 않는다');
      }
    }
  });

  test('알림 범위 바꾸기가 «됐는지»를 돌려주고, 화면이 그것을 본다', () {
    final push = File('lib/push.dart').readAsStringSync();
    expect(push.contains('Future<bool> setMode('), isTrue,
        reason: '못 바꿨는데 바뀐 것처럼 보이면 안 된다');
    final settings = File('lib/ui/settings.dart').readAsStringSync();
    final at = settings.indexOf('Push.i.setMode(');
    expect(at, greaterThan(0));
    expect(settings.substring(at, at + 400).contains('바꾸지 못했어요'), isTrue,
        reason: '실패를 회원에게 알려야 한다');
  });

  /* 총괄 콘솔은 목록을 못 읽으면 «도는 표시»가 참인 채로 남아
     앱을 죽이는 것 말고는 빠져나올 길이 없었다 (81회차). */
  test('총괄 콘솔은 목록을 못 읽어도 빠져나올 길이 있다', () {
    final src = File('lib/ui/admin.dart').readAsStringSync();
    expect(src.contains('_loadErr'), isTrue, reason: '못 읽었다는 것을 담아 둘 자리가 없다');
    expect(src.contains('다시 시도'), isTrue, reason: '다시 해볼 길이 없으면 앱을 죽여야 한다');
    final at = src.indexOf('Future<void> _load()');
    final body = src.substring(at, src.indexOf('\n  }\n', at));
    expect(body.contains('_loading = false'), isTrue,
        reason: '실패한 자리에서 도는 표시를 반드시 내려야 한다');
  });
}
