import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/ui/album.dart';

/* 🏷 사진첩 정리 모드 「태그 달기」 — 긴 설명에 붙일 때 옛 태그를 망가뜨리지 않는다. (2026-09-25 조사)
   예전에는 40자에 맞추려고 설명을 «앞에서부터 38-태그길이 자»로 그냥 잘랐다.
   그 자리가 옛 태그 한가운데면 `#결승전연습` 이 `#결승` 으로 바뀌고, 뒤에 있던 태그는 사라졌다.
   태그가 이미 여섯 개면(웹 규칙 최대 6개) 붙여도 안 보이는데 「붙였어요」라고 했다.
   이미 있던 사진·저장 실패는 셈에서 빠져 「0장에 붙였어요」만 떴다. */
void main() {
  test('짧으면 끝에 붙인다', () {
    expect(addTagToCaption('단체 사진', '대회'), '단체 사진 #대회');
    expect(addTagToCaption('', '대회'), '#대회');
  });

  test('이미 있으면 그대로(두 번 안 붙인다)', () {
    expect(addTagToCaption('단체 #대회', '대회'), '단체 #대회');
  });

  test('길면 «설명»만 줄이고 옛 태그는 온전히 남긴다', () {
    const cur = '이번 달 정기 모임에서 찍은 단체 사진입니다 모두 수고 #결승전연습';
    final out = addTagToCaption(cur, '대회')!;
    expect(out.length, lessThanOrEqualTo(40));
    expect(photoTags(out), containsAll(['결승전연습', '대회']));
    expect(photoTags(out), isNot(contains('결승')), reason: '옛 태그가 반으로 잘렸다');
    expect(out, startsWith('이번 달'));
  });

  test('태그가 설명 가운데 있어도 살린다', () {
    const cur = '#정모 이번 달 정기 모임에서 찍은 단체 사진입니다 모두 수고했어요';
    final out = addTagToCaption(cur, '대회')!;
    expect(out.length, lessThanOrEqualTo(40));
    expect(photoTags(out), containsAll(['정모', '대회']));
  });

  test('태그가 이미 여섯 개면 못 붙인다(붙여도 안 보인다)', () {
    expect(addTagToCaption('#a #b #c #d #e #f', 'g'), isNull);
  });

  test('태그만으로 40자가 넘으면 못 붙인다', () {
    expect(addTagToCaption('#가나다라마바사아자차 #가나다라마바사아자카 #가나다라마바', '대회결승전연습경기'), isNull);
  });

  test('화면은 이 규칙을 쓰고, 이미 있던 것·못 붙인 것·실패를 따로 말한다', () {
    final s = File('lib/ui/album.dart').readAsStringSync();
    final at = s.indexOf('Future<void> _tagPicked(');
    final body = s.substring(at, s.indexOf('Future<void> _delPicked(', at));
    expect(body, contains('addTagToCaption('));
    expect(body.contains('cur.substring('), isFalse, reason: '앞에서부터 잘라 옛 태그를 망가뜨린다');
    expect(body, contains('already'));
    expect(body, contains('full'));
    expect(body, contains('failed'));
  });
}
