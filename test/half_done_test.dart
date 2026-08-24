import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/* 「반만 됐을 때 하는 말」 시험.

   한 동작이 서버에 **두 번 이상** 쓰는 자리가 있다. 앞이 됐는데 뒤가 실패하면
   그냥 「저장하지 못했어요」라고 하는 것은 **거짓말**이 된다 — 방장은 아무 일도
   없었다고 믿는데 실제로는 절반이 이미 서버에 남아 있다.
   특히 권한·직책은 그 절반이 «회비 장부를 여는» 절반이라 그냥 넘어가면 안 된다.

   그래서 이 시험은 두 가지를 한다.
     ① 쓰기가 둘 이상인 자리를 «빠짐없이 세어» 새로 생기면 알려준다.
     ② 이미 아는 자리마다, 어디까지 됐는지 가려서 말하는지 못 박는다. */
void main() {
  const writes = [
    'setCouple', 'patchCouple', 'setClubTitle', 'deleteCouple', 'mutateCouple',
    'addItem', 'deleteItem', 'mutateItem', 'savePhoto', 'purgeClubData',
    'migrateFeePayer',
  ];

  String bare(String p) => File(p)
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//.*'), '');

  /// `try {` 하나를 괄호를 맞춰 떼어낸다 (다음 블록으로 새지 않게)
  List<String> tryBlocks(String s) {
    final out = <String>[];
    for (final m in RegExp(r'\btry\s*\{').allMatches(s)) {
      var depth = 0, i = m.end - 1;
      for (; i < s.length; i++) {
        if (s[i] == '{') depth++;
        if (s[i] == '}') { depth--; if (depth == 0) break; }
      }
      out.add(s.substring(m.end, i));
    }
    return out;
  }

  int countWrites(String block) => writes
      .map((w) => RegExp('await Store[.]i[.]$w[(]').allMatches(block).length)
      .fold(0, (a, b) => a + b);

  /// 쓰기가 둘 이상인 자리 — «전부» 여기 적혀 있어야 한다.
  /// 값은 그 자리가 「어디까지 됐는지」를 들고 있는 표시 이름.
  const known = <String, List<String>>{
    'lib/ui/admin.dart': ['roomMade', 'roomDone'], // 방 만들기(되돌리기), 이름 바꾸기
    'lib/ui/members.dart': ['titleDone', 'roleDone'], // 직책 주기, 권한 내리기
  };
  /// 지우기는 표시가 없어도 된다 — 한 걸음씩 나아가기만 하고 되돌릴 것이 없어서,
  /// 「지운 것까지는 그대로예요」로 이미 사실대로 말한다.
  const noFlagOk = 1; // admin.dart 의 _delete

  /* 표시(플래그)가 «필요 없는» 자리 — **되돌리기가 있어서** 반만 남지 않는다.
     사진 올리기는 「보관함에 올리기 → 기록 남기기」 두 걸음인데,
     뒤가 실패하면 `dropPhotos` 로 방금 올린 원본을 도로 치우고 「$fail장 실패」로 알린다.
     (171회차에 사진 한 장씩을 try 로 감싸면서 이 자리가 새로 잡혔다) */
  /// ⚠️ 수는 «겹친 try» 까지 센다 — 사진 올리기는 바깥(단추 되살리기)과
  ///    안쪽(진행 수 올리기) 두 겹이라 한 자리가 2로 잡힌다.
  const rollbackOk = <String, int>{
    'lib/ui/board.dart': 2, // 사진 올리기 — 실패하면 원본을 치운다 (두 겹)
  };

  test('한 동작이 두 번 쓰는 자리가 «늘어나면» 알려준다', () {
    final found = <String, int>{};
    for (final f in Directory('lib/ui').listSync().whereType<File>()) {
      final p = f.path.replaceAll(r'\', '/');
      final n = tryBlocks(bare(p)).where((b) => countWrites(b) >= 2).length;
      if (n > 0) found[p] = n;
    }
    expect(found.keys.toSet(), {...known.keys, ...rollbackOk.keys},
        reason: '두 번 쓰는 자리가 새로 생겼거나 사라졌다 — '
            '앞이 됐는데 뒤가 실패했을 때 무슨 말을 하는지 확인하고 known 에 적어라');
    expect(found['lib/ui/admin.dart'], known['lib/ui/admin.dart']!.length + noFlagOk);
    expect(found['lib/ui/members.dart'], known['lib/ui/members.dart']!.length);
    expect(found['lib/ui/board.dart'], rollbackOk['lib/ui/board.dart']);
  });

  test('되돌리기로 넘어가는 자리는 «정말로» 되돌린다', () {
    // 표시를 안 두는 대신 되돌리기가 반드시 있어야 한다 — 없으면 원본만 남아 요금이 샌다
    final s = bare('lib/ui/board.dart');
    final blk = tryBlocks(s).firstWhere((b) => countWrites(b) >= 2, orElse: () => '');
    expect(blk, isNotEmpty);
    expect(blk, contains('dropPhotos([photoId])'),
        reason: '기록을 못 남겼는데 «방금 올린 원본»을 안 치운다 — '
            '아무도 못 보는 파일에 보관 요금만 매달 나간다');
  });

  test('갈라 말하는 곳이 «catch 안»이다 — 표시만 두고 안 보면 소용없다', () {
    for (final e in known.entries) {
      final s = bare(e.key);
      for (final flag in e.value) {
        // `} catch (_) {` 부터 그 블록 끝까지에 표시가 나와야 한다
        var seen = false;
        for (final m in RegExp(r'catch\s*\(_\)\s*\{').allMatches(s)) {
          var depth = 0, i = m.end - 1;
          for (; i < s.length; i++) {
            if (s[i] == '{') depth++;
            if (s[i] == '}') { depth--; if (depth == 0) break; }
          }
          if (s.substring(m.end, i).contains(flag)) seen = true;
        }
        expect(seen, isTrue,
            reason: '${e.key} 의 catch 가 $flag 를 안 본다 — '
                '앞이 됐는데도 「저장하지 못했어요」라고 «거짓말»을 한다');
      }
    }
  });

  test('권한·직책이 반만 됐을 때는 «회비 장부»를 짚어 준다', () {
    // 남은 절반이 하필 회비 장부를 여는 절반이라, 그 말이 빠지면 방장이 못 알아챈다
    final s = bare('lib/ui/members.dart');
    final catches = RegExp(r'catch\s*\(_\)\s*\{').allMatches(s).map((m) {
      var depth = 0, i = m.end - 1;
      for (; i < s.length; i++) {
        if (s[i] == '{') depth++;
        if (s[i] == '}') { depth--; if (depth == 0) break; }
      }
      return s.substring(m.end, i);
    }).where((c) => c.contains('titleDone') || c.contains('roleDone')).toList();
    expect(catches.length, 2, reason: '직책·권한 두 자리 모두 갈라 말해야 한다');
    for (final c in catches) {
      expect(c, contains('회비 장부'),
          reason: '반만 된 것을 알리면서 «회비 장부가 열려 있다»는 말이 빠졌다 — '
              '방장이 권한을 뗐다고 믿는 사이 그 사람은 회비를 계속 고칠 수 있다');
    }
  });
}
