import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* ⏳ 「기다린 «뒤»에 화면을 고칠 때는 아직 그 화면이 있는지 본다」.

   사진 올리기·방 지우기처럼 **수십 초 걸리는 일**은 도중에 회원이 화면을 닫을 수 있다.
   그때 `setState` 를 그냥 부르면 Flutter 가 «없어진 화면을 고치려 한다»며 터진다.
   ⚠️ 분석기는 `BuildContext` 만 보고 **`setState` 는 안 본다** — 아무도 안 잡는다(182회차에 확인).

   ※ 「기다림 뒤의 모든 setState」를 기계로 훑어 보려 했으나,
     `build()` 안의 «누르는 순간» 손잡이(`onPressed: () => setState(…)`)까지 함께 걸려
     거짓 지적이 너무 많았다. 그래서 **오래 걸리는 자리만 콕 집어** 못 박는다. */
void main() {
  String bare(String p) => File(p)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  test('사진 여러 장 올리기 — 진행 표시와 되살리기 둘 다 «화면이 있는지» 본다', () {
    final s = bare('lib/ui/board.dart');
    expect(s, contains('if (mounted) setState(() => _upDone'),
        reason: '올리는 도중 화면을 닫으면 터진다');
    expect(s, contains('if (mounted) setState(() => _upBusy = false)'),
        reason: '끝내고 단추를 되살릴 때도 화면이 없을 수 있다');
  });

  test('방 지우기 — 시작·진행·끝 «세 자리 모두» 본다', () {
    final s = bare('lib/ui/admin.dart');
    final at = s.indexOf('Future<void> _delete(String code');
    expect(at, greaterThan(0), reason: '방 지우기를 못 찾았다 — 이 시험이 헛돌고 있다');
    final body = s.substring(at, s.indexOf('Future<', at + 30));
    // 시작: 물어보는 «사이»에 콘솔을 닫았을 수 있다
    /* ⚠️ 「앞에 있나」만 보면 안 된다 — 못 찾으면 -1 이라 «늘 앞»이 되어 통과한다
       (182회차에 그렇게 틀렸다). 있는지부터 본다. */
    final guard = body.indexOf('if (!mounted) return;');
    final start = body.indexOf("_busyText = '기록을 지우는 중…'");
    expect(guard, greaterThan(0), reason: '물어본 뒤 화면이 있는지 아예 안 본다');
    expect(start, greaterThan(0));
    expect(guard, lessThan(start),
        reason: '물어본 뒤 바로 화면을 고친다 — 그 사이 콘솔을 닫았으면 터진다');
    // 진행·끝
    expect(body, contains("if (mounted) setState(() => _busyText = '기록을 지우는 중… "),
        reason: '지우는 동안 진행을 알리다가 터진다');
    expect(body, contains('if (mounted) setState(() => _busyText = null)'),
        reason: '끝내고 표시를 지울 때도 화면이 없을 수 있다');
  });

  test('그 막이가 «기다림 뒤»에 있다 — 앞에 두면 뜻이 없다', () {
    /* 기다리기 «전»에 본 `mounted` 는 아무것도 안 지킨다 — 기다리는 동안 닫히기 때문이다. */
    final s = bare('lib/ui/board.dart');
    final at = s.indexOf('Future<void> _addPhotos(');
    final body = s.substring(at, s.indexOf('\n  }\n', at));
    final firstAwait = body.indexOf('await ');
    expect(firstAwait, greaterThan(0));
    expect(body.indexOf('if (mounted) setState(() => _upDone'), greaterThan(firstAwait),
        reason: '진행 표시가 기다림보다 «앞»에 있다 — 그러면 지킬 것이 없다');
  });
}
