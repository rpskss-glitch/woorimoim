import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 👥👥 「두 사람이 거의 같은 때에 고치면」

   모임 앱은 여럿이 같은 문서를 본다. 총무 둘이 같은 순간에 설정을 고치거나,
   방장이 회원을 임명하는 사이 다른 운영진이 다른 회원을 임명한다.

   그때 «통째로 덮어쓰면» 뒤에 쓴 사람이 앞사람의 고침을 지운다 —
   아무 표시도 없이. 그래서 이 앱은 «내가 바꾼 칸만» 보낸다.

   ⚠️ 이 시험은 코드가 그 규칙을 지키는지 본다. 실제 동시 쓰기는 서버에서 일어나므로
      여기서는 «보내는 모양»을 지킨다 — 통째로 보내면 그 순간 규칙이 깨진다. */
void main() {
  String bare(String s) => s
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//.*'), '');

  List<File> uiFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  group('모임 문서를 통째로 덮어쓰지 않는다', () {
    test('setCouple 에 «묶음 전체»를 그대로 넘기는 자리가 없다', () {
      /* `setCouple(code, couple)` 처럼 통째로 넘기면, 그 사이 남이 고친 칸이
         내가 들고 있던 옛 값으로 되돌아간다 — 아무 표시도 없이. */
      final bad = <String>[];
      for (final f in uiFiles()) {
        final code = bare(f.readAsStringSync());
        for (final m in RegExp(r'setCouple\(\s*\w+\s*,\s*(\w+)\s*\)').allMatches(code)) {
          final arg = m.group(1)!;
          // 「지금 들고 있는 모임 문서」를 그대로 넘기는 꼴
          if (arg == 'couple' || arg == 'c' || arg == 'club') {
            final line = code.substring(0, m.start).split('\n').length;
            bad.add('${f.path.replaceAll(r'\', '/')}:$line');
          }
        }
      }
      expect(bad, isEmpty,
          reason: '모임 문서를 통째로 보낸다 — 그 사이 남이 고친 칸이 옛 값으로 되돌아간다: $bad');
    });

    test('회원 하나를 고칠 때 «members 전체»를 안 보낸다', () {
      /* `{'members': {...전체...}}` 로 보내면 그 사이 승인된 새 회원이 사라진다.
         점 경로(`members.uid.role`)나 한 사람 묶음만 보내야 한다. */
      final bad = <String>[];
      for (final f in uiFiles()) {
        final code = bare(f.readAsStringSync());
        for (final m in RegExp(r"'members'\s*:\s*(\w+)").allMatches(code)) {
          final arg = m.group(1)!;
          if (arg == 'members' || arg == 'all' || arg == 'map') {
            final line = code.substring(0, m.start).split('\n').length;
            bad.add('${f.path.replaceAll(r'\', '/')}:$line');
          }
        }
      }
      expect(bad, isEmpty,
          reason: '회원 묶음을 통째로 보낸다 — 그 사이 승인된 새 회원이 사라진다: $bad');
    });
  });

  group('돈이 걸린 칸은 «내 것만» 고친다', () {
    test('회비 칸을 고칠 때 다른 회비 칸을 같이 안 보낸다', () {
      /* `fee` 는 금액·내는 날·보내는 곳이 한 묶음이다. 통째로 보내면
         남이 방금 고친 「내는 날」을 조용히 되돌린다. */
      final settings = File('lib/ui/settings.dart').readAsStringSync();
      for (final name in const ['_editAccount', '_editFee', '_editDay']) {
        final at = settings.indexOf('Future<void> $name(');
        if (at < 0) continue;
        final end = settings.indexOf('\n  Future<', at + 10);
        final body = settings.substring(at, end > 0 ? end : settings.length);
        final fields = RegExp(r"'(amount|day|account)'")
            .allMatches(body)
            .map((m) => m.group(1))
            .toSet();
        expect(fields.length, lessThanOrEqualTo(1),
            reason: '$name 이 회비 칸을 ${fields.length}개 함께 보낸다 — '
                '남이 방금 고친 칸을 되돌린다: $fields');
      }
    });
  });

  group('한 번에 두 곳을 고칠 때', () {
    test('앞이 됐는데 뒤가 실패하면 «그렇게» 말한다', () {
      /* 앞이 되고 뒤가 실패했는데 「저장하지 못했어요」라고만 하면 거짓말이다 —
         절반은 이미 바뀌었다. 회원은 다시 눌러 앞을 두 번 하게 된다. */
      final members = File('lib/ui/members.dart').readAsStringSync();
      expect(members.contains('거짓말'), isTrue,
          reason: '절반만 됐을 때를 다루는 자리가 사라졌다 (주석으로 뜻을 남겨 두었다)');
    });
  });

  group('트랜잭션이 필요한 자리', () {
    test('표(투표)는 «내 자리»만 적는다', () {
      /* 통째로 덮어쓰면 그 사이 남이 던진 표가 사라진다. */
      final store = bare(File('lib/store.dart').readAsStringSync());
      expect(store.contains('runTransaction'), isTrue,
          reason: '동시에 고쳐도 안전하게 만드는 장치가 없다');
    });

    test('회비 기록은 «같은 이름»으로 적어 두 번 안 들어가게 한다', () {
      /* 총무가 두 번 눌러도 같은 문서 이름이면 덮어쓰기라 한 건으로 남는다. */
      final store = File('lib/store.dart').readAsStringSync();
      expect(store.contains('static String feeDocId('), isTrue,
          reason: '회비 기록에 고정 이름이 없다 — 두 번 누르면 두 건이 된다');
    });
  });
}
