import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 🕳 「아무도 안 보고 있던 자리」 일곱 곳 (167회차).

   소스 22군데에 일부러 흠을 내고 시험 전체(681개)를 돌렸더니 **7곳이 안 물렸다.**
   일곱 다 지금 코드는 맞다 — 지키는 시험이 없었을 뿐이다. */
void main() {
  String ym(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  final now = DateTime.now();
  String plus(int n) {
    final t = DateTime(now.year, now.month + n);
    return ym(t);
  }

  void seed(List<Map<String, dynamic>> ledger) {
    AppState.i.couple = Store.tidyCouple({
      'fee': {'amount': 20000},
      'members': {
        'u1': {'uid': 'u1', 'name': '갑', 'joinedAt': 1690000000000}
      },
    });
    AppState.i.setItems(Store.tidy([
      for (var i = 0; i < ledger.length; i++) {'id': 'l$i', 'type': 'ledger', ...ledger[i]}
    ]));
  }

  Map<String, dynamic> paid(List<String> months, {String kind = 'in', String payer = 'u1'}) =>
      {'kind': kind, 'amount': 20000, 'payer': payer, 'feeMonths': months, 'date': '${plus(0)}-05'};

  test('① 선납은 «빈 달»에서 멈춘다', () {
    // 다음 달과 세 달 뒤를 냈다 — 두 달 뒤는 비었다
    seed([paid([plus(0), plus(1), plus(3)])]);
    expect(Logic.prepaidLeft('u1'), 1,
        reason: '중간이 빈 채로 「앞으로 N달치 채워짐」이라 하면 '
            '회원이 그 빈 달을 «안 내도 되는 줄» 안다');
  });

  test('② «나간 돈»을 회비 낸 것으로 세지 않는다', () {
    /* 웹은 지출의 「누가 결제했나요?」에 **회원**을 고를 수 있다
       (회비통장 말고 회원이 제 돈으로 샀을 때). 그 기록의 payer 를 회비로 세면
       **셔틀콕 한 통 사 준 회원의 그 달 회비가 저절로 사라진다.** */
    seed([
      {'kind': 'out', 'amount': 30000, 'payer': 'u1', 'cat': 'shuttle', 'date': '${plus(0)}-03'}
    ]);
    expect(Logic.paidIn('u1', plus(0)), isFalse,
        reason: '지출 기록이 회비 낸 것으로 잡혔다');
    expect(Logic.unpaidMonths('u1'), contains(plus(0)));
  });

  test('③ 회비 기록은 «어느 달치»를 적은 대로 센다', () {
    // 이번 달에 받았지만 «두 달 전» 것이다
    seed([
      {'kind': 'in', 'amount': 20000, 'payer': 'u1', 'feeMonths': [plus(-2)], 'date': '${plus(0)}-05'}
    ]);
    expect(Logic.paidIn('u1', plus(-2)), isTrue,
        reason: '적어 둔 달치로 안 센다');
    expect(Logic.paidIn('u1', plus(0)), isFalse,
        reason: '받은 «날»의 달로 세면, 밀린 달은 영영 미납으로 남고 이번 달만 지워진다');
  });

  test('④ 출석은 «true 인 것»만 센다', () {
    AppState.i.couple = Store.tidyCouple({
      'members': {'u1': {'uid': 'u1', 'name': '갑'}, 'u2': {'uid': 'u2', 'name': '을'}}
    });
    final day = '${plus(0)}-01';
    AppState.i.setItems(Store.tidy([
      {
        'id': 'e1', 'type': 'event', 'title': '모임', 'date': day, 'repeat': 'none',
        'attend': {'${day}_u1': true, '${day}_u2': false}
      }
    ]));
    final n = Logic.attendStats();
    expect(n['u1'], 1);
    expect(n['u2'], isNull,
        reason: '「출석 취소」로 남은 false 표시를 출석으로 센다 — 배지·순위가 부풀려진다');
  });

  group('소스가 지켜야 할 차례·값', () {
    String bare(String p) => File(p)
        .readAsStringSync()
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'//.*'), '');

    test('⑤ 방을 지울 때 «기록을 먼저» 지운다', () {
      final s = bare('lib/ui/admin.dart');
      final at = s.indexOf('Future<void> _delete(');
      final body = s.substring(at, s.indexOf('Future<', at + 30));
      final purge = body.indexOf('purgeClubData(');
      final drop = body.indexOf('deleteCouple(');
      expect(purge, greaterThan(0));
      expect(purge, lessThan(drop),
          reason: '방 문서를 먼저 지우면 규칙상 아무도 그 기록에 손댈 수 없어 «영영 남는다» — '
              '대화·사진이 그대로 남아 매달 요금만 나간다');
    });

    test('⑥ 답을 기다리는 시간이 «사람이 기다릴 만한» 값이다', () {
      final s = bare('lib/store.dart');
      final m = RegExp(r'_settleWait = Duration\(seconds: (\d+)\)').firstMatch(s);
      expect(m, isNotNull, reason: '기다리는 시간을 못 찾았다 — 이 시험이 헛돌고 있다');
      final sec = int.parse(m![1]!);
      expect(sec, greaterThanOrEqualTo(3),
          reason: '너무 짧으면 멀쩡한 저장도 「답 없음」이 되어 «지운 사진이 되살아나는» 길이 열린다');
      expect(sec, lessThanOrEqualTo(15),
          reason: '너무 길면 단추를 누르고 그만큼 멈춰 있는다');
    });

    test('⑦ 회비를 받을 때 «어느 달치»를 기록에 적는다', () {
      final s = bare('lib/ui/wallet.dart');
      final at = s.indexOf("'kind': 'in'");
      expect(at, greaterThan(0));
      final blk = s.substring(at, s.indexOf('});', at));
      expect(blk, contains("'feeMonths': feeMonths"),
          reason: '어느 달치인지 안 적으면 받은 «날»의 달로 세어져, '
              '3월에 받은 1월치가 3월치가 되고 1월은 계속 미납으로 남는다');
    });

    test('⑧ 일정을 만들 때 «반복 주기»를 적는다', () {
      final s = bare('lib/ui/calendar.dart');
      final at = s.indexOf("'type': 'event'");
      expect(at, greaterThan(0));
      final blk = s.substring(at, s.indexOf('};', at));
      expect(blk, contains("'repeat':"),
          reason: '반복 주기를 안 적으면 매주 모임이 «한 번짜리»가 되어 '
              '출석·순위가 통째로 어긋난다');
      expect(blk, contains("'until':"), reason: '끝나는 날을 안 적는다');
    });
  });
}
