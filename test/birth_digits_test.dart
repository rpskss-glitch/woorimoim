import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/theme.dart';
import 'package:woorimoim/ui/common.dart';
import 'package:woorimoim/ui/onboarding.dart';

/* 🎂 「생년월일을 숫자 6자리로 칠 수 있는가」

   예전에는 달력에서 고르기뿐이었다. 이 앱 회원은 1960~80년대생이 많은데,
   달력으로 수십 년을 거슬러 가려면 수십 번을 눌러야 했다.
   6자리(800125)는 주민번호 앞자리 그대로라 설명이 필요 없다.

   ⚠️ 6자리의 연도는 «추정»이다(80→1980, 05→2005). 추정이 틀릴 수 있으므로
      읽어낸 날짜를 반드시 화면에 되보여 줘야 한다 — 그것까지 여기서 잠근다. */
void main() {
  group('숫자 읽기', () {
    test('6자리 — 주민번호 앞자리 그대로', () {
      expect(Logic.parseBirthDigits('800125'), DateTime(1980, 1, 25));
      expect(Logic.parseBirthDigits('051231'), DateTime(2005, 12, 31));
      expect(Logic.parseBirthDigits('200101'), DateTime(2020, 1, 1));
      /* ⚠️ 경계는 «올해 두 자리»라 해마다 움직인다 — 숫자를 박으면 해가 바뀌는 순간
         이 시험이 터진다(27을 박았다면 2027년 1월 1일에 깨졌을 것이다).
         올해보다 «한 해 뒤» 두 자리는 1900년대로 읽혀야 한다. */
      final yyNext = (DateTime.now().year % 100) + 1;
      final six = '${yyNext.toString().padLeft(2, '0')}0315';
      expect(Logic.parseBirthDigits(six)?.year, 1900 + yyNext,
          reason: '올해 뒤 두 자리($yyNext)는 1900년대로 읽어야 한다');
    });

    test('8자리 — 그대로 읽는다', () {
      expect(Logic.parseBirthDigits('19800125'), DateTime(1980, 1, 25));
      expect(Logic.parseBirthDigits('20051231'), DateTime(2005, 12, 31));
    });

    test('없는 날짜·어중간한 길이는 거른다', () {
      expect(Logic.parseBirthDigits('801325'), isNull, reason: '13월');
      expect(Logic.parseBirthDigits('800230'), isNull, reason: '2월 30일');
      expect(Logic.parseBirthDigits('80012'), isNull, reason: '5자리');
      expect(Logic.parseBirthDigits('1980012'), isNull, reason: '7자리');
      expect(Logic.parseBirthDigits(''), isNull);
      /* 허용 범위(1920~2020) 밖 — 앱의 달력과 같은 잣대라야 두 길이 안 어긋난다 */
      expect(Logic.parseBirthDigits('19190101'), isNull);
      expect(Logic.parseBirthDigits('20210101'), isNull);
    });

    test('점·빈칸이 섞여도 숫자만 읽는다', () {
      // 「1980.01.25」처럼 붙여 넣는 사람이 꼭 있다
      expect(Logic.parseBirthDigits('1980.01.25'), DateTime(1980, 1, 25));
      expect(Logic.parseBirthDigits('80 01 25'), DateTime(1980, 1, 25));
    });
  });

  group('입력칸', () {
    testWidgets('6자리를 치면 읽어낸 날짜를 «되보여 준다»', (t) async {
      DateTime? got;
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: Scaffold(body: BirthInput(onChanged: (d) => got = d)),
      ));
      await t.enterText(find.byType(TextField), '800125');
      await t.pumpAndSettle();

      /* 연도 추정(80→1980)이 틀렸으면 회원이 여기서 알아채야 한다 —
         이 되비침이 사라지면 잘못 읽힌 생년월일로 가입해 폰 바꿀 때 본인 확인이 막힌다 */
      expect(find.text('1980년 1월 25일'), findsOneWidget,
          reason: '읽어낸 날짜를 안 보여 준다 — 연도 추정이 틀려도 모른 채 가입한다');
      expect(got, DateTime(1980, 1, 25));
    });

    testWidgets('어중간하게 치면 값이 «비워진다» — 옛 값이 남지 않는다', (t) async {
      DateTime? got;
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: Scaffold(body: BirthInput(onChanged: (d) => got = d)),
      ));
      await t.enterText(find.byType(TextField), '800125');
      await t.pumpAndSettle();
      expect(got, isNotNull);

      // 지우다 만 상태 — 이때 옛 값이 남아 있으면 «화면과 다른 값»으로 가입된다
      await t.enterText(find.byType(TextField), '8001');
      await t.pumpAndSettle();
      expect(got, isNull, reason: '지우다 만 값인데 옛 날짜가 그대로 남는다');
    });

    testWidgets('가입 화면에 이 입력칸이 실제로 있다', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        theme: buildTheme('sky'),
        home: OnboardingScreen(onJoined: () {}),
      ));
      await t.pumpAndSettle();
      expect(find.byType(BirthInput), findsOneWidget,
          reason: '가입 화면이 다시 달력만으로 돌아갔다');
    });

    test('설정(내 정보)도 같은 칸을 쓴다', () {
      /* 두 자리가 다른 길을 쓰면 한쪽만 고쳐져 어긋난다 — 소스로 못 박는다 */
      const path = 'lib/ui/settings.dart';
      final src = File(path).readAsStringSync();
      expect(src.contains('BirthInput('), isTrue,
          reason: '설정의 생년월일이 다른 길로 돌아갔다');
    });
  });
}
