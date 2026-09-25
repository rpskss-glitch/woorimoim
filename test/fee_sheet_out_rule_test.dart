import 'package:flutter_test/flutter_test.dart';
import 'package:woorimoim/fee_sheet.dart';
import 'package:woorimoim/logic.dart';
import 'package:woorimoim/state.dart';
import 'package:woorimoim/store.dart';

/* 💸 지출 표도 잔액과 «같은 규칙» — 「in 만 수입, 나머지는 지출」. (2026-09-25 조사)
   지출 표(outByCat)만 「kind == 'out' 만 지출」이었다. 종류가 빠진 옛 기록(웹 백업 복원 등)은
   잔액·통계에서는 지출인데 지출 표에서는 빠져, 표 합계가 통장과 안 맞았다 —
   바로 그 «안 맞음»을 막으려고 「기타」 갈래까지 둔 표인데. */
void main() {
  final st = AppState.i;
  tearDown(() => st.setItems([]));

  test('종류가 빠진 기록도 지출 표에 «기타»로 들어가 잔액과 맞는다', () {
    st.setItems(Store.tidy([
      {'id': 'a', 'type': 'ledger', 'kind': 'in', 'amount': 100000, 'date': '2026-08-01'},
      {'id': 'b', 'type': 'ledger', 'kind': 'out', 'cat': 'court', 'amount': 30000, 'date': '2026-08-05'},
      {'id': 'c', 'type': 'ledger', 'amount': 20000, 'date': '2026-08-09'}, // 종류 없음
    ]));
    final out = FeeSheet.outByCat(['2026-08']);
    final total = out.values.fold<int>(0, (s, m) => s + (m['2026-08'] ?? 0));
    final inSum = FeeSheet.inByMonth(['2026-08'])['2026-08']!;
    expect(total, 50000, reason: '종류 없는 2만 원이 표에서 빠졌다');
    expect(inSum - total, Logic.balance(), reason: '표로 셈한 잔액이 통장과 다르다');
  });
}
