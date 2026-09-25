import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🚪 «내 자리가 없어졌다» 안내가 사실과 맞는가. (2026-09-25 조사)

   ① 내가 가입 신청을 «취소»했는데 「가입 신청이 받아들여지지 않았어요」가 떴다.
      내 쓰기가 곧바로 모임 알림을 불러, 알림 쪽이 먼저 «거절»로 판정하고 대기 화면까지 닫아 버렸다
      — 취소가 실패해도 「취소하지 못했어요」를 보여 줄 화면이 이미 없었다.
   ② 탈퇴했다가 다시 신청한 사람이 거절되면 「모임 이용이 중지됐어요」가 떴다(옛 탈퇴 기록 때문).
   ③ 내 자료를 지워도 알림이 먼저 오면 「모임 이용이 중지됐어요」가 뜰 수 있었다. */
String codeOf(String path) => File(path)
    .readAsStringSync()
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

void main() {
  final main = codeOf('lib/main.dart');

  test('스스로 떠나는 중이면 알림 쪽이 끼어들지 않는다', () {
    final gone = main.indexOf('if (!isMember) {');
    final guard = main.indexOf('if (st.leavingOnPurpose) return;', gone);
    final clear = main.indexOf('st.clearProfile();', gone);
    expect(guard, greaterThan(gone), reason: '내가 취소·삭제해도 알림 쪽이 먼저 판정한다');
    expect(guard, lessThan(clear), reason: '화면을 닫은 «뒤에» 막으면 늦다');
  });

  test('방금까지 신청 대기였으면 «거절»이다 (옛 탈퇴 기록과 상관없이)', () {
    expect(main, contains('final wasPending = _wasPending;'));
    final keep = main.indexOf('final wasPending = _wasPending;');
    final overwrite = main.indexOf('_wasPending = isPending && !isMember;');
    expect(keep, lessThan(overwrite), reason: '덮어쓴 «뒤에» 잡으면 늘 거짓이다');
    expect(main, contains('wasPending ? SeatGone.rejected : AppState.whyGone('));
  });

  for (final (file, head) in [
    ('lib/ui/wait.dart', '신청 취소'),
    ('lib/ui/settings.dart', '내 자료 지우기'),
  ]) {
    test('$head: 떠나는 동안 표시를 켜고, 실패하면 끈다', () {
      final s = codeOf(file);
      expect(s, contains('st.leavingOnPurpose = true;'), reason: '$file 이 표시를 안 켠다');
      expect('st.leavingOnPurpose = false;'.allMatches(s).length, greaterThanOrEqualTo(2),
          reason: '$file — 성공·실패 두 길 모두 표시를 꺼야 한다(안 끄면 다음 알림을 영영 무시한다)');
    });
  }
}
