// 「빈 글자」가 들어왔을 때 (106회차).
//
// 앱은 `(m['name'] as String?) ?? '회원'` 처럼 기본값을 두는데,
// **빈 글자는 «있는 값»이라 기본값이 안 걸린다** — 이름이 아무것도 안 보이고 아바타가 투명해진다.
// 56회차에 «종류가 틀린 값»은 고쳤는데 «비어 있는 값»은 그대로였다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/config.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/ui/common.dart';

const _blank = ['', '   ', '　', ' \t\n '];

Map<String, dynamic> club(Object? v) => {
      'title': v,
      'members': {
        'u1': {'uid': 'u1', 'name': v, 'emoji': v, 'role': v, 'photo': v}
      },
    };

void main() {
  test('눈에 보이는 글자가 없으면 «빈 것»이다', () {
    for (final v in _blank) {
      expect(Store.isBlank(v), isTrue, reason: '${v.codeUnits}');
    }
    for (final v in ['홍', ' 홍 ', '0']) {
      expect(Store.isBlank(v), isFalse, reason: v);
    }
  });

  test('빈 이름·아바타·권한은 아예 빼서 기본값이 걸리게 한다', () {
    for (final v in _blank) {
      final c = Store.tidyCouple(club(v))!;
      final m = (c['members'] as Map)['u1'] as Map;
      for (final f in ['name', 'emoji', 'role', 'photo']) {
        expect(m.containsKey(f), isFalse, reason: '$f (${v.codeUnits})');
      }
      expect(c.containsKey('title'), isFalse, reason: '모임 이름 (${v.codeUnits})');
    }
  });

  test('«비어 있음»이 뜻을 가지는 칸은 안 건드린다', () {
    // 직책 없음·생년월일 없음은 실제로 그런 뜻이다
    final c = Store.tidyCouple({
      'members': {
        'u1': {'uid': 'u1', 'name': '나', 'role': 'member', 'title': '', 'birth': ''}
      }
    })!;
    final m = (c['members'] as Map)['u1'] as Map;
    expect(m['title'], '');
    expect(m['birth'], '');
  });

  test('멀쩡한 값은 그대로다', () {
    final c = Store.tidyCouple(club('홍길동'))!;
    final m = (c['members'] as Map)['u1'] as Map;
    expect(m['name'], '홍길동');
    expect(c['title'], '홍길동');
  });

  testWidgets('화면에 «이름 없는 회원»이 안 생긴다', (t) async {
    for (final v in _blank) {
      AppState.i.couple = Store.tidyCouple(club(v));
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(children: [
            const Avatar('u1'),
            Text(AppState.i.nameOf('u1')),
          ]),
        ),
      ));
      expect(AppState.i.nameOf('u1'), '회원', reason: '${v.codeUnits} — 이름이 안 보이면 누군지 알 수 없다');
      expect(AppState.i.emojiOf('u1'), '🏸', reason: '${v.codeUnits} — 아바타가 투명해진다');
      expect(AppState.i.role, 'member');
      expect(find.text('🏸'), findsOneWidget);
    }
  });

  testWidgets('위쪽 막대에 모임 이름이 «사라지지» 않는다', (t) async {
    AppState.i.couple = Store.tidyCouple(club('   '));
    final title = (AppState.i.couple?['title'] as String?) ?? Cfg.appName;
    expect(title, Cfg.appName, reason: '빈 이름이 그대로 오면 위쪽이 텅 빈다');
  });
}
