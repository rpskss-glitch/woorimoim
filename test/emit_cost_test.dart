import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* ⏱ 「대화 한 건이 올 때 무엇을 다시 하는가」.

   대화가 오면 `_emit` 이 돌아 화면에 기록을 다시 넘긴다. 그 자리에서 «기록 전부»를
   다시 다듬고 있었다 — 사진·회비·일정까지. 다듬기는 **제자리에서** 고치므로
   만드는 곳에서 한 번이면 되는데, 알리는 곳에서 매번 또 했다.
   2026-08-24 실측(기록 950건, 사진 300장에 작은 그림 포함):
     · 이미 다듬은 950건을 또 다듬기 … **8,157㎲**
     · 새 대화 창 201건만 다듬기 …… 648㎲  (12배)
   값싼 폰은 서너 배라 한 프레임(16,700㎲)을 넘겨 **말이 올 때마다 화면이 끊긴다.** */
void main() {
  String bare(String p) => File(p)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  /// 이름 뒤 괄호를 짝 맞춰 닫은 «뒤»의 몸통만 떼어낸다
  String bodyOf(String src, String decl) {
    final at = src.indexOf(decl);
    if (at < 0) return '';
    var i = src.indexOf('(', at), d = 0;
    for (; i < src.length; i++) {
      if (src[i] == '(') d++;
      if (src[i] == ')') { d--; if (d == 0) break; }
    }
    final open = src.indexOf('{', i);
    d = 0;
    for (var j = open; j < src.length; j++) {
      if (src[j] == '{') d++;
      if (src[j] == '}') { d--; if (d == 0) return src.substring(open, j + 1); }
    }
    return '';
  }

  test('알리는 곳(_emit)은 다듬지 «않는다»', () {
    final body = bodyOf(bare('lib/store.dart'), 'void _emit()');
    expect(body, isNotEmpty, reason: '_emit 을 못 찾았다 — 이 시험이 헛돌고 있다');
    expect(body.contains('tidy('), isFalse,
        reason: '대화 한 건마다 «기록 전부»를 다시 다듬는다 — '
            '실측 8,157㎲, 값싼 폰이면 한 프레임을 넘겨 말이 올 때마다 끊긴다');
  });

  test('만드는 곳 «넷 모두»에서 한 번씩 다듬는다', () {
    final s = bare('lib/store.dart');
    // ① 기록 구독  ② 대화 구독  ③ 이전 대화 더 보기  ④ 옛 대화 한 건 맞추기
    final subItems = bodyOf(s, 'void subItems(');
    expect(subItems.contains('_core = tidy('), isTrue,
        reason: '기록 구독이 안 다듬는다 — 서버에서 온 날것이 그대로 화면으로 간다');
    expect(RegExp(r'final next =\s*tidy\(').hasMatch(subItems), isTrue,
        reason: '대화 구독이 안 다듬는다');

    final older = bodyOf(s, 'Future<int> loadOlder(');
    expect(older.contains('tidy('), isTrue, reason: '이전 대화 더 보기가 안 다듬는다');

    final sync = bodyOf(s, 'Future<void> syncOlder(');
    expect(sync.contains('tidy('), isTrue, reason: '옛 대화 한 건 맞추기가 안 다듬는다');
  });

  test('그래도 화면에 가는 기록은 «다 다듬어져» 있다', () {
    // 날것이 섞여 들어와도 화면이 안 터지는지 — 다듬기를 옮긴 뒤에도 그대로여야 한다
    final raw = <Map<String, dynamic>>[
      {'id': 'a', 'type': 'msg', 'text': 123, 'createdAt': 1}, // 글이 숫자
      {'id': 'b', 'type': 'event', 'title': ['배열'], 'date': '2026-8-5'}, // 제목이 배열·날짜 0 없음
      {'id': 'c', 'type': 'ledger', 'kind': 'in', 'amount': '오만원', 'date': '2026-08-01'},
    ];
    final out = Store.tidy(raw);
    expect(out[0]['text'], '123');
    expect(out[1]['title'], '');
    expect(out[1]['date'], '2026-08-05', reason: '0을 안 채우면 날짜 차례가 뒤집힌다');
    expect(Store.money(out[2]['amount']), 0);
  });

  test('다듬기는 «두 번 해도 같다» — 옮겨도 값이 안 달라진다', () {
    final one = <Map<String, dynamic>>[
      {'id': 'a', 'type': 'event', 'title': '모임', 'date': '2026-8-5', 'repeat': 'weekly'},
    ];
    final a = Store.tidy(one).first;
    final first = Map<String, dynamic>.from(a);
    final b = Store.tidy(one).first;
    expect(b, first, reason: '두 번 다듬으면 값이 달라진다 — 만드는 곳으로 옮길 수 없다');
  });

  test('대화만 왔을 때는 출석·회비 표를 «다시 만들지 않는다»', () {
    /* 진짜 앱은 기록 구독(_core)과 대화 구독(_recent)이 «따로» 돈다.
       대화만 오면 기록 쪽 물건은 손대지 않은 그대로라, 이 검사가 통해야 한다.
       (그래서 여기서도 기록은 같은 물건을 다시 쓴다 — 새로 만들면 실제와 다른 흉내가 된다) */
    final core = Store.tidy([
      for (var i = 0; i < 20; i++)
        {'id': 'e$i', 'type': 'event', 'title': '모임$i', 'date': '2026-08-10'},
      for (var i = 0; i < 20; i++)
        {'id': 'l$i', 'type': 'ledger', 'kind': 'in', 'amount': 20000, 'payer': 'u1'},
    ]);
    List<Map<String, dynamic>> msgs(int n) => Store.tidy([
          for (var i = 0; i < n; i++)
            {'id': 'm$i', 'type': 'msg', 'text': '$i', 'createdAt': 1000 + i},
        ]);

    AppState.i.setItems([...core, ...msgs(5)]);
    final ev = AppState.i.by('event');
    final led = AppState.i.by('ledger');

    AppState.i.setItems([...core, ...msgs(6)]); // 대화 한 건이 늘었다
    expect(identical(AppState.i.by('event'), ev), isTrue,
        reason: '대화 한 건에 일정 묶음이 새것이 된다 — 출석·순위를 통째로 다시 센다');
    expect(identical(AppState.i.by('ledger'), led), isTrue,
        reason: '대화 한 건에 회비 묶음이 새것이 된다 — 밀린 회비를 통째로 다시 센다');

    // 반대로 «기록이 정말 바뀌면» 새것이라야 한다 (검사가 너무 헐거우면 안 된다)
    final more = Store.tidy([
      ...core,
      {'id': 'eX', 'type': 'event', 'title': '새 모임', 'date': '2026-09-01'},
    ]);
    AppState.i.setItems([...more, ...msgs(6)]);
    expect(identical(AppState.i.by('event'), ev), isFalse,
        reason: '일정이 늘었는데도 옛 묶음을 그대로 쓴다 — 새 모임이 화면에 안 나온다');
  });
}
