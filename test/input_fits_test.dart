import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

/* ✍️ 「앱이 적는 값은 «제 다듬기»를 그대로 통과해야 한다」.

   `Store.tidy*` 는 서버·백업에서 온 값을 화면이 못 깨뜨리게 다듬는다.
   그런데 **앱 스스로 적는 값**이 그 다듬기에 걸리면, 「저장했어요」라고 말해 놓고
   돌아온 값은 다른 것이 된다 — 회원은 왜 그런지 알 길이 없다.

   실제로 걸린 곳: 월 회비. 입력칸에 한도가 없어 1억을 넘겨 적을 수 있는데
   `Store.money` 는 그런 값을 **0**으로 만든다 → 「…원으로 정했어요」라고 말하고
   화면은 **0원 = 회비를 안 걷는 모임**이 된다.
   그러면 회원들의 밀린 달이 전부 사라지고 홈의 회비 카드도 통째로 없어진다. */
void main() {
  String bare(String p) => File(p)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  group('돈', () {
    test('흔히 쓰는 회비는 그대로 지나간다', () {
      for (final v in const [0, 10000, 20000, 50000, 200000, 100000000]) {
        expect(Store.money(v), v, reason: '$v 원이 다듬기에 걸린다');
      }
    });

    test('다듬기는 «너무 큰 값»을 0으로 만든다 — 그래서 미리 막아야 한다', () {
      expect(Store.money(100000001), 0);
      expect(Store.money(-1), 0);
    });

    test('회비를 정할 때 «다듬기가 버릴 값»은 저장하지 않는다', () {
      final s = bare('lib/ui/settings.dart');
      final at = s.indexOf('Future<void> _editFee(');
      expect(at, greaterThan(0));
      final body = s.substring(at, s.indexOf('Future<', at + 30));
      expect(body, contains('amount != Store.money(amount)'),
          reason: '한도를 안 보고 저장한다 — 「정했어요」라고 말해 놓고 '
              '회비가 0원(안 걷는 모임)이 되어 밀린 달이 전부 사라진다');
      // 막는 자리가 «저장보다 앞»이라야 한다
      expect(body.indexOf('amount != Store.money(amount)'),
          lessThan(body.indexOf('setCouple(')),
          reason: '막는 검사가 저장보다 뒤에 있다');
    });
  });

  group('글자 길이', () {
    /// 한 줄로 그리는 칸은 다듬기가 60자에서 자른다 —
    /// 입력 한도가 그보다 크면 「적었는데 잘려서 저장」되는 꼴이 된다.
    /// 아래 셋은 «여러 줄이 당연한» 글이라 예외다.
    const longOk = {4000, 2000, 500};

    test('입력 한도가 «다듬기가 자르는 길이»를 넘지 않는다', () {
      final bad = <String>[];
      for (final f in Directory('lib/ui').listSync().whereType<File>()) {
        final p = f.path.replaceAll(r'\', '/');
        for (final m in RegExp(r'maxLength:\s*(\d+)').allMatches(bare(p))) {
          final n = int.parse(m[1]!);
          if (n > Store.oneLineMax && !longOk.contains(n)) bad.add('$p → $n자');
        }
      }
      expect(bad, isEmpty,
          reason: '한 줄 칸의 입력 한도가 다듬기(${Store.oneLineMax}자)를 넘는다 — '
              '적은 대로 저장이 안 되고 조용히 잘린다: $bad');
    });

    test('가장 긴 모임 이름·회원 이름이 «잘리지 않고» 지나간다', () {
      final c = Store.tidyCouple({
        'title': '가' * 14, // 설정·콘솔의 입력 한도
        'members': {
          'u1': {'uid': 'u1', 'name': '나' * 12, 'title': '경기이사'}
        },
      })!;
      expect(c['title'], '가' * 14, reason: '모임 이름이 잘렸다');
      final me = ((c['members'] as Map)['u1'] as Map).cast<String, dynamic>();
      expect(me['name'], '나' * 12, reason: '회원 이름이 잘렸다');
    });
  });
}
