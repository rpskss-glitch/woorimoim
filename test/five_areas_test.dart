import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/comments.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/board.dart';
import 'package:woorimoim/ui/calendar.dart';
import 'package:woorimoim/ui/chat.dart';
import 'package:woorimoim/ui/post_screen.dart';

/* 다섯 자리를 «이상한 자료»로 두드려 본다 — 결제·대화창·사진첩·댓글·일정.

   화면은 좋은 자료로는 잘 뜬다. 터지는 것은 늘 «있을 리 없는» 자료가 왔을 때다:
   백업을 손으로 고쳤거나, 웹앱이 다른 모양으로 적었거나, 옛 판이 남긴 찌꺼기이거나.
   그런 자료로도 화면이 버텨야 «팔 수 있는 앱»이다. */
void main() {
  final st = AppState.i;

  Widget host(Widget child) => MaterialApp(
        theme: buildTheme('sky'),
        home: Scaffold(body: child),
      );

  /* 이상한 값들 — 어느 칸에든 들어올 수 있다.

     ⚠️ **부를 때마다 새로 만든다.** 하나를 여러 시험이 돌려쓰면,
        앱이 그 값을 제자리에서 고칠 때 다음 시험이 «이미 고쳐진 것»을 받는다 —
        앱 버그가 아닌데 버그처럼 보이거나, 반대로 진짜 버그를 가린다. */
  List<Object?> weirdValues() => <Object?>[
        null, '', ' ', 0, -1, 3.14, true,
        <Object?>[], <String, Object?>{}, <Object?>['a'], <String, Object?>{'x': 1},
        'ㄱ' * 5000, '\n\n\n', '<script>', '../../etc',
      ];

  void seed(List<Map<String, dynamic>> items) {
    st.profile = {'code': 'C', 'slot': 'me', 'name': '나'};
    st.setCouple({
      'title': '앞산 배드민턴',
      'free': true, // 잠금과 섞이지 않게
      'fee': {'amount': 20000},
      'members': {
        'me': {'uid': 'me', 'name': '나', 'role': 'owner'},
        'u2': {'uid': 'u2', 'name': '남', 'role': 'member'},
      },
    });
    /* ⚠️ **실제 앱이 지나는 길과 똑같이** 다듬기를 거친다.
       `Store.tidy` 가 이상한 값을 걸러 주는 것이 이 앱의 방어선이다 —
       그걸 건너뛰고 시험하면 «앱에서는 안 나는 탈»을 잡느라 헛수고하고,
       정작 다듬기에 구멍이 나도 못 잡는다.
       (Store 의 읽기 자리는 모두 tidy 를 거쳐 setItems 를 부른다) */
    st.setItems(Store.tidy(items));
  }

  group('대화창', () {
    testWidgets('말풍선 칸이 이상해도 안 터진다', (t) async {
      for (final w in weirdValues()) {
        seed([
          {'id': 'm1', 'type': 'msg', 'by': 'u2', 'text': w, 'createdAt': 1},
          {'id': 'm2', 'type': 'msg', 'by': 'me', 'text': '보통 말', 'kind': w},
        ]);
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(host(const ChatTab(active: true)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'text/kind 가 $w 일 때 터진다');
      }
    });

    testWidgets('투표 칸이 이상해도 안 터진다', (t) async {
      for (final w in weirdValues()) {
        seed([
          {'id': 'p1', 'type': 'msg', 'kind': 'poll', 'by': 'u2', 'poll': w},
          {'id': 'p2', 'type': 'msg', 'kind': 'poll', 'by': 'u2',
           'poll': <String, Object?>{'q': '무엇?', 'opts': w}, 'votes': w},
        ]);
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(host(const ChatTab(active: true)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'poll 이 $w 일 때 터진다');
      }
    });
  });

  group('사진첩', () {
    testWidgets('사진 번호가 이상해도 안 터진다', (t) async {
      for (final w in weirdValues()) {
        seed([
          {'id': 'ph1', 'type': 'photo', 'by': 'u2', 'photoId': w},
          {'id': 'ph2', 'type': 'photo', 'by': 'u2', 'photoIds': w},
        ]);
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(host(const BoardTab()));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'photoId 가 $w 일 때 터진다');
      }
    });
  });

  group('댓글', () {
    test('replyTo 가 이상해도 셈이 안 터진다', () {
      for (final w in weirdValues()) {
        seed([
          {'id': 'd1', 'type': 'diary', 'by': 'me', 'title': '글'},
          {'id': 'c1', 'type': 'reply', 'replyTo': w, 'by': 'u2', 'text': '댓글'},
        ]);
        expect(() => Comments.of('d1'), returnsNormally,
            reason: 'replyTo 가 $w 일 때 터진다');
        expect(() => Comments.count('d1'), returnsNormally);
      }
    });

    testWidgets('글 안에서 댓글 칸이 이상해도 안 터진다', (t) async {
      for (final w in weirdValues()) {
        seed([
          {'id': 'd1', 'type': 'diary', 'by': 'me', 'title': '글', 'text': '내용'},
          {'id': 'c1', 'type': 'reply', 'replyTo': 'd1', 'by': w, 'text': w,
           'createdAt': w, 'date': w},
        ]);
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(host(const PostScreen(postId: 'd1')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '댓글 칸이 $w 일 때 터진다');
      }
    });
  });

  group('일정', () {
    testWidgets('일정 칸이 이상해도 안 터진다', (t) async {
      for (final w in weirdValues()) {
        seed([
          {'id': 'e1', 'type': 'event', 'by': 'me', 'title': w, 'date': w,
           'time': w, 'place': w, 'rsvp': w, 'attend': w},
        ]);
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(host(const CalendarTab()));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: '일정 칸이 $w 일 때 터진다');
      }
    });

    test('되풀이 일정 칸이 이상해도 셈이 안 터진다', () {
      for (final w in weirdValues()) {
        seed([
          {'id': 'e1', 'type': 'event', 'by': 'me', 'title': '정기',
           'date': '2026-09-01', 'repeat': w, 'until': w},
        ]);
        expect(() => Logic.nextEvent(), returnsNormally,
            reason: 'repeat 이 $w 일 때 터진다');
        expect(() => Logic.attendStats(), returnsNormally);
      }
    });
  });

  tearDown(() {
    Demo.stop();
    st.setItems([]);
  });

  group('앉은 자리를 흔들지 않는다', () {
    /* 💥 2026-08-29: 게시판이 `by('diary')` 가 준 목록을 **제자리에서** 정렬했다.
         · 글이 하나도 없으면 «고칠 수 없는 빈 목록»이 와서 그 자리에서 터졌고
         · 글이 있어도 앱이 들고 있는 원본이 뒤섞여, 그 차례를 믿는 다른 화면이 엉뚱한 순서를 봤다. */
    test('by(...) 결과를 바로 정렬하는 자리가 없다', () {
      final bad = <String>[];
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final src = f.readAsStringSync();
        // by(...) 또는 hide(by(...)) 를 «복사 없이» 정렬하는 모양
        if (RegExp(r'(?<!\[\.\.\.)\.by\([^)]*\)\)?\s*\.\.sort').hasMatch(src) ||
            RegExp(r'hide\(AppState\.i\.by\([^)]*\)\)\s*\.\.sort').hasMatch(src)) {
          bad.add(f.path.replaceAll(r'', '/'));
        }
      }
      expect(bad, isEmpty,
          reason: '앱이 들고 있는 목록을 제자리에서 정렬한다 — '
              '비어 있으면 터지고, 차례를 믿는 다른 화면이 엉뚱한 걸 본다: \$bad');
    });

    test('다듬기가 «고칠 수 있는» 묶음을 넣는다', () {
      /* `const []` 를 넣으면, 그 뒤에 이 묶음에 무언가 «더하려는» 자리가 터진다.
         다듬기는 고쳐 주는 일이지 다음 사람을 넘어뜨리는 일이 아니다. */
      // 주석에는 나올 수 있다 — «넣는 자리»가 있는지를 본다
      final store = File('lib/store.dart')
          .readAsStringSync()
          .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
          .replaceAll(RegExp(r'//.*'), '');
      final at = store.indexOf('for (final k in _arrFields)');
      expect(at, greaterThan(0));
      final body = store.substring(at, (at + 700).clamp(0, store.length));
      expect(body.contains('const []'), isFalse,
          reason: '다듬기가 고칠 수 없는 빈 묶음을 넣는다');
    });
  });
}
