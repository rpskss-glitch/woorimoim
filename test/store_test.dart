// 사진 지우기 실패를 「영영 안 되는 것」과 「지금만 안 되는 것」으로 가르는 규칙 시험.
//
// 왜 중요한가: 인터넷이 없어 못 지운 것을 실패로 세면, 며칠 오프라인이었다는 이유로
// 포기 횟수(10번)를 채워 대기줄에서 빠진다. 그 사진은 아무도 못 보는 채로 남아
// 매달 보관 요금만 나간다. (웹앱이 명시적으로 막아둔 것을 옮기며 빠뜨렸던 자리)
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:woorimoim/config.dart';
import 'package:woorimoim/store.dart';

/* 소스 «모양»을 볼 때는 반드시 주석을 걷어낸다.
   ⚠️ 안 걷어내면 «설명글에 적힌 낱말»이 코드처럼 잡힌다.
      130회차에 실제로 그랬다: `bootstrap` 에 「Firebase.initializeApp 이 터질 수 있다」는
      경고를 적었더니, 그 글이 진짜 호출보다 «앞»이라 「먼저 갈래를 알아내는가」 시험이
      **고친 것이 없는데 깨졌다.** (85·94·97·99회차와 같은 함정) */
String readSource(String path) => File(path)
    .readAsStringSync()
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//.*'), '');

FirebaseException err(String code) => FirebaseException(plugin: 'test', code: code);

void main() {
  group('지울 수 없을 때 — 실패로 셀 것인가', () {
    test('권한 문제는 다시 해도 마찬가지라 실패로 센다', () {
      expect(Store.countsAsFailure(err('unauthorized')), isTrue);
      expect(Store.countsAsFailure(err('permission-denied')), isTrue);
      expect(Store.countsAsFailure(err('invalid-argument')), isTrue);
    });

    test('인터넷 문제는 세지 않는다 (오프라인이라고 포기하면 사진이 영영 남는다)', () {
      for (final code in ['unknown', 'retry-limit-exceeded', 'canceled', 'unavailable', 'deadline-exceeded']) {
        expect(Store.countsAsFailure(err(code)), isFalse, reason: '$code 는 다시 시도해야 한다');
      }
    });

    /* 160회차에 뜻을 바꿨다. 예전에는 「Firebase 오류가 아니면 끊김일 수도 있으니 세지 말자」였는데,
       그러면 **값이 잘못돼 터지는 줄**(예: 대기줄에 남아 있던 옛 `data:` 값 →
       ArgumentError 'A document path must not contain "//"')이 10번 세기를 아예 안 돌아
       앱을 켤 때마다 «말없이 영원히» 다시 시도한다.
       서버가 준 오류가 아니면 다시 해도 똑같으므로 센다 — 10번 뒤에 «크게 알리고» 포기하는 편이
       조용히 영원히 도는 것보다 낫다. (애초에 그런 값은 `deletable` 이 앞에서 걸러 낸다) */
    test('서버가 준 오류가 «아닌» 것은 센다 — 안 그러면 영영 안 빠지는 줄이 생긴다', () {
      expect(Store.countsAsFailure(ArgumentError('A document path must not contain "//"')),
          isTrue);
      expect(Store.countsAsFailure(Exception('알 수 없는 오류')), isTrue);
    });
  });

  group('이미 없어진 것인가', () {
    test('없으면 지울 게 없으니 성공으로 본다', () {
      expect(Store.alreadyGone(err('object-not-found')), isTrue);
      expect(Store.alreadyGone(err('not-found')), isTrue);
    });

    test('권한·인터넷 문제는 「없어진 것」이 아니다', () {
      expect(Store.alreadyGone(err('unauthorized')), isFalse);
      expect(Store.alreadyGone(err('unknown')), isFalse);
    });
  });

  group('기록 빈칸 메꾸기', () {
    test('선납 개월수도 숫자로 바로잡는다', () {
      final r = Store.tidy([
        {'type': 'ledger', 'amount': '30000', 'months': '6', 'date': '2026-01-01'},
      ]);
      expect(r[0]['amount'], 30000);
      expect(r[0]['months'], 6);
    });

    test('숫자 칸이 아예 비어 있으면 0으로 (합계가 NaN이 되지 않게)', () {
      final r = Store.tidy([
        {'type': 'ledger', 'amount': null, 'date': '2026-01-01'},
      ]);
      expect(r[0]['amount'], 0);
    });

    test('선납이 아닌 기록에 months를 억지로 넣지 않는다', () {
      final r = Store.tidy([
        {'type': 'ledger', 'amount': 1000, 'date': '2026-01-01'},
      ]);
      expect(r[0].containsKey('months'), isFalse);
    });

    test('대화·게시글처럼 날짜가 필요 없는 종류는 건드리지 않는다', () {
      final r = Store.tidy([
        {'type': 'msg', 'text': '안녕', 'createdAt': 1},
      ]);
      expect(r[0].containsKey('date'), isFalse);
    });
  });

  group('사진 번호 모으기 — 방을 지울 때 원본을 놓치지 않으려면', () {
    // 보안 규칙이 사진 보관함의 「목록 보기」를 막아 두었기 때문에,
    // 기록을 지우기 전에 여기서 번호를 다 모아둬야 한다. 하나라도 빠지면 영영 못 찾는다.
    test('사진 한 장·영수증·여러 장을 모두 모은다', () {
      final ids = Store.photoIdsOf({
        'photoId': 'st:BM0001/a1',
        'rcptId': 'st:BM0001/r1',
        'photoIds': ['st:BM0001/p1', 'st:BM0001/p2'],
      });
      expect(ids, ['st:BM0001/a1', 'st:BM0001/r1', 'st:BM0001/p1', 'st:BM0001/p2']);
    });

    test('빈 값·없는 칸은 걸러낸다', () {
      expect(Store.photoIdsOf({'photoId': null, 'rcptId': '', 'photoIds': []}), isEmpty);
      expect(Store.photoIdsOf({}), isEmpty);
      expect(Store.photoIdsOf(null), isEmpty);
    });

    test('photoIds가 목록이 아닌 이상한 값이어도 죽지 않는다', () {
      expect(Store.photoIdsOf({'photoId': 'st:x/1', 'photoIds': '망가진값'}), ['st:x/1']);
    });
  });

  group('사진을 메모리에 올리는 크기', () {
    // 원본(1600px) 그대로 올리면 한 장에 7MB쯤 잡아 값싼 폰에서 앱이 꺼진다.
    // 작게 보여주는 곳은 반드시 줄여서 올려야 한다.
    test('사진첩 격자·채팅은 줄여서 올리고, 크게 보기는 원본을 쓴다', () {
      /* ⚠️ 사진첩 격자는 board.dart 가 아니라 **album.dart** 에 있다
         (웹앱과 같은 사진첩으로 옮기면서 나왔다). 옛 파일을 보면 격자에서
         크기 지정이 통째로 빠져도 시험이 그냥 통과한다. */
      final album = readSource('lib/ui/album.dart');
      final chat = readSource('lib/ui/chat.dart');
      final common = readSource('lib/ui/common.dart');
      expect(album.contains('decodeWidth:'), isTrue, reason: '사진첩 격자에 크기 지정이 빠졌다');
      expect(chat.contains('decodeWidth:'), isTrue, reason: '채팅 사진에 크기 지정이 빠졌다');
      expect(common.contains('cacheWidth: decodeWidth'), isTrue,
          reason: 'decodeWidth가 실제 그리기에 안 쓰이면 아무 소용이 없다');
    });
  });

  test('모임을 이름으로 찾을 때 코드는 «문서 이름»에서 만든다', () {
    /* 방을 만들 때 문서 안에 code 값을 따로 넣지 않는다.
       그래서 찾은 결과에 code를 문서 이름으로 채워 넣어야 하고,
       «문서 안의 code 값»에 기대면 방이 하나도 안 나온다.
       (실제로 웹앱이 그렇게 돼 있어 이름으로 찾기가 늘 0개였다 — 회원 가입이 막히는 자리다) */
    final src = readSource('lib/store.dart');
    // 112회차에 «정리를 거치는 한 문»(fromDoc)으로 모았다 — 뜻은 그대로, 모양만 바뀌었다
    expect(src.contains('fromDoc(d.data(), d.id)'), isTrue,
        reason: '찾은 문서의 code를 문서 이름에서 만들어야 한다');
    expect(src.contains("tidyCouple({...data, 'code': code})"), isTrue,
        reason: 'code 는 문서 이름에서 온 것이라야 한다');
    expect(src.contains("v.code") || src.contains("data()['code']"), isFalse,
        reason: '문서 안에 저장된 code 값에 기대면 안 된다');
  });

  test('설정에 보이는 버전이 실제 버전과 같다', () {
    // 어긋나면 회원에게 "몇 버전 쓰세요?"라고 물었을 때 엉뚱한 답을 듣고 헛다리를 짚는다
    final pubspec = readSource('pubspec.yaml');
    final line = pubspec
        .split('\n')
        .firstWhere((l) => l.startsWith('version:'), orElse: () => '');
    final real = line.replaceFirst('version:', '').trim().split('+').first;
    expect(Cfg.version, real, reason: 'lib/config.dart의 version을 pubspec.yaml과 맞춰주세요');
  });

  group('「가벼운 갱신」으로 넘기는 값', () {
    // 채팅만 살짝 고치고 다른 화면은 그대로 두는 값들. 여기에 넣은 값이 다른 화면에도
    // 보이는 것이면, 그 화면이 영영 안 바뀌어 「눌러도 반응이 없다」로 보인다.
    final main = readSource('lib/main.dart');

    test('알림(push)은 넣으면 안 된다 — 설정 화면 표시가 안 바뀐다', () {
      final line = main
          .split('\n')
          .firstWhere((l) => l.contains('_liveKeys = {'), orElse: () => '');
      expect(line, isNot(contains("'push'")),
          reason: '알림 범위를 바꿔도 설정 화면이 그대로 남는다');
    });

    test('입력중·읽음·접속만 들어 있다', () {
      final line = main
          .split('\n')
          .firstWhere((l) => l.contains('_liveKeys = {'), orElse: () => '');
      expect(line, contains("'typing'"));
      expect(line, contains("'lastRead'"));
      expect(line, contains("'lastSeen'"));
    });
  });

  group('앱 두 가지의 Firebase 열쇠', () {
    /* 앱을 나눈 뒤 열쇠를 하나로 두면 앞산 앱이 「우리 모임」의 열쇠로 등록해
       알림이 엉뚱한 곳으로 가거나 아예 안 온다. 코드의 값과 설정 파일이 같은지 대조한다. */
    String appIdIn(String path, String pkg) {
      final j = readSource(path);
      final at = j.indexOf(pkg);
      expect(at, greaterThan(0), reason: '$path 에 $pkg 설정이 없다');
      final k = j.substring(0, at).lastIndexOf('"mobilesdk_app_id"');
      expect(k, greaterThan(0));
      final tail = j.substring(k);
      final end = tail.indexOf(',');
      return tail.substring(0, end).split('"')[3];
    }

    test('우리 모임 열쇠가 설정 파일과 같다', () {
      final want = appIdIn('android/app/src/woori/google-services.json', 'com.taejinsoft.woorimoim');
      expect(readSource('lib/config.dart').contains(want), isTrue,
          reason: 'lib/config.dart 의 우리 모임 appId 가 설정 파일과 다르다');
    });

    test('앞산 배드민턴 열쇠가 설정 파일과 같다', () {
      final want = appIdIn('android/app/src/apsan/google-services.json', 'com.taejinsoft.apsanclub');
      expect(readSource('lib/config.dart').contains(want), isTrue,
          reason: 'lib/config.dart 의 앞산 appId 가 설정 파일과 다르다');
    });

    test('두 앱의 열쇠가 서로 다르다', () {
      final a = appIdIn('android/app/src/woori/google-services.json', 'com.taejinsoft.woorimoim');
      final b = appIdIn('android/app/src/apsan/google-services.json', 'com.taejinsoft.apsanclub');
      expect(a, isNot(b));
    });

    test('어느 앱인지 «꾸러미 이름»에서 스스로 알아낸다', () {
      /* 사람이 --dart-define 으로 알려주게 두면 빠뜨렸을 때
         겉과 속이 어긋난 앱(이름·Firebase 열쇠 불일치)이 조용히 나온다. */
      final cfg = readSource('lib/config.dart');
      expect(cfg.contains('PackageInfo.fromPlatform()'), isTrue);
      expect(cfg.contains("String.fromEnvironment('BRAND'"), isFalse,
          reason: '사람이 적어 넣는 방식이 남아 있으면 다시 어긋날 수 있다');
      final main = readSource('lib/main.dart');
      final a = main.indexOf('Cfg.detectBrand()');
      final b = main.indexOf('Firebase.initializeApp');
      expect(a, greaterThan(0));
      expect(a, lessThan(b), reason: 'Firebase를 켜기 «전»에 어느 앱인지 알아야 열쇠를 고를 수 있다');
    });

    test('뒷자리(알림 받는 자리)도 어느 앱인지 «다시» 알아낸다', () {
      /* 푸시 뒷자리는 앱과 따로 도는 자리라 main()에서 정해둔 것이 하나도 넘어오지 않는다.
         거기서 갈래를 다시 안 알아내면 앞산 앱이 「우리 모임」 열쇠로 Firebase를 켠다. */
      final src = readSource('lib/push.dart');
      final head = src.substring(0, src.indexOf('class Push'));
      final a = head.indexOf('Cfg.detectBrand()');
      final b = head.indexOf('Firebase.initializeApp');
      expect(a, greaterThan(0), reason: '뒷자리에서 갈래를 다시 알아내야 한다');
      expect(a, lessThan(b), reason: 'Firebase를 켜기 «전»이라야 열쇠를 고를 수 있다');
    });

    test('토큰 갱신 듣기는 한 번만 건다', () {
      // setup()은 첫 화면·홈 카드·설정에서 저마다 불린다 —
      // 그대로 두면 듣는 자리가 겹겹이 쌓여 같은 쓰기가 여러 번 나간다(요금)
      final src = readSource('lib/push.dart');
      final at = src.indexOf('onTokenRefresh');
      expect(at, greaterThan(0));
      expect(src.substring(0, at).contains('_refreshBound = true'), isTrue);
    });

    test('방장을 맡으면 「자리가 비었다」 표시를 지운다', () {
      /* 서버 규칙은 ownerReleased 가 있는 동안 «회원이 스스로 방장이 되는 것»을 허용한다.
         맡은 뒤에 그 표시를 안 지우면 문이 영영 열려 있어 아무나 자리를 가로챌 수 있다. */
      final src = readSource('lib/ui/members.dart');
      final claim = src.indexOf('_claimOwner');
      final sweep = src.indexOf('_sweepOwnerSeat()');
      expect(claim, greaterThan(0));
      expect(sweep, greaterThan(0), reason: '화면을 열 때 남은 표시를 치우는 자리가 있어야 한다');
      // 맡기 성공 뒤에 표시를 지우는 쓰기가 있어야 한다
      final after = src.substring(claim);
      final clear = after.indexOf("'ownerReleased': null");
      expect(clear, greaterThan(0), reason: '맡은 «뒤»에 지워야 한다 — 맡는 순간엔 아직 평회원이라 규칙이 막는다');
    });

    test('사진을 «못 받은 것»은 기억하지 않는다', () {
      /* 지하철에서 한 번 못 받은 사진을 기억해 두면 앱을 껐다 켤 때까지 깨진 채로 남는다.
         정말 없어진 사진일 때만 기억해야 한다. */
      final src = readSource('lib/store.dart');
      final at = src.indexOf('Future<String?> getPhoto');
      expect(at, greaterThan(0));
      final body = src.substring(at, at + 1200);
      expect(body.contains('alreadyGone'), isTrue,
          reason: '없어진 사진인지 가려서 기억해야 한다');
      expect(body.contains('if (d != null || gone)'), isTrue,
          reason: '실패한 것까지 통째로 기억하면 안 된다');
    });

    test('사진 지우기 대기줄은 한 번 걸려도 다시 돈다', () {
      // 도중에 터졌을 때 표시를 안 되돌리면 그 뒤로 대기줄이 영영 안 돌아 보관 요금만 나간다
      final src = readSource('lib/store.dart');
      final at = src.indexOf('Future<void> flushDeletes');
      expect(at, greaterThan(0));
      final body = src.substring(at, at + 600);
      expect(body.contains('finally'), isTrue);
      expect(body.contains('_flushing = false'), isTrue);
    });

    test('모임 상징 사진을 «모임 문서 안»에 넣지 않는다', () {
      /* 모임 문서는 회원 모두가 실시간으로 듣는다. 사진을 그 안에 통째로 적으면
         누가 글씨만 쳐도(입력중 표시) 사진이 회원 수만큼 다시 내려간다. */
      final src = readSource('lib/ui/settings.dart');
      final at = src.indexOf('_editEmblem');
      expect(at, greaterThan(0));
      final body = src.substring(at);
      expect(body.contains('Store.i.savePhoto'), isTrue,
          reason: '사진은 보관함에 올리고 번호만 적어야 한다');
      expect(body.contains('base64Encode'), isFalse,
          reason: '사진을 글자로 바꿔 문서에 적으면 안 된다');
      expect(body.contains('dropPhotos'), isTrue,
          reason: '바꾸면 옛 원본을 치워야 보관 요금이 안 샌다');
    });

    test('창 밖으로 밀려난 대화는 붙들고, 지운 대화는 안 되살린다', () {
      /* 「이전 대화 더 보기」를 한 뒤 새 대화가 오면 창(최근 200개)에서 하나가 밀려나는데,
         그건 더 보기로 가져온 묶음보다 «새것»이라 어느 쪽에도 없다 → 화면 중간에서 사라진다. */
      Map<String, dynamic> m(String id, int t) => {'id': id, 'createdAt': t};

      // 창이 한 칸 미끄러진 경우 — a가 밀려났다
      final fell = Store.fellOutOfWindow(
        [m('a', 10), m('b', 20), m('c', 30)],
        [m('b', 20), m('c', 30), m('d', 40)],
      );
      expect(fell.map((x) => x['id']).toList(), ['a']);

      // 중간 대화를 지운 경우 — 되살리면 안 된다 (b는 새 창의 가장 오래된 것보다 새것)
      final del = Store.fellOutOfWindow(
        [m('a', 10), m('b', 20), m('c', 30)],
        [m('a', 10), m('c', 30)],
      );
      expect(del, isEmpty, reason: '지운 대화가 되살아나면 안 된다');

      // 창이 미끄러지면서 «동시에» 중간 것이 지워져도, 밀려난 것만 골라야 한다
      final both = Store.fellOutOfWindow(
        [m('a', 10), m('b', 20), m('c', 30)],
        [m('b', 20), m('d', 40)],
      );
      expect(both.map((x) => x['id']).toList(), ['a']);

      expect(Store.fellOutOfWindow([], [m('a', 1)]), isEmpty);
      expect(Store.fellOutOfWindow([m('a', 1)], []), isEmpty);
    });

    test('서버가 막는 「기기 이어받기」를 앱이 권하지 않는다', () {
      /* 규칙(claimsOwnSeat)은 「새 자리 생년월일 == 옛 자리 생년월일」을 요구한다.
         옛 자리에 그 칸이 없으면 견줄 수 없어 **403**이 난다(2026-08-22 실서버 확인).
         그런데 앱이 「혹시 본인이신가요?」라고 물으면, 「네」를 누른 회원은
         「서버에 연결하지 못했어요」만 보며 몇 번이고 다시 누르게 된다. */
      final src = readSource('lib/ui/onboarding.dart');
      final at = src.indexOf('final dupBirth');
      expect(at, greaterThan(0));
      final body = src.substring(at, at + 1600);
      expect(body.contains('제가 기기(폰)를 바꿨어요'), isFalse,
          reason: '생년월일 없는 자리에 이어받기를 권하면 안 된다');
      expect(body.contains('가입 신청'), isTrue, reason: '왜 안 되는지 알려주고 다른 길로 보내야 한다');
    });

    test('같은 이름이 여럿이면 생년월일이 맞는 사람을 고른다', () {
      // 그냥 첫 사람을 잡으면 동명이인 때문에 정작 본인이 폰을 못 이어받는다
      final src = readSource('lib/ui/onboarding.dart');
      final at = src.indexOf('final sameName');
      expect(at, greaterThan(0));
      final body = src.substring(at, at + 700);
      expect(body.contains('sameName.where'), isTrue);
    });

    test('모임을 떠나면 「어디까지 읽었는지」도 함께 지운다', () {
      /* 이 값은 모임과 상관없이 기기에 하나뿐이라, 안 지우면 다음 모임에 그대로 따라간다 →
         새 모임의 옛 대화가 전부 「이미 읽음」으로 잡혀 안읽음 숫자가 0으로 나온다. */
      final src = readSource('lib/state.dart');
      final at = src.indexOf('Future<void> clearProfile');
      expect(at, greaterThan(0));
      final body = src.substring(at, at + 900);
      expect(body.contains('club_seenchat'), isTrue);
      expect(body.contains('club_seendiary'), isTrue);
    });

    test('답장 인용은 원래 대화를 못 찾아도 사라지지 않는다', () {
      // 인용이 통째로 빠지면 그냥 보통 말처럼 보여 무슨 얘기에 답한 건지 알 수 없다
      final src = readSource('lib/ui/chat.dart');
      final at = src.indexOf('final replyId');
      expect(at, greaterThan(0));
      final body = src.substring(at, at + 1600);
      expect(body.contains('if (replyId != null)'), isTrue,
          reason: '원래 대화가 없어도 인용 자리는 남겨야 한다');
      expect(body.contains('지난 대화'), isTrue);
    });

    test('갈래에 따라 열쇠를 고른다', () {
      expect(readSource('lib/config.dart').contains('isApsan ? _androidApsan : _androidWoori'), isTrue);
    });
  });

  test('승인되는 순간 알림 준비를 다시 한다', () {
    /* 알림 토큰은 «그 방 회원»만 적을 수 있다. 처음 준비할 때는 아직 승인 전이라 서버가 거부하므로,
       승인되는 순간 다시 하지 않으면 앱을 껐다 켤 때까지 알림이 하나도 안 온다. */
    final main = readSource('lib/main.dart');
    expect(main.contains('_wasPending'), isTrue);
    final i = main.indexOf('_wasPending');
    final j = main.indexOf('if (!isMember && isPending)');
    expect(i, lessThan(j),
        reason: '대기 화면으로 되돌아가기 «전에» 승인 여부를 봐야 한다');
    expect(main.contains('Push.i.setupIfAllowed()'), isTrue);
  });

  group('앱을 보고 있을 때의 알림', () {
    final push = readSource('lib/push.dart');
    final shell = readSource('lib/ui/shell.dart');

    test('채팅을 보고 있으면 알림을 띄우지 않는다', () {
      expect(push.contains('AppState.i.currentTab == 1'), isTrue);
      expect(shell.contains('AppState.i.currentTab'), isTrue,
          reason: '탭이 바뀔 때 알려주지 않으면 위 검사가 늘 옛 값을 본다');
    });

    test('아이폰도 같은 규칙을 따른다 (시스템에 맡기지 않는다)', () {
      expect(push.contains('alert: false'), isTrue,
          reason: '시스템에 맡기면 채팅을 보는 중에도 무조건 떠서 규칙을 못 넣는다');
      expect(push.contains('DarwinNotificationDetails'), isTrue,
          reason: '직접 띄우려면 아이폰 쪽 설정도 있어야 한다');
    });
  });

  group('회비 기록 이름 — 두 총무가 동시에 눌러도 두 번 안 들어가게', () {
    test('같은 사람·같은 시작 달이면 이름이 같다 (나중 것이 덮어써서 하나만 남는다)', () {
      final a = Store.feeDocId('BM0001', 'u1', '2026-08');
      final b = Store.feeDocId('BM0001', 'u1', '2026-08');
      expect(a, b);
    });

    test('사람이 다르거나 시작 달이 다르면 이름도 다르다', () {
      final base = Store.feeDocId('BM0001', 'u1', '2026-08');
      expect(Store.feeDocId('BM0001', 'u2', '2026-08'), isNot(base));
      expect(Store.feeDocId('BM0001', 'u1', '2026-09'), isNot(base));
      expect(Store.feeDocId('BM0002', 'u1', '2026-08'), isNot(base));
    });

    test('이름에 Firestore가 싫어하는 글자(/)가 들어가지 않는다', () {
      expect(Store.feeDocId('BM0001', 'u1', '2026-08').contains('/'), isFalse);
    });
  });

  test('사진을 저장할 때 「누가 올렸는지」를 꼭 적는다', () {
    /* 안 적으면 서버 규칙이 주인을 알 수 없어 **올린 본인도 못 지운다** →
       아무도 못 보는 사진이 남아 매달 보관 요금만 나간다. */
    final src = readSource('lib/store.dart');
    final i = src.indexOf("docRef('photos', id).set({");
    expect(i, greaterThan(0), reason: '사진 폴백 저장 자리를 못 찾았다');
    final block = src.substring(i, i + 500);
    expect(block.contains("'uid': myUid"), isTrue);
    expect(block.contains("'by': myUid"), isTrue);
  });

  group('모임 이름 바꿔도 회원이 찾을 수 있는가', () {
    /* 방장이 이름을 바꾸면 총괄 목록(META)에도 반영해야 하는데,
       **방장에게는 총괄 목록을 고칠 권한이 없다.** 그래서 옛 이름이 남고
       띄어쓰기가 다른 회원은 새 이름으로 영영 못 찾았다.
       → 방 문서에 「찾기용 이름」(titleKey)을 같이 적어 한 번에 찾는다. */
    final store = readSource('lib/store.dart');

    test('이름을 저장할 때 찾기용 이름도 같이 적는다', () {
      expect(store.contains('setClubTitle'), isTrue);
      expect(store.contains("'titleKey': normTitle(title)"), isTrue);
    });

    test('찾을 때 찾기용 이름을 먼저 쓴다', () {
      expect(store.contains("where('titleKey'"), isTrue);
    });

    test('이름을 저장하는 곳은 모두 새 방법을 쓴다', () {
      for (final f in ['lib/ui/admin.dart', 'lib/ui/settings.dart']) {
        final src = readSource(f);
        expect(src.contains("setCouple(code, {'title'"), isFalse,
            reason: '$f 가 찾기용 이름 없이 이름만 저장하고 있다');
      }
    });

    test('총괄 목록에 옛 이름이 남아도 콘솔은 방 문서에서 읽는다', () {
      final admin = readSource('lib/ui/admin.dart');
      expect(admin.contains("c['title']"), isTrue);
    });
  });

  group('목록이 길어져도 버티는가', () {
    /* 목록을 한꺼번에 다 만들면 기록이 쌓일수록 그 탭을 누르는 순간 화면이 멈칫한다.
       그리고 «말없이 잘라내면» 회원은 "기록이 이것뿐인가?"로 오해한다.
       → 화면에 보이는 것만 만들고, 자를 때는 남은 수를 알리고 더 볼 수 있게 한다. */
    test('일정은 보이는 것만 만들고, 자른 만큼 「더 보기」를 준다', () {
      final src = readSource('lib/ui/calendar.dart');
      expect(src.contains('ListView.builder'), isTrue, reason: '한꺼번에 다 만들면 안 된다');
      expect(src.contains('더 보기'), isTrue, reason: '말없이 자르면 안 된다');
      expect(src.contains('take(40)'), isFalse, reason: '고정 40개로 말없이 자르던 코드가 남아 있다');
    });

    test('회비 내역도 조금씩 보여준다', () {
      final src = readSource('lib/ui/wallet.dart');
      expect(src.contains('_shown'), isTrue);
      expect(src.contains('더 보기'), isTrue);
    });
  });

  group('채팅이 보여주는 자리', () {
    // 채팅은 늘 「가장 새 대화」가 먼저 보여야 하고, 위에서 옛 대화를 읽는 중에는
    // 새 대화가 와도 화면을 끌어내리면 안 된다.
    final src = readSource('lib/ui/chat.dart');

    test('열면 맨 아래(최신)부터 보인다', () {
      expect(src.contains('_scrollToBottom();'), isTrue);
      expect(src.contains('addPostFrameCallback'), isTrue,
          reason: '첫 그리기 뒤에 내려줘야 목록 높이가 정해진 뒤에 맞게 내려간다');
    });

    test('맨 아래를 보고 있었을 때만 새 대화를 따라 내려간다', () {
      expect(src.contains('wasAtBottom'), isTrue,
          reason: '위쪽에서 옛 대화를 읽는 중에 끌어내리면 읽던 자리를 잃는다');
    });

    test('옛 대화를 불러오는 중에는 내려가지 않는다', () {
      expect(src.contains('_keepPosition'), isTrue);
    });
  });

  test('모임 이름 견주기 — 앞뒤 공백·중간 띄어쓰기·대소문자 모두 무시', () {
    expect(Store.normTitle('  앞산 배드민턴  A방 '), Store.normTitle('앞산배드민턴a방'));
    expect(Store.normTitle('Wed  Club'), Store.normTitle('wedclub'));
    expect(Store.normTitle(null), '');
  });
}
