import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

/* 「내 정보 고치기」가 내 회원 칸을 **통째로** 덮어쓰면,
   내 화면이 담아 둔 «전에 본 모습»이 서버에 그대로 얹힌다.
   그 사이 방장이 내 직책을 바꿨다면 그 직책이 사라지거나,
   규칙(myRoleTitleUnchanged)에 걸려 이름 저장 자체가 까닭 없이 실패한다.
   → 바꾸는 항목만 점 경로로 쓴다(Store.memberPatch). */

/// Firestore update() 흉내 — 점 경로는 그 자리만 갈고, 통째 값은 그 칸 전체를 갈아끼운다.
Map<String, dynamic> applyPatch(
    Map<String, dynamic> doc, Map<String, dynamic> patch) {
  Map<String, dynamic> copy(Map m) => {
        for (final e in m.entries)
          e.key as String: e.value is Map ? copy(e.value as Map) : e.value
      };
  final out = copy(doc);
  patch.forEach((path, v) {
    final seg = path.split('.');
    var cur = out;
    for (var i = 0; i < seg.length - 1; i++) {
      cur = (cur[seg[i]] ??= <String, dynamic>{}) as Map<String, dynamic>;
    }
    // patchCouple 은 null 을 FieldValue.delete() 로 바꾼다
    if (v == null) {
      cur.remove(seg.last);
    } else {
      cur[seg.last] = v;
    }
  });
  return out;
}

String stripComments(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  test('memberPatch 는 항목별 점 경로만 만든다 (칸 통째 키가 없다)', () {
    final p = Store.memberPatch('u1', {'name': '하나', 'emoji': '🏸'});
    expect(p.keys.toSet(), {'members.u1.name', 'members.u1.emoji'});
    expect(p.containsKey('members.u1'), isFalse);
  });

  test('통째로 덮으면 그 사이 방장이 준 직책이 사라진다 (재현)', () {
    // 서버: 방장이 방금 「총무」를 달아 줬다
    final server = {
      'members': {
        'u1': {'uid': 'u1', 'name': '하나', 'role': 'member', 'title': '총무'},
        'u2': {'uid': 'u2', 'name': '두리', 'role': 'owner'},
      }
    };
    // 내 화면: 직책이 오기 «전»의 모습
    final stale = {'uid': 'u1', 'name': '하나', 'role': 'member'};

    final wholeMap = applyPatch(server, {
      'members.u1': {...stale, 'name': '하나둘'}
    });
    expect((wholeMap['members'] as Map)['u1'], isNot(contains('title')),
        reason: '옛 모습이 통째로 얹혀 직책이 지워진다 — 이게 고치려는 버그');

    final perField =
        applyPatch(server, Store.memberPatch('u1', {'name': '하나둘'}));
    final me = (perField['members'] as Map)['u1'] as Map;
    expect(me['title'], '총무', reason: '항목별로 쓰면 방장이 준 직책이 살아남는다');
    expect(me['name'], '하나둘');
    expect(me['role'], 'member');
  });

  test('내 칸만 건드린다 — 남의 칸은 그대로', () {
    final server = {
      'members': {
        'u1': {'uid': 'u1', 'name': '하나'},
        'u2': {'uid': 'u2', 'name': '두리', 'title': '회장'},
      }
    };
    final after = applyPatch(server, Store.memberPatch('u1', {'name': '새이름'}));
    expect((after['members'] as Map)['u2'], {
      'uid': 'u2',
      'name': '두리',
      'title': '회장'
    });
  });

  test('null 은 그 항목 하나만 지운다 — 회원이 통째로 사라지지 않는다', () {
    final server = {
      'members': {
        'u1': {'uid': 'u1', 'name': '하나', 'birth': '1990-01-01'}
      }
    };
    final after = applyPatch(server, Store.memberPatch('u1', {'birth': null}));
    final me = (after['members'] as Map)['u1'] as Map;
    expect(me.containsKey('birth'), isFalse);
    expect(me['name'], '하나', reason: '회원 칸 자체는 남아야 한다');
  });

  test('설정 화면은 내 칸을 통째로 쓰지 않는다', () {
    final code = stripComments(File('lib/ui/settings.dart').readAsStringSync());
    expect(code.contains(r"'members.${Store.i.myUid}': {"), isFalse,
        reason: '칸 통째 쓰기가 돌아왔다 — Store.memberPatch 를 써야 한다');
    expect(code.contains('Store.memberPatch('), isTrue);
  });

  test('이미 있는 회원의 칸을 통째로 쓰는 곳은 «만들 때»뿐이다', () {
    // 가입 승인·자리 이어받기는 회원을 «새로» 만드는 것이라 통째 쓰기가 맞다.
    final allowed = {'lib/ui/members.dart', 'lib/ui/onboarding.dart'};
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      if (allowed.any(rel.endsWith)) continue;
      final code = stripComments(f.readAsStringSync());
      if (RegExp(r"'members\.\$\{?\w[^']*'\s*:\s*\{").hasMatch(code)) {
        offenders.add(rel);
      }
    }
    expect(offenders, isEmpty,
        reason: '여기서 회원 칸을 통째로 덮으면 남이 바꾼 직책·권한을 지운다');
  });
}
