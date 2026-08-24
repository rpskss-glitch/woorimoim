import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/config.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 📸 「남이 올린 사진은 방장·회장·총무만 지운다」.

   사진은 되돌릴 수 없고 보관료도 걸려 있어 운영진 «전부»가 아니라 여기까지만 좁힌다.
   ⚠️ 그런데 서버 규칙(`isStaffOf`)은 role 이 owner·admin 인지만 보고 **직책은 안 본다.**
      직책만 보고 단추를 보여 주면 평회원 「총무」에게는
      **눌러도 서버가 거절하는 죽은 단추**가 된다 (회비 장부에서 실제로 그랬다). */
void main() {
  void seed({required String role, String? title}) {
    final me = <String, dynamic>{'uid': 'me', 'name': '나', 'role': role};
    if (title != null) me['title'] = title;
    AppState.i.couple = Store.tidyCouple({
      'members': {
        'me': me,
        'boss': {'uid': 'boss', 'name': '방장', 'role': 'owner'},
      },
    });
    AppState.i.profile = {'code': 'ABC', 'slot': 'me', 'name': '나'};
  }

  // 남이 올린 «사진이 든» 것과 «사진 없는» 것
  final photoOfOthers = {'id': 'p', 'by': 'boss', 'uid': 'boss', 'photoId': 'ph1'};
  final textOfOthers = {'id': 't', 'by': 'boss', 'uid': 'boss', 'text': '안녕'};
  final myPhoto = {'id': 'm', 'by': 'me', 'uid': 'me', 'photoId': 'ph2'};

  group('남의 사진', () {
    test('방장은 지운다', () {
      seed(role: 'owner');
      expect(Logic.canDeleteItem(photoOfOthers, 'me'), isTrue);
    });

    test('운영진 «회장»은 지운다', () {
      seed(role: 'admin', title: '회장');
      expect(Logic.canDeleteItem(photoOfOthers, 'me'), isTrue);
    });

    test('운영진 «총무»는 지운다', () {
      seed(role: 'admin', title: '총무');
      expect(Logic.canDeleteItem(photoOfOthers, 'me'), isTrue);
    });

    test('직책 없는 운영진은 «못» 지운다', () {
      seed(role: 'admin');
      expect(Logic.canDeleteItem(photoOfOthers, 'me'), isFalse,
          reason: '사진은 운영진 전부가 아니라 방장·회장·총무만');
    });

    test('운영진이지만 «경기이사»면 못 지운다', () {
      seed(role: 'admin', title: '경기이사');
      expect(Logic.canDeleteItem(photoOfOthers, 'me'), isFalse);
    });

    test('평회원 「총무」는 «못» 지운다 — 서버가 거절할 사람이다', () {
      seed(role: 'member', title: '총무');
      expect(Logic.canDeleteItem(photoOfOthers, 'me'), isFalse,
          reason: '직책만 보고 단추를 띄우면 눌러도 안 되는 죽은 단추가 된다');
    });

    test('평회원은 당연히 못 지운다', () {
      seed(role: 'member');
      expect(Logic.canDeleteItem(photoOfOthers, 'me'), isFalse);
    });
  });

  group('사진이 아닌 것은 그대로', () {
    test('직책 없는 운영진도 남의 «글»은 지운다', () {
      seed(role: 'admin');
      expect(Logic.canDeleteItem(textOfOthers, 'me'), isTrue,
          reason: '좁힌 것은 «사진»뿐이다 — 글까지 좁히면 방 관리가 막힌다');
    });
  });

  group('내 것', () {
    test('내가 올린 사진은 평회원도 지운다', () {
      seed(role: 'member');
      expect(Logic.canDeleteItem(myPhoto, 'me'), isTrue,
          reason: '잘못 올린 사진을 스스로 치울 수 있어야 한다');
    });

    test('누구인지 모르면 아무것도 못 지운다', () {
      seed(role: 'owner');
      expect(Logic.canDeleteItem(myPhoto, ''), isFalse);
    });
  });

  test('직책 목록은 «회장·총무» 둘이다', () {
    expect(photoBossTitles, ['회장', '총무']);
    /* 이 둘은 직책을 정할 때 운영진 권한도 같이 줄지 물어보는 목록에 있어야 한다 —
       아니면 회장·총무를 달아 줘도 서버가 거절해 영영 못 지운다. */
    for (final t in photoBossTitles) {
      expect(adminTitles.contains(t), isTrue,
          reason: '「$t」에게 운영진 권한을 줄 길이 없으면 지우기가 영영 안 된다');
      expect(titlePresets.contains(t), isTrue, reason: '고를 수 있는 직책 목록에 있어야 한다');
    }
  });

  test('사진이 든 것인지 «한 곳에서» 판단한다', () {
    /* 칸 이름을 손으로 적으면 칸이 늘 때(rcptId 처럼) 한 곳을 빠뜨린다. */
    final src = File('lib/logic.dart').readAsStringSync();
    final at = src.indexOf('static bool canDeleteItem');
    expect(at, greaterThan(0));
    expect(src.substring(at, at + 500).contains('Store.photoIdsOf(item)'), isTrue,
        reason: '사진 칸 목록은 Store.photoIdsOf 하나로 본다');
  });
}
