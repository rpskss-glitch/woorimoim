import 'state.dart';
import 'store.dart';

/* 💬 게시판 글에 다는 댓글.

   저장 모양: `{type: 'reply', replyTo: 글번호, text: '...'}` — `items` 묶음에 한 건씩 들어간다.

   ⚠️ 글 문서 «안»에 배열로 넣지 않는다. 그러면 댓글 하나를 달 때마다 글 전체를 다시 쓰게 되어
      두 사람이 거의 동시에 달면 **한쪽 댓글이 통째로 사라진다**(마지막에 쓴 사람이 이긴다).
      한 건씩 따로 두면 서로 부딪히지 않는다.

   ⚠️ `type`·`replyTo`·`text` 는 이미 서버 규칙과 «남길 칸 목록»(Store._strFields)이 아는 이름이다.
      새 이름을 만들면 저장은 되는데 **다시 읽을 때 조용히 버려진다.** */
class Comments {
  static const type = 'reply';

  /// 그 글에 달린 댓글 — 오래된 것부터 (대화처럼 위에서 아래로 읽는다)
  static List<Map<String, dynamic>> of(String postId) {
    final out = AppState.i
        .by(type)
        .where((x) => x['replyTo'] == postId)
        .toList();
    out.sort((a, b) {
      final x = (a['createdAt'] as num?)?.toInt() ?? 0;
      final y = (b['createdAt'] as num?)?.toInt() ?? 0;
      return x.compareTo(y);
    });
    return out;
  }

  /// 그 글의 댓글 수 — 목록에서 「💬 3」처럼 보여 준다
  static int count(String postId) => of(postId).length;

  /// 글자 수 한계 — 댓글은 «짧은 말»이다. 없으면 긴 글이 통째로 들어와 목록이 무너진다.
  static const maxLen = 500;

  /// 댓글 하나를 단다. 돌려주는 값은 안 됐을 때의 «까닭»(됐으면 null).
  static Future<String?> add(String postId, String text) async {
    final t = text.trim();
    if (t.isEmpty) return '내용을 적어주세요';
    if (t.length > maxLen) return '댓글은 $maxLen자까지 쓸 수 있어요';
    final code = AppState.i.code;
    if (code == null) return '모임을 찾지 못했어요';

    final id = await Store.i.addItem(code, {
      'type': type,
      'replyTo': postId,
      'text': t,
      'date': ymd(DateTime.now()),
    });
    return id == null ? '댓글을 남기지 못했어요 — 다시 해주세요' : null;
  }

  /* 댓글을 지울 수 있는 사람 — 쓴 사람 본인, 그리고 운영진.

     ⚠️ 「글쓴이」에게는 남의 댓글을 지울 권한을 주지 않는다.
        서버 규칙(`isMineDoc`·`isStaffOf`)이 그렇게 돼 있어서, 단추를 보여 줘도
        눌리면 거절당하는 «헛단추»가 된다. */
  /* ⚠️ 내 번호는 `AppState.slot` 에서 읽는다 — `Store.i.myUid` 를 쓰면
     이 판정 하나 때문에 파이어베이스가 서야 해서, 화면 없이 셈만 시험할 수 없다. */
  static bool canDelete(Map<String, dynamic> comment) =>
      comment['by'] == AppState.i.slot || AppState.i.isAdmin;

  static Future<bool> remove(String id) async {
    final code = AppState.i.code;
    if (code == null) return false;
    return Store.i.deleteItem(code, id, type);
  }

  /// 글이 지워질 때 딸린 댓글도 함께 지운다 — 안 그러면 «주인 없는 댓글»이 영영 남는다.
  static Future<void> removeAllOf(String postId) async {
    final code = AppState.i.code;
    if (code == null) return;
    for (final c in of(postId)) {
      await Store.i.deleteItem(code, c['id'] as String, type);
    }
  }
}
