import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

/* 🕳 「아무도 안 보고 있던 자리」 세 곳.

   166회차에 소스에 일부러 흠을 내고 시험 전체를 돌려 봤다(12군데).
   9곳은 물렸는데 **3곳은 흠을 내도 674개가 전부 통과**했다 — 여기가 그 셋이다. */
void main() {
  String bare(String p) => File(p)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  String bodyOf(String src, String decl) {
    final at = src.indexOf(decl);
    if (at < 0) return '';
    var i = src.indexOf('(', at), d = 0;
    for (; i < src.length; i++) {
      if (src[i] == '(') d++;
      if (src[i] == ')') { d--; if (d == 0) break; }
    }
    final open = src.indexOf('{', i);
    d = 0;
    for (var j = open; j < src.length; j++) {
      if (src[j] == '{') d++;
      if (src[j] == '}') { d--; if (d == 0) return src.substring(open, j + 1); }
    }
    return '';
  }

  group('① 방에 들어갈 때 «옛 방의 것»을 먼저 비운다', () {
    test('구독을 걸기 «전»에 비운다', () {
      final body = bodyOf(bare('lib/main.dart'), 'void _enter()');
      expect(body, isNotEmpty, reason: '_enter 를 못 찾았다 — 이 시험이 헛돌고 있다');
      final clear = body.indexOf('Store.i.stopAll()');
      final sub = body.indexOf('Store.i.subCouple(');
      expect(clear, greaterThan(0),
          reason: '방에 들어가면서 옛 방의 것을 안 비운다 — '
              '첫 스냅샷이 오기 전까지 «옛 방의 대화»가 새 방에 그대로 보이고, '
              '「더 보기」 단추도 옛 방의 값으로 떠 있다가 눌러도 헛걸음이 된다');
      expect(sub, greaterThan(clear), reason: '비우기가 구독보다 «뒤»에 있다');
    });

    test('비울 때 «방마다 두는 값»을 하나도 안 빠뜨린다', () {
      final s = bare('lib/store.dart');
      final body = bodyOf(s, 'void stopAll()');
      /* 방 하나치로 들고 있는 값 — 새로 생기면 여기도 같이 비워야 한다.
         하나만 남아도 옛 방의 것이 새 방에 비친다(133·151회차와 같은 갈래). */
      for (final f in const [
        '_coupleSub', '_itemsSub', '_msgsSub', '_itemsCb',
        '_core', '_recent', '_older', '_curRecent', '_curOlder',
        '_hasMore', '_noMoreOlder',
      ]) {
        expect(body, contains(f), reason: '방을 옮길 때 $f 를 안 비운다');
      }
    });

    test('«새로 생긴» 방마다 두는 값이 있으면 알려준다', () {
      final s = bare('lib/store.dart');
      // 구독 언저리에 선언된 방 하나치 값들 — 개수가 달라지면 위 목록을 손봐야 한다
      final zone = s.substring(s.indexOf('StreamSubscription? _coupleSub'),
          s.indexOf('void subItems('));
      final names = RegExp(r'\b(_[a-zA-Z]\w*)\s*(?:=|,|;)')
          .allMatches(zone)
          .map((m) => m[1]!)
          .toSet();
      expect(names.length, lessThanOrEqualTo(12),
          reason: '방마다 두는 값이 늘었다 — stopAll 에서도 비우는지 보고 위 목록에 적어라: $names');
    });
  });

  group('② 대화 창 크기', () {
    test('터무니없는 값이 아니다', () {
      expect(Store.msgWindow, greaterThanOrEqualTo(50),
          reason: '창이 너무 작으면 방에 들어갈 때마다 「더 보기」를 눌러야 한다');
      expect(Store.msgWindow, lessThanOrEqualTo(500),
          reason: '창이 너무 크면 방에 들어갈 때마다 그만큼 읽기 요금이 나간다');
    });

    test('웹과 «같은 크기»다 — 두 회원이 같은 만큼 본다', () {
      final f = File('../앞산배드민턴/index.html');
      if (!f.existsSync()) return;
      final m = RegExp(r'MSG_WINDOW\s*[:=]\s*(\d+)').firstMatch(f.readAsStringSync());
      expect(m, isNotNull, reason: '웹의 대화 창 크기를 못 찾았다');
      expect(int.parse(m![1]!), Store.msgWindow,
          reason: '앱과 웹이 다른 만큼 거슬러 본다 — '
              '한쪽 회원만 옛 대화가 안 보여 「내 말이 지워졌나」로 읽힌다');
    });
  });

  group('③ 가입 신청이 «서버가 받아 주는 모양»으로 나간다', () {
    /* 규칙(firestore.rules)의 onlyJoining 은 «신청 칸만» 건드릴 때만 허락한다:
         affectedKeys().hasOnly(['pending'])
       그래서 최상위 칸 이름이 하나라도 더 붙으면 **가입 자체가 거절된다.** */
    late String call;

    setUpAll(() {
      final s = bare('lib/ui/onboarding.dart');
      final at = s.lastIndexOf("'pending': {");
      expect(at, greaterThan(0), reason: '가입 신청을 적는 곳을 못 찾았다');
      // 그 setCouple 부름만 괄호를 맞춰 떼어낸다
      var open = s.lastIndexOf('setCouple(', at);
      var depth = 0, i = open + 'setCouple'.length;
      for (; i < s.length; i++) {
        if (s[i] == '(') depth++;
        if (s[i] == ')') { depth--; if (depth == 0) break; }
      }
      call = s.substring(open, i);
    });

    test('최상위 칸은 「신청」 하나뿐이다', () {
      /* ⚠️ 줄 단위로 `'칸':` 을 세면 «묶음 안쪽» 이름까지 걸린다(처음에 그렇게 틀렸다).
         중괄호 깊이를 세어 **바깥 한 겹**의 이름만 모은다. */
      final open = call.indexOf('{');
      final top = <String>{};
      var depth = 0;
      for (var i = open; i < call.length; i++) {
        final c = call[i];
        if (c == '{') depth++;
        if (c == '}') depth--;
        if (depth == 1 && c == "'") {
          final end = call.indexOf("'", i + 1);
          if (end > 0 && end + 1 < call.length) {
            final after = call.substring(end + 1).trimLeft();
            if (after.startsWith(':')) top.add(call.substring(i + 1, end));
          }
          i = end;
        }
      }
      expect(top, {'pending'},
          reason: '가입 신청에 다른 칸이 섞였다 — 서버 규칙이 «신청 칸만» 허락하므로 '
              '가입이 통째로 거절된다. 찾은 것: $top');
    });

    test('신청서에 «폰을 바꿔도 이어받을» 값이 들어 있다', () {
      for (final k in const ['name', 'emoji', 'uid', 'birth', 'requestedAt']) {
        expect(call, contains("'$k'"),
            reason: '신청서에 $k 가 빠졌다 — '
                '이름·생년월일이 없으면 폰을 바꿀 때 제 자리를 못 찾고, '
                '신청 시각이 없으면 방장 화면에서 차례가 뒤죽박죽이 된다');
      }
    });
  });
}
