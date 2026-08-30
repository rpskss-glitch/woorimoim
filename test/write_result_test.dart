// 「결과를 안 보고 됐다고 말하는 곳」이 없는지 — 이 앱에서 되풀이해 나온 병이라 상설로 지킨다.
//
// 저장·삭제가 «거절»되면 예외가 아니라 **빈 값·false** 로 온다.
// 결과를 안 보면 「저장했어요」 해놓고 아무것도 안 남는다 —
// 총무는 회비를 받은 줄 알고 넘어가고 회원은 미납으로 남는다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 값을 돌려주는 쓰기 — 이것들은 반드시 결과를 봐야 한다
const _returning = ['addItem', 'deleteItem', 'mutateItem', 'mutateCouple', 'savePhoto'];

/// 「됐다」고 말하는 표시
final _saidOk = RegExp('했어요|됐어요|지웠어요|보냈어요|올렸어요|바꿨어요');

void main() {
  test('값을 돌려주는 쓰기는 결과를 보고 나서 「됐다」고 말한다', () {
    final bad = <String>[];
    // ⚠️ 훑는 범위도 «값»이다 — 좁혀 두면 그 밖에 생긴 것을 못 잡는다 (lib 전체를 본다)
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final call = _returning.any((m) => lines[i].contains('Store.i.$m('));
        if (!call) continue;
        /* 결과를 받았나 — 같은 줄이나 바로 앞줄에 대입이 있으면 본 것으로 친다.
           ⚠️ `if (await …)` 도 **결과를 보는 것**이다. 대입만 세면
              「지운 장수를 세는」 자리가 헛되이 잡힌다(실제로 그랬다). */
        final assigned = RegExp(r'(final|var|=)\s*\w*\s*=?\s*await').hasMatch(lines[i]) ||
            RegExp(r'(if|while)\s*\(\s*!?\s*await').hasMatch(lines[i]) ||
            (i > 0 && RegExp(r'(final|var)\s+\w+\s*=\s*$').hasMatch(lines[i - 1].trim()));
        if (assigned) continue;
        /* 안 받았다면, 그 뒤 «몇 줄» 안에서 「됐다」고 말하는지 본다.
           ⚠️ 12줄로는 아슬아슬하게 놓쳤다 — 「$done장 지웠어요」처럼
              여러 줄로 나뉜 안내는 열세 번째 줄에 걸린다(미끼로 확인). */
        final after = lines.sublist(i, (i + 18).clamp(0, lines.length)).join('\n');
        if (_saidOk.hasMatch(after)) bad.add('$rel:${i + 1}');
      }
    }
    expect(bad, isEmpty,
        reason: '결과를 안 보고 「됐다」고 말한다 — 저장이 거절돼도 회원은 됐다고 믿는다: ${bad.join(', ')}');
  });

  test('총괄 콘솔이 방 목록을 «한꺼번에» 물어본다', () {
    // 차례로 물으면 방 하나마다 서버를 한 번씩 오간다 — 왕복 300ms·방 20개면 6초 넘게 흰 화면
    final src = File('lib/ui/admin.dart').readAsStringSync();
    final at = src.indexOf('Future<void> _load');
    expect(at, greaterThan(0));
    final body = src.substring(at, at + 1800);
    expect(body.contains('Future.wait'), isTrue);
  });

  test('총괄 콘솔이 «못 읽은 방»을 «없어진 방»으로 몰지 않는다', () {
    /* 잠깐 안 읽힌 방을 「없어진 방」으로 보여주면 메뉴가 「목록에서 지우기」만 남아,
       멀쩡히 쓰고 있는 방을 지워 버릴 수 있다. */
    final src = File('lib/ui/admin.dart').readAsStringSync();
    final at = src.indexOf('Future<void> _load');
    final body = src.substring(at, at + 1800);
    expect(body.contains('readFailed'), isTrue, reason: '두 경우를 갈라야 한다');
    final fail = body.indexOf('identical(d, readFailed)');
    final gone = body.indexOf("'gone': true");
    expect(fail, greaterThan(0));
    expect(fail, lessThan(gone), reason: '못 읽은 것을 «먼저» 걸러야 한다');
  });
}
