import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 💰 직책은 됐는데 권한 주기가 실패했을 때의 안내가 거짓말을 했다 (2026-09-26 89회차).

   「(이 직책만으로도 회비 장부는 열려요)」를 직책과 상관없이 붙였다 — 부회장·경기이사처럼
   회비 장부를 «안» 여는 직책에도. 방장은 그 사람이 회비를 다룰 수 있다고 잘못 안다.
   회비를 여는 직책(Logic.keepsMoneyByTitle)일 때만 그 말을 붙인다. */
void main() {
  final s = File('lib/ui/members.dart').readAsStringSync();
  final at = s.indexOf('Future<void> _setTitle(');
  final body = s.substring(at, s.indexOf('Future<void> _setRole(', at));
  final catchAt = body.lastIndexOf('} catch (_) {');
  final tail = body.substring(catchAt);

  test('«회비 장부가 열린다»는 말은 회비를 여는 직책일 때만', () {
    expect(tail, contains('이 직책만으로도 회비 장부는 열려요'));
    expect(tail, contains('Logic.keepsMoneyByTitle(picked)'),
        reason: '부회장·경기이사에게도 「회비 장부는 열려요」라고 한다');
  });
}
