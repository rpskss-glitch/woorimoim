import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 📷 「아바타를 앨범 사진으로도 쓸 수 있다」.

   자기 사진을 아바타로 쓰는 사람이 많다. 회원 칸에는 «번호»만 적고 원본은 보관함에 둔다
   (모임 문서는 회원 모두가 실시간으로 듣고 있어서, 그림을 통째로 넣으면
    누가 글씨만 쳐도 사진이 회원 수만큼 다시 내려간다). */
void main() {
  final common = File('lib/ui/common.dart').readAsStringSync();
  final settings = File('lib/ui/settings.dart').readAsStringSync();

  String bodyOf(String src, String head) {
    final at = src.indexOf(head);
    if (at < 0) return '';
    final open = src.indexOf('{', at);
    var d = 0;
    for (var i = open; i < src.length; i++) {
      if (src[i] == '{') d++;
      if (src[i] == '}') {
        d--;
        if (d == 0) return src.substring(open, i);
      }
    }
    return src.substring(open);
  }

  group('그리기', () {
    final avatar = bodyOf(common, 'class Avatar extends StatelessWidget');

    test('보관함 사진 «번호»도 그린다', () {
      /* 예전에는 옛 `data:` 방식만 그릴 줄 알아서, 폰 사진으로 고른 아바타가
         **아무 데서도 안 보였다.** */
      expect(avatar.contains('ClubPhoto('), isTrue,
          reason: '번호만 있는 사진을 못 그리면 아바타가 빈 동그라미가 된다');
    });

    test('작게 그리는 자리라 «decodeWidth» 를 준다', () {
      final at = avatar.indexOf('ClubPhoto(');
      expect(avatar.substring(at, at + 260).contains('decodeWidth:'), isTrue,
          reason: '안 주면 원본 크기로 메모리에 올라 회원 수만큼 쌓인다');
    });

    test('못 받아와도 «이모지 얼굴»로 돌아간다', () {
      final at = avatar.indexOf('ClubPhoto(');
      expect(avatar.substring(at, at + 260).contains('placeholder:'), isTrue,
          reason: '빈 동그라미만 남으면 누구인지 아예 알 수 없다');
    });

    test('옛 «data:» 방식도 그대로 그린다', () {
      expect(avatar.contains("startsWith('data:')"), isTrue,
          reason: '웹앱에서 만든 옛 아바타가 안 보이게 되면 안 된다');
    });
  });

  group('고르기·저장', () {
    final me = bodyOf(settings, 'Future<void> _editMe()');

    test('앨범에서 고를 수 있다', () {
      expect(me.contains('ImagePicker()'), isTrue);
      expect(me.contains('앨범 사진'), isTrue);
    });

    test('이모지로 «되돌아갈» 길이 있다', () {
      /* 없으면 한번 고른 사진을 영영 못 뺀다. */
      expect(me.contains('이모지로'), isTrue);
    });

    test('회원 칸에는 «번호»만 적는다', () {
      expect(me.contains('savePhoto('), isTrue, reason: '보관함에 올려야 한다');
      final at = me.indexOf("'photo':");
      expect(at, greaterThan(0));
      expect(me.substring(at, at + 40).contains('newPhoto'), isTrue,
          reason: '그림을 통째로 넣으면 회원 모두에게 그때마다 다시 내려간다');
    });

    test('옛 원본을 «치운다» — 바꿨을 때도, 이모지로 돌아갔을 때도', () {
      expect(me.contains('oldPhoto != newPhoto'), isTrue,
          reason: '안 치우면 아무 데도 안 보이는 사진에 보관료만 계속 나간다');
    });

    test('겹침 검사는 «지금 화면에서 고른 값»으로 한다', () {
      /* 저장돼 있는 값으로 보면, 방금 「이모지로」를 눌러 사진을 뺀 사람이
         겹침 검사를 그냥 통과해 같은 이름·같은 이모지 두 사람이 생긴다. */
      expect(me.contains('willHavePhoto'), isTrue);
      final at = me.indexOf('final clash =');
      expect(at, greaterThan(0));
      expect(me.substring(at, at + 120).contains("st.me?['photo']"), isFalse,
          reason: '저장돼 있는 값으로 따지면 방금 뺀 사진을 못 알아본다');
    });
  });
}
