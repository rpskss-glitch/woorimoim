import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/* 🔒 잠긴 모임에서 사진을 올리려 하면 «고르기 전에» 말한다.

   2026-09-25 조사: 사진첩에 20장을 고르면 20장을 다 올린 뒤 기록이 거절돼 하나씩 도로 지우고,
   「0장 올렸어요 (20장 실패 — 다시 시도해주세요)」라고 했다 — 이용권 얘기는 없이 연결 탓처럼 들렸다.
   대화방 사진·회비 표 올리기·영수증도 같은 순서(먼저 올리고, 나중에 거절)였다.

   ⚠️ 기록(items)을 남기는 올리기만 본다. 가입 화면·내 정보·모임 상징은 기록이 아니라
      모임 문서를 고치는 것이라 잠겨도 된다(잠긴 방장이 결제 전에 꾸밀 수 있어야 한다). */
void main() {
  for (final (file, fn) in [
    ('lib/ui/board.dart', 'Future<void> _addPhotos('),
    ('lib/ui/chat.dart', 'await ImagePicker()'),
    ('lib/ui/fee_sheet_screen.dart', "setState(() => _busy = true);"),
    ('lib/ui/wallet.dart', 'Future<void> _pickReceipt('),
  ]) {
    test('$file — 올리기 전에 잠김을 본다', () {
      final s = File(file).readAsStringSync();
      final save = s.indexOf('await Store.i.savePhoto(code', s.indexOf(fn) - 600 < 0 ? 0 : s.indexOf(fn) - 600);
      expect(save, greaterThan(0), reason: '$file 에서 사진 올리기를 못 찾았다');
      final lock = s.lastIndexOf('Store.lockReason()', save);
      expect(lock, greaterThan(0), reason: '$file — 잠김을 안 보고 먼저 올린다');
      // 그 확인이 «이 올리기»와 같은 함수 안에 있는지 — 사이에 다른 함수가 시작되면 안 된다
      final between = s.substring(lock, save);
      expect(RegExp(r'\n  (Future<|void |Widget )').hasMatch(between), isFalse,
          reason: '$file — 잠김 확인이 다른 함수의 것이다');
    });
  }
}
