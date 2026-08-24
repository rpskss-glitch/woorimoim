// 「이름으로 찾은 모임」도 정리를 거치는지 (112회차).
//
// `getCouple` 은 `tidyCouple` 을 지나는데 «이름으로 찾기»만 서버 날것을 그대로 돌려줬다.
// 그 값을 **가입 화면**이 읽는다: `(x['members'] as Map?)` — 회원 목록이 글자면
// 그 자리에서 터져 가입 화면이 통째로 안 뜬다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/store.dart';

/// 가입 화면이 찾은 모임에서 «실제로 읽는» 것들
void readLikeJoinScreen(Map<String, dynamic> x) {
  final owner = (x['members'] as Map?)
      ?.values
      .whereType<Map>()
      .where((m) => m['role'] == 'owner');
  final n = (x['members'] as Map?)?.length ?? 0;
  final t = x['title'] as String?;
  final code = x['code'] as String?;
  owner?.length;
  n.abs();
  t?.length;
  code?.length;
}

void main() {
  test('망가진 모임 문서도 «읽을 수 있는» 모양으로 나온다', () {
    for (final broken in [
      {'title': '앞산', 'members': '글자'},
      {'title': 123, 'members': <int>[]},
      {'title': '앞산', 'members': {'u1': '사람이 아님'}},
      {'members': {'u1': {'uid': 'u1', 'name': 9, 'role': 'owner'}}},
    ]) {
      final c = Store.fromDoc(broken.cast<String, dynamic>(), 'AAA111');
      expect(c, isNotNull);
      expect(() => readLikeJoinScreen(c!), returnsNormally, reason: '$broken');
      expect(c!['code'], 'AAA111');
    }
  });

  test('멀쩡한 문서는 그대로 온다', () {
    final c = Store.fromDoc({
      'title': '앞산 배드민턴',
      'members': {
        'u1': {'uid': 'u1', 'name': '갑', 'role': 'owner'}
      },
    }, 'AAA111')!;
    expect(c['title'], '앞산 배드민턴');
    expect(((c['members'] as Map)['u1'] as Map)['name'], '갑');
    expect(c['code'], 'AAA111');
  });

  test('문서가 없으면 null', () {
    expect(Store.fromDoc(null, 'AAA111'), isNull);
  });

  test('«이름으로 찾기»와 «코드로 읽기»가 같은 문을 쓴다', () {
    final src = File('lib/store.dart').readAsStringSync();
    // 두 길 모두 fromDoc 을 거쳐야 한다
    final find = src.indexOf('Future<List<Map<String, dynamic>>> findClubByTitle');
    expect(find, greaterThan(0));
    final body = src.substring(find, (find + 1200).clamp(find, src.length));
    expect(body.contains('fromDoc('), isTrue,
        reason: '날것을 그대로 넘기면 가입 화면이 그 값을 읽다가 터진다');
    expect(body.contains("out[d.id] = {...d.data(), 'code': d.id};"), isFalse,
        reason: '옛 방식(정리를 안 거치는 길)이 남아 있다');

    final get = src.indexOf('Future<Map<String, dynamic>?> getCouple');
    final gbody = src.substring(get, (get + 500).clamp(get, src.length));
    expect(gbody.contains('fromDoc('), isTrue);
  });
}
