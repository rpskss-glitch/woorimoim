import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/demo.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 👀 체험 모드(둘러보기) — 192회차.

   가입·승인 없이 앱을 볼 수 있는 길. 스토어 심사원이 **승인 대기 화면에서 막히면**
   애플이 2.1「미완성」으로 반려한다(장부의신에서 실제로 겪은 사유).

   여기서 지키는 것 둘:
     ① 체험 중에는 **서버로 아무것도 나가지 않는다** — Store 의 읽기·쓰기 자리가 빠짐없이 Demo 를 먼저 묻는가.
        한 자리라도 빠지면 «샘플을 만지는 줄 알았는데 진짜 모임 자료가 바뀐다.»
     ② 화면에서는 **진짜처럼 된다** — 쓰기를 막아 버리면 「눌러도 아무 일도 안 나는 앱」으로 보인다. */
void main() {
  tearDown(Demo.stop);

  group('체험 시작·끝', () {
    test('시작하면 샘플 모임에 «방장»으로 들어가 있다', () {
      Demo.start();
      final st = AppState.i;
      expect(Demo.on, isTrue);
      expect(st.code, Demo.code);
      expect(st.couple?['title'], '앞산 배드민턴');
      expect(st.memberList.length, 6);
      expect(st.approved, isTrue, reason: '승인 대기 화면에 갇히면 둘러볼 수가 없다');
      expect(st.isOwner, isTrue, reason: '승인·회비·설정까지 보여야 무엇을 하는 앱인지 안다');
      expect(st.pending, isNotEmpty, reason: '가입 승인 화면도 보여줘야 한다');
    });

    test('샘플에 대화·투표·일정·회비가 다 들어 있다', () {
      Demo.start();
      final st = AppState.i;
      expect(st.by('msg'), isNotEmpty);
      expect(st.by('msg').where((m) => m['kind'] == 'poll'), hasLength(2));
      expect(st.by('event'), isNotEmpty);
      expect(st.by('ledger'), isNotEmpty);
      expect(st.by('diary'), isNotEmpty);
      // 그 달 회비를 낸 것으로 보여야 회비 화면이 «쓰는 모습»으로 보인다
      // (수입에는 «이월금»처럼 회비가 아닌 것도 있으므로 «회비인 것»을 찾아 본다)
      final dues = st.by('ledger').where((x) => x['kind'] == 'in' && x['feeMonths'] != null);
      expect(dues, isNotEmpty, reason: '회비를 낸 기록이 없으면 회비 화면이 텅 비어 보인다');
      expect((dues.first['feeMonths'] as List), isNotEmpty);
    });

    test('통장이 «마이너스»로 보이지 않는다', () {
      /* 체험 모드는 심사원이 보는 화면이자 스토어 그림이다.
         수입보다 지출이 크면 통장이 «-216,000원»(빨간 글씨)으로 떠서 빚진 모임처럼 보인다.
         실제 동호회도 지난달 잔액을 이월해서 시작한다 — 그 이월금을 샘플에 둔다. */
      Demo.start();
      var bal = 0;
      for (final x in AppState.i.by('ledger')) {
        final amt = (x['amount'] as num).toInt();
        bal += x['kind'] == 'in' ? amt : -amt;
      }
      expect(bal, greaterThan(0), reason: '샘플 통장이 $bal 원 — 빚진 모임처럼 보인다');
    });

    test('게시판이 «만들다 만» 것처럼 비어 보이지 않는다', () {
      Demo.start();
      expect(AppState.i.by('diary').length, greaterThanOrEqualTo(3),
          reason: '글이 한둘이면 심사원 눈에 미완성(2.1)으로 보인다');
    });

    test('나가면 흔적이 남지 않는다', () {
      Demo.start();
      Demo.stop();
      expect(Demo.on, isFalse);
      expect(AppState.i.profile, isNull);
      expect(AppState.i.couple, isNull);
      expect(AppState.i.items, isEmpty);
      expect(AppState.i.byId('d1'), isNull, reason: '번호로 찾는 표가 남으면 답장 인용에 옛 대화가 뜬다');
    });
  });

  group('체험 중에 하는 일 (화면에서는 진짜처럼)', () {
    test('대화를 보내면 목록에 남는다', () {
      Demo.start();
      final n = AppState.i.by('msg').length;
      final id = Demo.addItem({'type': 'msg', 'text': '안녕하세요'});
      expect(id, isNotEmpty);
      expect(AppState.i.by('msg').length, n + 1);
      expect(AppState.i.byId(id)?['by'], Demo.uid, reason: '내가 보낸 말로 잡혀야 한다');
    });

    test('투표를 찍고 뗄 수 있다 (점 경로·지우기)', () {
      Demo.start();
      final poll = AppState.i.by('msg').firstWhere((m) => m['kind'] == 'poll');
      final id = poll['id'] as String;
      Demo.updateItem(id, {'votes.${Demo.uid}': [1]});
      expect(Logic.pollMine(AppState.i.byId(id)!.cast<String, dynamic>(), Demo.uid), [1]);
      Demo.updateItem(id, {'votes.${Demo.uid}': null});
      expect(Logic.pollMine(AppState.i.byId(id)!.cast<String, dynamic>(), Demo.uid), isEmpty);
    });

    test('트랜잭션 자리(mutateItem)도 «지우기»를 알아본다', () {
      Demo.start();
      final id = Demo.addItem({'type': 'msg', 'text': '하트 시험'});
      Demo.applyItem(id, (cur) => {
            'reacts': {Demo.uid: '❤️'}
          });
      expect(Logic.reactEmojis(AppState.i.byId(id)?['reacts']), '❤️');
      Demo.applyItem(id, (cur) => {
            'reacts': {Demo.uid: Store.del}
          });
      expect(Logic.reactEmojis(AppState.i.byId(id)?['reacts']), '');
    });

    test('지우기·모임 설정 바꾸기도 된다', () {
      Demo.start();
      final id = Demo.addItem({'type': 'msg', 'text': '지울 말'});
      expect(Demo.deleteItem(id), isTrue);
      expect(AppState.i.byId(id), isNull);
      Demo.setCouple({'title': '앞산 배드민턴 2팀'});
      expect(AppState.i.couple?['title'], '앞산 배드민턴 2팀');
      Demo.patchCouple({'members.${Demo.uid}.name': '홍길동'});
      expect((AppState.i.couple?['members'] as Map)[Demo.uid]['name'], '홍길동');
    });

    test('사진은 그림 그 자체로 들고 있다 (보관함에 못 올리므로)', () {
      Demo.start();
      final src = Demo.keepPhoto(Uint8List.fromList(_bytes([1, 2, 3])));
      expect(src.startsWith('data:image/jpeg;base64,'), isTrue);
      expect(Demo.getPhoto(src), src);
      expect(Demo.getPhoto('st:club/123'), isNull, reason: '서버 번호는 체험에서 못 읽는다');
    });
  });

  group('서버로 새지 않는가 (코드가 지켜야 하는 것)', () {
    final src = File('lib/store.dart')
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//.*'), '');

    /// [name] 으로 시작하는 자리의 본문(다음 메서드 전까지)을 대충 잘라 온다
    String bodyOf(String name) {
      final at = src.indexOf(name);
      expect(at, greaterThan(0), reason: '$name 자리가 없어졌다 — 시험을 고쳐야 한다');
      return src.substring(at, (at + 700).clamp(0, src.length));
    }

    const writes = [
      'Future<String?> addItem(',
      'Future<void> updateItem(',
      'Future<bool> deleteItem(',
      'Future<bool> mutateItem(',
      'Future<void> setCouple(',
      'Future<void> patchCouple(',
      'Future<bool> mutateCouple(',
      'Future<String?> savePhoto(',
    ];
    for (final w in writes) {
      test('$w 은 체험 모드를 먼저 묻는다', () {
        expect(bodyOf(w), contains('Demo.'),
            reason: '체험 중에 «진짜 모임 자료»가 바뀐다 — 심사원이 만진 것이 회원 화면에 뜬다');
      });
    }

    const reads = [
      'void subCouple(',
      'void subItems(',
      'void stopAll(',
      'Future<Map<String, dynamic>?> getCouple(',
      'Future<String?> getPhoto(',
    ];
    for (final r in reads) {
      test('$r 도 체험 모드를 먼저 묻는다', () {
        expect(bodyOf(r), contains('Demo.'),
            reason: '체험인데 서버를 부른다 — 로그인·요금이 나가고 빈 화면이 된다');
      });
    }

    test('내 번호도 체험 것으로 바뀐다', () {
      /* 한 줄이든 여러 줄이든 «체험이면 체험 번호»라야 한다 —
         모양은 바뀔 수 있으니 뜻만 본다. */
      final at = src.indexOf('String get myUid');
      expect(at, greaterThan(0), reason: '내 번호를 주는 자리가 사라졌다');
      final body = src.substring(at, (at + 420).clamp(0, src.length));
      expect(body.contains('Demo.on') && body.contains('Demo.uid'), isTrue,
          reason: '내 말·내 표가 하나도 내 것으로 안 잡혀 앱이 남의 것처럼 보인다');
      // 체험 판정이 «먼저» 와야 한다 — 뒤에 오면 그 전에 파이어베이스를 만진다
      expect(body.indexOf('Demo.on'), lessThan(body.indexOf('_auth')),
          reason: '체험인지 묻기 전에 파이어베이스부터 만진다');
    });
  });
}

/// 시험용 짧은 바이트열
List<int> _bytes(List<int> v) => v;
