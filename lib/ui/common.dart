import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config.dart';
import '../moderation.dart';
import '../state.dart';
import '../store.dart';
import '../theme.dart';

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
}

/// 날짜 고르기에 줄 «처음 보여줄 날» — 범위 안으로 당긴다.
///
/// ⚠️ `showDatePicker` 는 `initialDate` 가 [first]~[last] 밖이면 **그 자리에서 터진다**(assert).
/// 저장된 값이 그럴 수 있다: 생년월일이 2023년(잘못 적힌 해)이거나 1900년,
/// 2020년 전에 시작한 모임, 「끝나는 날」이 모임 날보다 앞선 기록…
/// 그러면 **날짜 단추를 누르는 순간 화면이 빨개진다.**
/// (2026-08-23 실측: 생년월일 2023-05-01·1900-01-01 둘 다 터졌다)
DateTime clampDate(DateTime d, DateTime first, DateTime last) =>
    d.isBefore(first) ? first : (d.isAfter(last) ? last : d);

/// 회원 얼굴 — 사진을 넣었으면 사진, 아니면 이모지.
class Avatar extends StatelessWidget {
  final String? uid;
  final double size;
  final String? emojiOverride;
  const Avatar(this.uid, {super.key, this.size = 38, this.emojiOverride});

  @override
  Widget build(BuildContext context) {
    final st = AppState.i;
    final photo = uid == null ? null : st.photoOf(uid);
    final emoji = emojiOverride ?? (uid == null ? '🏸' : st.emojiOf(uid));
    // 되돌아갈 얼굴을 «먼저» 만들어 둔다 — 사진이 깨졌을 때도 이걸 쓴다
    Widget face() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Text(emoji, style: TextStyle(fontSize: size * .58)),
        );

    /* 📷 지금 방식 — 사진은 보관함에 있고 회원 칸에는 «번호»만 있다.
       (모임 상징이 이미 이렇게 한다. 회원 아바타만 옛 `data:` 만 그릴 줄 알아서,
        폰 사진으로 고른 아바타가 **아무 데서도 안 보였다**)
       작게 그리는 자리라 `decodeWidth` 를 꼭 준다 — 안 주면 원본 크기로 메모리에 올라
       회원 수만큼 쌓여 목록에서 앱이 무거워진다. */
    if (photo != null && photo.isNotEmpty && !photo.startsWith('data:')) {
      return ClipOval(
        child: ClubPhoto(
          photoId: photo,
          width: size,
          height: size,
          decodeWidth: (size * 3).round(),
          placeholder: face(), // 받아오는 동안·못 받아왔을 때도 빈 동그라미가 아니게
        ),
      );
    }
    if (photo != null && photo.startsWith('data:')) {
      Uint8List? bytes;
      try {
        bytes = base64Decode(photo.split(',').last);
      } catch (_) {}
      if (bytes != null) {
        return ClipOval(
          /* ⚠️ `base64Decode` 가 통과했다고 «사진»인 것은 아니다 —
             잘린 값·백업 복원 찌꺼기는 풀리기는 해도 그림이 아니다.
             그때 `Image.memory` 는 **그리는 도중에** 터지므로 위의 try 로는 못 잡는다.
             받아 내지 않으면 이모지로 되돌아가지도 못하고 **소리 없이 빈 동그라미**가 된다.
             (2026-08-23 실측: 오류 2건, 화면에는 이모지도 안 뜸) */
          child: Image.memory(bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => face()),
        );
      }
    }
    return face();
  }
}

/// 모임 상징 (방장이 꾸민 이모지·사진) — 크기·회전까지 웹앱과 같게 그린다.
/// 돌린 만큼 «자리도» 넓히는 회전.
///
/// ⚠️ `Transform.rotate` 는 **그릴 때만** 돌린다 — 차지하는 자리는 안 돈 그대로다.
/// 그래서 모임 상징을 기울이면 그림만 밖으로 삐져나와 옆·아래 글씨를 파고든다.
/// (2026-08-22 실측: 홈 카드에서 30°에 아래로 28.2px 삐져나와 모임 이름과 **18.2px 겹쳤다**.
///  45°면 21.9px. 위로도 같은 만큼 삐져나와 카드 밖으로 넘친다)
/// 안 돌렸을 때(0°)는 예전과 똑같은 자리를 쓴다 — 돌릴 때만 넓어진다.
class RotateAndFit extends SingleChildRenderObjectWidget {
  final double angle;
  const RotateAndFit({super.key, required this.angle, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => RenderRotateAndFit(angle);

  @override
  void updateRenderObject(BuildContext context, covariant RenderRotateAndFit renderObject) =>
      renderObject.angle = angle;
}

/// [RotateAndFit] 의 속 — 자리 셈과 그리기.
class RenderRotateAndFit extends RenderShiftedBox {
  RenderRotateAndFit(this._angle) : super(null);

  double _angle;
  set angle(double v) {
    if (v == _angle) return;
    _angle = v;
    markNeedsLayout();
  }

  Matrix4 get _matrix {
    final cx = size.width / 2, cy = size.height / 2;
    return Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..rotateZ(_angle)
      ..translateByDouble(-cx, -cy, 0, 1);
  }

  @override
  void performLayout() {
    final ch = child;
    if (ch == null) {
      size = constraints.smallest;
      return;
    }
    ch.layout(const BoxConstraints(), parentUsesSize: true);
    final c = math.cos(_angle).abs(), s = math.sin(_angle).abs();
    final w = ch.size.width * c + ch.size.height * s;
    final h = ch.size.width * s + ch.size.height * c;
    size = constraints.constrain(Size(w, h));
    (ch.parentData! as BoxParentData).offset = Offset(
      (size.width - ch.size.width) / 2,
      (size.height - ch.size.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.pushTransform(
        needsCompositing, offset, _matrix, (ctx, off) => super.paint(ctx, off));
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_matrix);
    super.applyPaintTransform(child, transform);
  }
}

/// 홈 카드에서 모임 상징을 그리는 «기준 크기».
/// 꾸미기 화면의 미리보기도 이 값을 써야 «보이는 대로» 저장된다
/// (예전에는 미리보기만 60이라 사진이 11% 크게 보였다).
const emblemBasePx = 54.0;

/// 상징 모서리 둥글기 — 기준 크기에 비례한다.
double emblemRadius(double base) => base * .28;

class Emblem extends StatelessWidget {
  final double basePx;
  final double capScale;
  const Emblem({super.key, this.basePx = 30, this.capScale = 3});

  @override
  Widget build(BuildContext context) {
    final e = (AppState.i.couple?['emblem'] as Map?)?.cast<String, dynamic>();
    final size = ((e?['size'] as num?)?.toDouble() ?? 1).clamp(0.5, capScale);
    final rot = ((e?['rot'] as num?)?.toDouble() ?? 0) * 3.1415926535 / 180;
    final kind = e?['kind'] as String?;
    Widget child;
    final src = e?['photo'] as String?;
    if (kind == 'photo' && src != null && src.startsWith('data:')) {
      // 옛 모임 — 사진이 모임 문서 안에 통째로 들어 있던 시절의 값
      Uint8List? bytes;
      try {
        bytes = base64Decode(src.split(',').last);
      } catch (_) {}
      // 깨진 값이면 이모지로 되돌아간다 — 상징은 «홈 맨 위»라 빈 자리가 그대로 보인다
      final fallback = Text('🏸', style: TextStyle(fontSize: basePx));
      child = bytes == null
          ? fallback
          : ClipRRect(
              borderRadius: BorderRadius.circular(emblemRadius(basePx)),
              child: Image.memory(bytes,
                  width: basePx * size,
                  height: basePx * size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback),
            );
    } else if (kind == 'photo' && src != null && src.isNotEmpty) {
      // 지금 방식 — 사진은 보관함에 있고 문서에는 번호만 있다
      child = ClubPhoto(
        photoId: src,
        width: basePx * size,
        height: basePx * size,
        radius: BorderRadius.circular(emblemRadius(basePx)),
        decodeWidth: (basePx * size * 3).round(),
        placeholder: Text('🏸', style: TextStyle(fontSize: basePx)),
      );
    } else {
      child = Text((e?['emoji'] as String?) ?? defaultAvatar, style: TextStyle(fontSize: basePx * size));
    }
    // 돌린 만큼 자리도 넓힌다 — 안 그러면 기울인 상징이 모임 이름 글씨를 파고든다
    return RotateAndFit(angle: rot, child: child);
  }
}

/// 제목 + 내용을 담는 카드 — 화면마다 같은 모양을 쓰기 위함.
class SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;
  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title!,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

/// 눌러서 «서버에 닿아야만» 되는 단추 (참석 투표·출석 체크처럼 트랜잭션을 쓰는 것).
///
/// ⚠️ 트랜잭션은 답이 올 때까지 **최대 30초**를 기다린다(`runTransaction` 의 기본값).
/// 그동안 아무 표시가 없으면 회원은 안 눌린 줄 알고 계속 누르고,
/// 누를 때마다 새 트랜잭션이 겹쳐 돌아 결과가 뒤죽박죽이 된다.
/// 그래서 도는 동안 «도는 표시»를 내고 다시 눌리지 않게 막는다.
class BusyButton extends StatefulWidget {
  final Future<void> Function() onTap;
  final Widget child;
  final ButtonStyle? style;
  const BusyButton({super.key, required this.onTap, required this.child, this.style});

  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onTap();
    } catch (e) {
      /* 부르는 쪽이 «자기 말»을 하도록 되어 있다(참석 투표·출석 체크 모두 안에서 받아낸다).
         그래도 새어 나오면 여기서 잡는다 — 안 잡으면 회원 화면이 통째로 빨개진다.
         자국은 남겨서 나중에 되짚을 수 있게 한다. */
      // ignore: avoid_print
      print('단추 처리 중 오류: $e');
    } finally {
      // 화면이 사라진 뒤에 건드리면 터진다 — 그래도 표시는 반드시 내려야 한다
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: _busy ? null : _run,
      style: widget.style,
      child: _busy
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : widget.child,
    );
  }
}


Future<bool> confirmSheet(
  BuildContext context,
  String title,
  String desc, {
  String okLabel = '확인',
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(desc),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
        FilledButton(
          /* ⚠️ 바탕만 바꾸면 **글씨색은 테마가 정한다.**
             어두운 화면의 테마 글씨는 «거의 검정»이라(옅은 강조색 위에 얹으려고),
             진한 빨강 바탕에 얹으면 2.93 밖에 안 나온다 — 되돌릴 수 없는 단추의 글씨가 안 읽힌다.
             바탕을 손대면 글씨도 «같이» 정해 줘야 한다. (2026-08-22 실측) */
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: dangerBg, foregroundColor: Colors.white)
              : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(okLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// 여러 선택지 중 하나 고르기 (웹앱의 UI.choose).
Future<String?> chooseSheet(
  BuildContext context,
  String title,
  String desc,
  List<List<String>> options,
) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    /* ⚠️ 고를 것이 몇 개일지 «정해져 있지 않다» — 같은 이름의 모임이 여럿이면 그 수만큼 생긴다.
       게다가 글자를 키워 쓰는 회원(중장년 동호회에는 흔하다)에게는 한 칸이 더 커진다.
       그냥 쌓아 두면 화면을 넘겨 **마지막 것을 아예 못 고른다**
       (2026-08-22 실측: 8개 · 글자 1.6배에서 246px, 2배에서 418px 넘침 → 마지막이 화면 밖).
       그래서 «넘치면 안에서 밀어 볼 수 있게» 한다. */
    builder: (c) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.85),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(desc, style: TextStyle(color: Theme.of(c).hintColor)),
                const SizedBox(height: 16),
                for (final o in options) ...[
                  FilledButton.tonal(
                    onPressed: () => Navigator.pop(c, o[0]),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: Text(o[1]),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String fmtWon(num? n) {
  final v = (n ?? 0).round();
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var idx = 0; idx < s.length; idx++) {
    if (idx > 0 && (s.length - idx) % 3 == 0) b.write(',');
    b.write(s[idx]);
  }
  return '${v < 0 ? '-' : ''}${b.toString()}원';
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String fmtDateFull(String? ymdStr) {
  if (ymdStr == null || ymdStr.length < 10) return '날짜 없음';
  final head = ymdStr.substring(0, 10);
  final d = DateTime.tryParse(head);
  /* ⚠️ 날짜 읽기는 **넘치는 값을 조용히 넘겨 준다** — '2026-13-45' 를 2027년 2월 14일로 읽는다.
     그대로 보여주면 **있지도 않은 날이 «그럴듯한 날»로** 화면에 뜨고 회원은 그걸 믿는다.
     되짚어서 같은 글자가 안 나오면 고친 것이므로, 적힌 글자를 그대로 보여준다(눈에 띄어야 고친다). */
  if (d == null || ymd(d) != head) return ymdStr;
  /* 올해가 아니면 «연도»를 함께 보여준다.
     ⚠️ 지난 회차 목록·옛 대화는 몇 년치를 한 줄로 늘어놓는데, 연도가 없으면
        2년 전 모임과 올해 모임이 똑같이 「8월 3일」로 보인다 — 회원은 구분할 길이 없다.
        (회비 장부는 처음부터 `2025-03-15` 로 연도를 보여 준다 — 두 곳이 어긋나 있었다)
     올해 것에는 안 붙인다: 거의 모든 줄이 올해라, 붙이면 되레 읽기 나쁘다.
     ⚠️ 「올해」는 시간이 지나면 달라진다 — 해가 바뀌는 순간은 자정이라
        `main.dart` 의 자정 시계가 화면을 깨워 준다(138회차). */
  final yearPart = d.year == DateTime.now().year ? '' : '${d.year}년 ';
  return '$yearPart${d.month}월 ${d.day}일 (${_weekdays[d.weekday - 1]})';
}

String fmtHm(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final ampm = d.hour < 12 ? '오전' : '오후';
  var h = d.hour % 12;
  if (h == 0) h = 12;
  return '$ampm $h:${d.minute.toString().padLeft(2, '0')}';
}

/// 사진 한 장 — 저장 위치에 따라 주소 형태가 다르다.
///  · Storage 사진: https 주소 → Image.network
///  · Storage를 못 쓸 때 넣어둔 사진: data:image/... 형태 → Image.memory
/// Image.network는 data: 주소를 못 읽어서, 섞어 쓰면 그 사진만 조용히 안 보인다.
class ClubPhoto extends StatefulWidget {
  final String? photoId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? radius;
  final Widget? placeholder;
  final VoidCallback? onTap;
  /// 메모리에 올릴 가로 크기 (작게 보여주는 곳은 꼭 지정한다)
  final int? decodeWidth;

  /* 그림이 «실제로 그려진» 순간 알려준다 — 그 전과 후의 **높이가 다르기 때문**이다.

     ⚠️ 자리표시는 납작한데 그림이 오면 세로로 길어진다. 대화방처럼 «맨 아래»가 중요한 목록에서는
        그 사이에 아래쪽이 화면 밖으로 밀린다 — 2026-08-29 확인: 총무가 올린 회비 표가
        회원 화면에서 안 보이고, 손으로 내려야 나왔다(표 그림은 세로로 길어 특히 심하다).
        높이를 미리 알 길이 없으니(옛 그림에는 크기가 안 적혀 있다) «그려진 뒤» 다시 맞춘다. */
  final VoidCallback? onShown;

  const ClubPhoto({
    super.key,
    required this.photoId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.radius,
    this.placeholder,
    this.onTap,
    this.decodeWidth,
    this.onShown,
  });

  @override
  State<ClubPhoto> createState() => _ClubPhotoState();

  /// [decodeWidth]는 「메모리에 올릴 때의 가로 크기」다.
  /// 안 주면 원본 그대로(1600px) 펼쳐서 한 장에 7MB쯤 잡아먹는다.
  /// 사진첩 격자처럼 작게 보여주는 곳에서 열두 장만 떠도 100MB에 가까워져
  /// 값싼 폰에서는 버벅이거나 앱이 꺼진다. 크게 볼 때(뷰어)만 원본을 쓴다.
  static Widget fromSrc(
    String src, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    int? decodeWidth,
    VoidCallback? onShown,
  }) {
    // 그림이 처음 화면에 나온 «그 프레임»에 알린다 (그때 높이가 바뀐다)
    Widget seen(Widget child, bool shown) {
      if (shown && onShown != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onShown());
      }
      return child;
    }
    /* ⚠️ 사진을 못 그리게 됐을 때 «대신 보여줄 것»을 반드시 준다.
       안 주면 Flutter가 그 자리를 **그냥 빈 칸으로 남긴다** — 사진첩에 흰 구멍이 뚫린 것처럼 보이고,
       회원은 사진이 지워진 건지 안 열린 건지 알 수 없다. */
    Widget broken() => Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          color: const Color(0x14808080),
          child: const Icon(Icons.broken_image_outlined, size: 20, color: Color(0x99808080)),
        );
    if (src.startsWith('data:')) {
      try {
        return Image.memory(base64Decode(src.split(',').last),
            width: width,
            height: height,
            fit: fit,
            cacheWidth: decodeWidth,
            frameBuilder: (_, child, frame, sync) => seen(child, sync || frame != null),
            errorBuilder: (_, _, _) => broken());
      } catch (_) {
        return broken();
      }
    }
    /* ⚠️ 받는 동안 «기다리는 표시»가 없으면 그 자리는 그냥 빈 칸이다.
       크게 보기에서는 화면이 통째로 까매서 회원은 앱이 멈춘 줄 안다. */
    return Image.network(src,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: decodeWidth,
        frameBuilder: (_, child, frame, sync) => seen(child, sync || frame != null),
        loadingBuilder: (_, child, p) => p == null
            ? child
            : SizedBox(
                width: width,
                height: height,
                child: const Center(
                  child: SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
        errorBuilder: (_, _, _) => broken());
  }

}

class _ClubPhotoState extends State<ClubPhoto> {
  /* ⚠️ 물어보는 일은 «한 번만» 걸어 둔다.
     `build` 안에서 걸면 화면을 다시 그릴 때마다 새로 물어본다 —
     상징(홈)과 채팅 사진은 **남이 글씨만 쳐도** 다시 그려지므로, 그때마다 저장소에 요청이 나간다.
     (요금·배터리·버벅임이 그만큼 늘고, 아직 못 받은 사진은 계속 깜빡인다) */
  late Future<String?> _src;

  @override
  void initState() {
    super.initState();
    _src = Store.i.getPhoto(widget.photoId);
  }

  @override
  void didUpdateWidget(ClubPhoto old) {
    super.didUpdateWidget(old);
    // 목록이 다시 그려지며 «다른 사진»이 이 자리에 오면 반드시 다시 물어본다
    if (old.photoId != widget.photoId) _src = Store.i.getPhoto(widget.photoId);
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.width, height = widget.height, radius = widget.radius;
    return FutureBuilder<String?>(
      future: _src,
      // 이미 받아둔 주소가 있으면 바로 보여준다 — 없으면 새 대화가 올 때마다 사진이 깜빡인다
      initialData: Store.i.cachedPhoto(widget.photoId),
      builder: (c, snap) {
        final src = snap.data;
        if (src == null) {
          return Container(
            width: width,
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(c).colorScheme.surfaceContainerHighest,
              borderRadius: radius ?? BorderRadius.circular(12),
            ),
            child: widget.placeholder ??
                (snap.connectionState == ConnectionState.waiting
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.image_outlined, size: 20)),
          );
        }
        final img = ClipRRect(
          borderRadius: radius ?? BorderRadius.circular(12),
          child: ClubPhoto.fromSrc(src,
              width: width,
              height: height,
              fit: widget.fit,
              decodeWidth: widget.decodeWidth,
              onShown: widget.onShown),
        );
        return GestureDetector(
          onTap: widget.onTap ?? () => showPhotoViewer(c, src),
          child: img,
        );
      },
    );
  }
}

/// 사진을 크게 보기 (손가락으로 확대·이동).
///
/// ⚠️ 닫는 길을 «눈에 보이게» 둬야 한다. 예전에는 화면을 가득 채운 대화상자뿐이라
/// 바깥을 눌러 닫으려면 **10px 테두리**를 정확히 눌러야 했고,
/// 아이폰에는 뒤로 단추도 없어 **사진을 열면 빠져나올 길이 사실상 없었다** (2026-08-22 실측).
void showPhotoViewer(BuildContext context, String src) {
  showDialog(
    context: context,
    builder: (d) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // 사진 «바깥»의 까만 데를 누르면 닫힌다 (사진을 누르면 안 닫힌다 — 확대하다 잘못 닫히지 않게)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(d),
            ),
          ),
          Center(
            child: InteractiveViewer(child: ClubPhoto.fromSrc(src, fit: BoxFit.contain)),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: '닫기',
                onPressed: () => Navigator.pop(d),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: const Color(0x66000000)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/* 🔢 「몇 개월치인가」를 고르거나 **직접 적는** 시트.

   ⚠️ 1·3·6·12개월만 주던 자리가 있었는데, 실제 모임에서는 「5개월 밀린 사람이
      한꺼번에 냈다」 같은 일이 흔하다. 그때 총무는 3개월+1개월+1개월로 세 번 나눠
      적어야 했고, 그러다 한 번 빠뜨리면 회원은 계속 미납으로 남았다.

   ⚠️ 고른 값에 «얼마인지»를 바로 붙여 보여 준다 — 총무가 받은 현금과 눈으로 맞춰 본다.
      숫자만 고르게 하면 12개월을 골라 놓고 1년치 금액을 안 세어 본 채 넘어간다. */
Future<int?> askMonths(
  BuildContext context, {
  required String title,
  required int monthly,
  int people = 1,
  int maxMonths = 36,
}) async {
  final c = TextEditingController();
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 4, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: StatefulBuilder(
        builder: (ctx, setSheet) {
          final typed = int.tryParse(c.text.trim()) ?? 0;
          final okTyped = typed >= 1 && typed <= maxMonths;
          String sum(int m) => people > 1
              ? '$m개월씩 · 모두 ${fmtWon(monthly * m * people)}'
              : '$m개월 · ${fmtWon(monthly * m)}';
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                people > 1
                    ? '$people명 · 한 사람당 월 ${fmtWon(monthly)}'
                    : '월 ${fmtWon(monthly)}',
                style: TextStyle(color: Theme.of(ctx).hintColor),
              ),
              const SizedBox(height: 14),
              for (final m in const [1, 3, 6, 12])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pop(ctx, m),
                    child: Text(sum(m)),
                  ),
                ),
              const SizedBox(height: 6),
              Text('그 밖의 개월 수', style: TextStyle(color: Theme.of(ctx).hintColor)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: c,
                      keyboardType: TextInputType.number,
                      autofocus: false,
                      decoration: const InputDecoration(
                        hintText: '예) 5',
                        suffixText: '개월',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setSheet(() {}),
                      onSubmitted: (_) {
                        if (okTyped) Navigator.pop(ctx, typed);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: inlineButtonStyle,
                    onPressed: okTyped ? () => Navigator.pop(ctx, typed) : null,
                    child: const Text('받기'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 적은 값이 얼마인지 바로 보여 준다 — 총무가 받은 현금과 맞춰 본다
              Text(
                c.text.trim().isEmpty
                    ? '1~$maxMonths개월까지 적을 수 있어요'
                    : (okTyped
                        ? sum(typed)
                        : '1~$maxMonths개월 사이로 적어주세요'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: okTyped ? FontWeight.w700 : FontWeight.w400,
                  color: okTyped ? null : Theme.of(ctx).hintColor,
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

/* 🚩 신고 — 사유를 고르게 한다 (스토어가 「무엇을 신고하는지」를 본다).
   🚫 차단 — 그 사람 글이 내 화면에서만 사라진다.

   ⚠️ 이 둘은 애플 1.2 가 요구하는 것이라 «이용자 글이 보이는 모든 자리»에 있어야 한다.
      대화방에만 두고 게시판 댓글에 빠뜨리면 그 자리가 반려 사유가 된다.
      그래서 화면마다 따로 짜지 않고 여기 한 곳에 둔다 — 길이 둘이면 한쪽만 고쳐진다. */
Future<void> reportSheet(BuildContext context, Map<String, dynamic> item,
    {String? snippet}) async {
  final code = AppState.i.code;
  if (code == null) return;
  final reason = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Text('무엇이 문제인가요?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          for (final r in Moderation.reasons)
            ListTile(title: Text(r), onTap: () => Navigator.pop(c, r)),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return;
  final ok = await Store.i.reportContent(
    code,
    targetId: item['id'] as String,
    targetBy: (item['by'] as String?) ?? '',
    reason: reason,
    // 무엇을 신고했는지 운영진이 알아볼 만큼만 (긴 글은 잘라 보낸다)
    snippet: snippet ?? ((item['text'] as String?) ?? '').trim(),
  );
  if (!context.mounted) return;
  if (!ok) return toast(context, '신고하지 못했어요 — 잠시 후 다시 해주세요');
  toast(context, '신고했어요 — 운영진이 확인합니다');
}

Future<void> blockSheet(BuildContext context, String? uid, VoidCallback onChanged) async {
  final code = AppState.i.code;
  if (code == null || uid == null) return;
  final name = AppState.i.nameOf(uid);
  final ok = await confirmSheet(
    context,
    '$name님을 차단할까요?',
    '이제부터 그분의 대화·글·사진이 내 화면에서 안 보여요.\n\n남의 화면에는 그대로 보이고, 설정에서 언제든 풀 수 있어요.',
    okLabel: '차단',
    danger: true,
  );
  if (!ok || !context.mounted) return;
  final done = await Store.i.setBlocked(code, Moderation.nextBlocked(uid, true));
  if (!context.mounted) return;
  toast(context, done ? '$name님을 차단했어요' : '차단하지 못했어요 — 다시 시도해주세요');
  onChanged();
}

/* ✏️ 「한 줄 물어보는 창」 — 이름·금액·계좌처럼 짧은 값을 받는다.

   ⚠️ **입력 그릇(TextEditingController)을 창이 스스로 들고 있어야 한다.**
      바깥에서 만들어 `Navigator.pop` 뒤에 버리면, 창이 닫히는 «몇 프레임» 동안
      아직 살아 있는 입력칸이 죽은 그릇을 읽어 **앱이 빨간 화면으로 터진다**
      (`A TextEditingController was used after being disposed`).
      2026-08-29 설정에서 「월 회비」를 저장하는 순간 실제로 터졌고,
      **이미 나간 판에도 그대로 들어 있었다** — 시험 940개가 다 통과하는데도.

   창이 들고 있으면 창이 사라질 때 Flutter 가 알아서 버린다 — 우리가 시각을 맞출 필요가 없다. */
Future<String?> askText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String? helper,
  String? suffix,
  int maxLength = 60,
  TextInputType? keyboard,
  String okLabel = '저장',
  bool obscure = false,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _AskTextDialog(
        title: title,
        initial: initial,
        hint: hint,
        helper: helper,
        suffix: suffix,
        maxLength: maxLength,
        keyboard: keyboard,
        okLabel: okLabel,
        obscure: obscure,
      ),
    );

class _AskTextDialog extends StatefulWidget {
  final String title, initial, okLabel;
  final String? hint, helper, suffix;
  final int maxLength;
  final TextInputType? keyboard;
  final bool obscure;
  const _AskTextDialog({
    required this.title,
    required this.initial,
    required this.okLabel,
    required this.maxLength,
    this.hint,
    this.helper,
    this.suffix,
    this.keyboard,
    this.obscure = false,
  });
  @override
  State<_AskTextDialog> createState() => _AskTextDialogState();
}

class _AskTextDialogState extends State<_AskTextDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    // 창이 «다 사라진 뒤»에 불린다 — 입력칸은 이미 없다
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _c,
          autofocus: true,
          obscureText: widget.obscure,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboard,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            suffixText: widget.suffix,
            counterText: '', // 글자 수는 자리를 먹는다 — 한계는 저장할 때 알린다
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(context, _c.text),
              child: Text(widget.okLabel)),
        ],
      );
}
