import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';

/* 방장이 없어진 방을 되살리는 길.
   서버 규칙은 «자리가 열려 있을 때»(ownerReleased)만 회원이 스스로 방장이 되게 허락한다.
   그런데 화면은 「방장이 없다」만 보고 단추를 띄웠고, 총괄의 「방장 해제」는
   방장이 이미 없으면 **아무것도 안 하고 돌아갔다.**
   → 그 방은 방장을 다시 세울 길이 영영 없었다(눌러도 「맡지 못했어요」만 나온다). */

const _rules = r'C:\Users\asas3\Desktop\데이트장부\firestore.rules';

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

String blockAt(String src, int from) {
  final open = src.indexOf('{', from);
  if (open < 0) return '';
  var d = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '{') d++;
    if (src[i] == '}') {
      d--;
      if (d == 0) return src.substring(from, i + 1);
    }
  }
  return src.substring(from);
}

void main() {
  const me = 'u1';

  test('자리가 열려 있으면 맡을 수 있다', () {
    expect(
        Logic.canClaimOwner({
          'ownerReleased': 123,
          'members': {
            me: {'role': 'member'}
          }
        }, me),
        isTrue);
  });

  test('자리가 안 열렸으면 못 맡는다 — 단추를 띄우면 안 된다', () {
    expect(
        Logic.canClaimOwner({
          'members': {
            me: {'role': 'member'}
          }
        }, me),
        isFalse);
    expect(
        Logic.canClaimOwner({
          'members': {
            me: {'role': 'admin'} // 운영진이어도 못 맡는다 (규칙이 그렇다)
          }
        }, me),
        isFalse);
  });

  test('원래 방장이면 그대로 둘 수 있다', () {
    expect(
        Logic.canClaimOwner({
          'members': {
            me: {'role': 'owner'}
          }
        }, me),
        isTrue);
  });

  test('모임 문서가 아직 안 왔으면 못 맡는다', () {
    expect(Logic.canClaimOwner(null, me), isFalse);
  });

  test('앱의 조건이 서버 규칙과 같은 것을 본다', () {
    final f = File(_rules);
    if (!f.existsSync()) {
      markTestSkipped('규칙 파일이 없는 기기 — 앱 쪽 조건만 확인했다');
      return;
    }
    final r = stripComments(f.readAsStringSync());
    // 스스로 방장이 되는 문은 둘뿐이다: 원래 방장이었거나, 자리가 열렸거나
    final body = blockAt(r, r.indexOf('function notSelfPromotingToOwner()'));
    expect(body.contains('wasOwner()'), isTrue);
    expect(body.contains('ownerSeatOpen()'), isTrue);
    // 「자리가 열렸다」는 곧 ownerReleased 가 문서에 있다는 뜻
    final seat = blockAt(r, r.indexOf('function ownerSeatOpen()'));
    expect(seat.contains('ownerReleased'), isTrue,
        reason: '서버가 보는 표시 이름이 바뀌었다 — Logic.canClaimOwner 도 같이 고쳐야 한다');
  });

  test('회원 화면은 맡을 수 있을 때만 단추를 띄운다', () {
    final code = stripComments(File('lib/ui/members.dart').readAsStringSync());
    expect(code.contains('Logic.canClaimOwner('), isTrue);
    final at = code.indexOf("'내가 방장 맡기'");
    expect(at, greaterThan(0));
    expect(code.substring(0, at).contains('if (canClaim)'), isTrue,
        reason: '조건 없이 띄우면 눌러도 안 되는 죽은 단추가 된다');
  });

  test('총괄은 «방장이 없는» 방도 열 수 있다', () {
    final code = stripComments(File('lib/ui/admin.dart').readAsStringSync());
    final body = blockAt(code, code.indexOf('_releaseOwner(String code'));
    expect(body.contains('ownerReleased'), isTrue);
    expect(body.contains('if (owner == null) return null'), isFalse,
        reason: '방장이 없다고 그냥 돌아가면 그 방은 방장을 다시 세울 길이 없다');
  });
}
