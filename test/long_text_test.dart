// 서버에서 «터무니없이 긴 글»이 왔을 때 (103회차).
//
// 입력칸은 95회차에 다 막았지만 **서버에서 오는 값은 그 문을 안 거친다**
// (웹앱·백업 복원·손으로 고친 자료). 실측: 직책 2000자면 회원 줄이 33,018픽셀 밖으로 나갔다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/ui/common.dart';

/// 그 화면을 그렸을 때 «넘침» 경고가 몇 건 나오는지
Future<int> overflows(WidgetTester t, Widget w) async {
  final errs = <String>[];
  final prev = FlutterError.onError;
  FlutterError.onError = (d) => errs.add(d.exception.toString());
  await t.pumpWidget(MaterialApp(home: Scaffold(body: w)));
  FlutterError.onError = prev;
  return errs.where((e) => e.contains('overflow')).length;
}

void main() {
  final long = '가' * 2000;

  group('길이를 자르는 규칙', () {
    test('짧은 값은 손대지 않는다', () {
      expect(Store.cutLine('홍길동'), '홍길동');
      expect(Store.cutLine('가' * Store.oneLineMax).length, Store.oneLineMax);
    });

    test('긴 값은 «잘렸다»는 표시와 함께 자른다', () {
      final cut = Store.cutLine(long);
      expect(cut.length, Store.oneLineMax + 1);
      expect(cut.endsWith('…'), isTrue, reason: '그냥 자르면 원래 그런 이름인 줄 안다');
    });

    test('입력칸 한도보다 훨씬 넉넉하다', () {
      // 이름 12 · 직책 14 — 멀쩡한 값이 잘리면 안 된다
      expect(Store.oneLineMax, greaterThan(14 * 3));
    });
  });

  group('망가진 값이 들어와도', () {
    test('회원의 이름·직책이 잘려서 들어온다', () {
      final c = Store.tidyCouple({
        'title': long,
        'members': {
          'u1': {'uid': 'u1', 'name': long, 'title': long, 'role': 'owner', 'emoji': '🏸'}
        },
      })!;
      final m = (c['members'] as Map)['u1'] as Map;
      expect((m['name'] as String).length, Store.oneLineMax + 1);
      expect((m['title'] as String).length, Store.oneLineMax + 1);
      expect((c['title'] as String).length, Store.oneLineMax + 1);
    });

    test('«길어도 되는» 칸은 안 자른다', () {
      // 사진은 data: 주소가 통째로 들어올 수 있다 — 자르면 사진이 깨진다
      final photo = 'data:image/jpeg;base64,${'A' * 5000}';
      final c = Store.tidyCouple({
        'members': {
          'u1': {'uid': 'u1', 'name': '나', 'photo': photo, 'role': 'member'}
        },
      })!;
      expect(((c['members'] as Map)['u1'] as Map)['photo'], photo);
    });

    test('번호(uid)도 안 자른다 — 자르면 그 사람이 사라진다', () {
      final id = 'u' * 200;
      final c = Store.tidyCouple({
        'members': {
          id: {'uid': id, 'name': '나', 'role': 'member'}
        },
      })!;
      expect(((c['members'] as Map)[id] as Map)['uid'], id);
    });
  });

  group('화면이 넘치지 않는다', () {
    setUp(() {
      AppState.i.couple = Store.tidyCouple({
        'title': long,
        'members': {
          'u1': {'uid': 'u1', 'name': long, 'title': long, 'role': 'owner', 'emoji': '🏸'}
        },
      });
    });

    testWidgets('회원 줄 (이름 + 직책 딱지)', (t) async {
      final m = AppState.i.members['u1'] as Map;
      expect(
        await overflows(t, Row(children: [
          const Avatar('u1', size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Row(children: [
              Flexible(
                  child: Text(m['name'] as String, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  child: Text(m['title'] as String,
                      style: const TextStyle(fontSize: 11))),
            ]),
          ),
        ])),
        0,
      );
    });

    testWidgets('출석 칩 (Wrap 안이라 폭이 무한대로 주어진다)', (t) async {
      final m = AppState.i.members['u1'] as Map;
      expect(
        await overflows(t, Wrap(spacing: 6, children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check, size: 14),
                Text(m['name'] as String, style: const TextStyle(fontSize: 12)),
              ])),
        ])),
        0,
      );
    });

    testWidgets('말풍선 위 이름', (t) async {
      expect(
        await overflows(t, Row(children: [
          const SizedBox(width: 34),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppState.i.nameOf('u1'), style: const TextStyle(fontSize: 11)),
          ]),
        ])),
        0,
      );
    });

    testWidgets('위쪽 모임 이름', (t) async {
      expect(
        await overflows(t, Row(children: [
          const Emblem(basePx: 24, capScale: 1.25),
          const SizedBox(width: 8),
          Flexible(
              child: Text(AppState.i.couple!['title'] as String,
                  overflow: TextOverflow.ellipsis)),
        ])),
        0,
      );
    });
  });

  /* 104회차: 기록 쪽에도 «한 줄 자리»가 있다.
     모르는 `repeat` 값이 일정 카드 윗줄의 딱지로 그대로 그려져 21,458픽셀 넘쳤다
     (`_repeatLabels[rep] ?? rep` — 모르면 그대로 쓴다). */
  group('기록의 «한 줄» 칸', () {
    test('반복·분류·시각·날짜는 잘린다', () {
      final out = Store.tidy([
        {
          'id': 'e1',
          'type': 'event',
          'repeat': long,
          'time': long,
          'date': long,
          'until': long,
          'cat': long,
        }
      ]).first;
      for (final k in ['repeat', 'time', 'date', 'until', 'cat']) {
        expect((out[k] as String).length, Store.oneLineMax + 1, reason: k);
      }
    });

    test('«여러 줄이 당연한» 글은 안 자른다', () {
      final out = Store.tidy([
        {'id': 'd1', 'type': 'diary', 'title': long, 'text': long, 'body': long}
      ]).first;
      expect((out['text'] as String).length, 2000, reason: '글을 자르면 회원이 쓴 내용이 사라진다');
      expect((out['body'] as String).length, 2000);
      // 제목은 어디서나 Expanded·Column 안이라 알아서 줄바꿈된다 — 자르지 않는다
      expect((out['title'] as String).length, 2000);
    });

    test('번호는 안 자른다 — 자르면 그 기록을 못 찾는다', () {
      final id = 'st:AAAAAA/${'1' * 200}';
      final out = Store.tidy([
        {'id': 'm1', 'type': 'msg', 'photoId': id, 'by': 'u' * 100, 'replyTo': 'r' * 100}
      ]).first;
      expect(out['photoId'], id);
      expect((out['by'] as String).length, 100);
      expect((out['replyTo'] as String).length, 100);
    });

    testWidgets('일정 카드 윗줄이 안 넘친다', (t) async {
      final e = Store.tidy([
        {'id': 'e1', 'type': 'event', 'title': '모임', 'repeat': long}
      ]).first;
      const labels = {'week': '매주', 'month': '매달'};
      final rep = e['repeat'] as String;
      expect(
        await overflows(t, Row(children: [
          const Expanded(child: Text('모임', style: TextStyle(fontSize: 16))),
          Chip(
              label: Text(labels[rep] ?? rep, style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact),
          const Icon(Icons.more_vert),
        ])),
        0,
      );
    });
  });
}
