import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee_sheet.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';

/* ⏱️ 「회비 표가 큰 모임에서도 끊기지 않는가」

   2026-08-29 에뮬에서 회비 화면을 여는 순간 앱이 멈추고
   「Skipped 833 frames」가 찍혔다. 예외가 아니라 **본 실이 막힌** 것이다.
   추측하지 말고 재 둔다 — 큰 모임(회원 40명 · 장부 1200건)에서
   표 한 장을 세는 데 몇 ㎳가 드는지.

   한 프레임은 16.7㎳다. 값싼 폰은 여기서 서너 배가 드니,
   이 셈이 100㎳를 넘으면 실제 폰에서는 눈에 보이게 끊긴다. */
void main() {
  final st = AppState.i;

  setUp(() {
    final members = <String, dynamic>{};
    for (var i = 0; i < 40; i++) {
      members['u$i'] = {
        'uid': 'u$i',
        'name': '회원$i',
        'role': 'member',
        'joinedAt': DateTime(2024, 1, 1).millisecondsSinceEpoch,
      };
    }
    st.profile = {'code': 'C', 'slot': 'u0', 'name': '회원0'};
    st.setCouple({
      'fee': {'amount': 20000},
      'members': members,
    });

    final items = <Map<String, dynamic>>[];
    var n = 0;
    // 장부 — 회원 40명 × 24달치 회비 = 960건
    for (var i = 0; i < 40; i++) {
      for (var m = 0; m < 24; m++) {
        final y = 2024 + (m ~/ 12);
        final mm = (m % 12) + 1;
        items.add(<String, dynamic>{
          'id': 'i${n++}',
          'type': 'ledger',
          'kind': 'in',
          'payer': 'u$i',
          'amount': 20000,
          'date': '$y-${mm.toString().padLeft(2, '0')}-05',
        });
      }
    }
    // 지출 120건
    for (var m = 0; m < 24; m++) {
      final y = 2024 + (m ~/ 12);
      final mm = (m % 12) + 1;
      for (final cat in ['court', 'shuttle', 'gear', 'party', 'etc']) {
        items.add(<String, dynamic>{
          'id': 'i${n++}',
          'type': 'ledger',
          'kind': 'out',
          'cat': cat,
          'amount': 30000,
          'date': '$y-${mm.toString().padLeft(2, '0')}-03',
        });
      }
    }
    st.setItems(items);
  });

  int msOf(void Function() f) {
    final sw = Stopwatch()..start();
    f();
    sw.stop();
    return sw.elapsedMilliseconds;
  }

  test('큰 모임(40명 · 1080건)에서 12달 표를 세는 데 걸리는 시간', () {
    final members = st.memberList;
    final months = FeeSheet.monthKeys(12, now: DateTime(2026, 8, 25));
    final first = msOf(() {
      for (final m in members) {
        for (final ym in months) {
          FeeSheet.mark(m['uid'] as String, ym);
        }
      }
      for (final ym in months) {
        FeeSheet.paidCount(members, ym);
      }
    });
    final again = msOf(() {
      for (final m in members) {
        for (final ym in months) {
          FeeSheet.mark(m['uid'] as String, ym);
        }
      }
    });
    // ignore: avoid_print
    print('▶ 회비 표: 첫 번 ${first}㎳ · 다시 그릴 때 ${again}㎳');
    expect(first, lessThan(120),
        reason: '표를 여는 데 $first㎳가 든다 — 값싼 폰이면 화면이 멈춘다');
    expect(again, lessThan(30),
        reason: '다시 그릴 때마다 $again㎳ — 표를 매번 새로 만들고 있다(캐시가 안 맞는다)');
  });

  test('회원 줄마다 「몇 달 밀렸나」를 세는 데 걸리는 시간', () {
    final members = st.memberList;
    final ms = msOf(() {
      for (final m in members) {
        Logic.unpaidMonths(m['uid'] as String);
        Logic.prepaidLeft(m['uid'] as String);
      }
    });
    // ignore: avoid_print
    print('▶ 현황 화면 40명: ${ms}㎳');
    expect(ms, lessThan(60),
        reason: '회비 탭을 그릴 때마다 $ms㎳ — 대화 한 줄만 와도 그 값을 치른다');
  });

  test('지출 표도 빠르게 묶인다', () {
    final months = FeeSheet.monthKeys(12, now: DateTime(2026, 8, 25));
    final ms = msOf(() => FeeSheet.outByCat(months));
    // ignore: avoid_print
    print('▶ 지출 표: ${ms}㎳');
    expect(ms, lessThan(50), reason: '지출 표가 $ms㎳ — 탭을 옮길 때마다 멈춘다');
  });
}
