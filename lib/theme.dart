import 'package:flutter/material.dart';

/// 테마 12종 — 웹앱(index.html)의 색과 같게 맞췄다.
/// 같은 모임을 웹으로 보는 회원과 앱으로 보는 회원이 같은 분위기를 보게 하기 위함.
class ClubTheme {
  final String key;
  final String label;
  final Color acc; // 강조색 (버튼·내 말풍선)
  final Color accText; // 강조색 위 글씨가 아니라, 밝은 배경 위에 쓰는 진한 강조 글씨
  final Color accLight; // 아주 옅은 강조 배경
  final Color acc2; // 옅은 강조 배경 (칩 등)
  final Color bg; // 화면 바탕

  const ClubTheme(this.key, this.label, this.acc, this.accText, this.accLight, this.acc2, this.bg);
}

const clubThemes = <ClubTheme>[
  ClubTheme('sky', '하늘', Color(0xFF5AA9E6), Color(0xFF2C72AC), Color(0xFFEAF5FF), Color(0xFFCFE9FF), Color(0xFFF3F9FF)),
  ClubTheme('mint', '민트', Color(0xFF4FBF9C), Color(0xFF27705A), Color(0xFFE6F8F1), Color(0xFFC9F0E3), Color(0xFFF3FBF7)),
  ClubTheme('forest', '숲', Color(0xFF7AA86B), Color(0xFF456638), Color(0xFFEEF6EA), Color(0xFFD8ECD0), Color(0xFFF6FBF4)),
  ClubTheme('lavender', '라벤더', Color(0xFF9A86E0), Color(0xFF6A55B8), Color(0xFFF0ECFF), Color(0xFFE5DBFF), Color(0xFFF8F6FF)),
  ClubTheme('peach', '복숭아', Color(0xFFF0946A), Color(0xFFAD552B), Color(0xFFFFF1EA), Color(0xFFFFD8C2), Color(0xFFFFF8F3)),
  ClubTheme('lemon', '레몬', Color(0xFFE5B429), Color(0xFF8A6410), Color(0xFFFFF8E2), Color(0xFFFFEEC0), Color(0xFFFFFCF2)),
  ClubTheme('grape', '포도', Color(0xFFC47AB8), Color(0xFF8C3F80), Color(0xFFFDEEFA), Color(0xFFF6DAF0), Color(0xFFFEF7FC)),
  ClubTheme('coral', '산호', Color(0xFFF2707F), Color(0xFFB23142), Color(0xFFFFEEF0), Color(0xFFFFD6DC), Color(0xFFFFF7F8)),
  ClubTheme('sage', '세이지', Color(0xFF8FB3A5), Color(0xFF3F6A5C), Color(0xFFEEF5F2), Color(0xFFD7E8E1), Color(0xFFF6FAF8)),
  ClubTheme('cocoa', '코코아', Color(0xFFC08A63), Color(0xFF7D4F2E), Color(0xFFF8EFE7), Color(0xFFECD7C4), Color(0xFFFDF8F4)),
  ClubTheme('denim', '데님', Color(0xFF7B8FC4), Color(0xFF41548A), Color(0xFFEEF1FA), Color(0xFFD8E0F3), Color(0xFFF7F9FD)),
  ClubTheme('pink', '분홍', Color(0xFFE86A8A), Color(0xFFC23D5C), Color(0xFFFFEFF4), Color(0xFFFFD9E4), Color(0xFFFFF7FA)),
];

ClubTheme themeOf(String? key) =>
    clubThemes.firstWhere((t) => t.key == key, orElse: () => clubThemes.first);

/// 강조색 위에 얹는 글씨색 — 어두운 바탕에서는 검정 계열을 쓴다.
const onAccentDark = Color(0xFF241D24);

/* 💰 돈 색 — 카드 위에 얹는 «글씨»라 밝고 어두운 화면에서 각각 달라야 한다.
   예전에는 `Colors.teal`·`Colors.redAccent` 를 그대로 썼는데 실측해 보니
     · 밝은 화면: 들어온 돈 3.67 · 나간 돈 3.19
     · 어두운 화면: 들어온 돈 4.13
   으로 기준(4.5:1)에 못 미쳤다. **모임에서 가장 중요한 숫자가 안 읽히던 자리다.**
   테마 색과 달리 이 둘은 뜻이 정해져 있어(들어옴=초록, 나감=빨강) 테마를 따라가지 않는다. */
const _moneyInLight = Color(0xFF00695C); // 카드 위 6.61
const _moneyInDark = Color(0xFF4DD0A7); // 카드 위 7.87
const _moneyOutLight = Color(0xFFC62828); // 카드 위 5.62
const _moneyOutDark = Color(0xFFFF8A80); // 카드 위 6.64

Color moneyIn(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? _moneyInDark : _moneyInLight;
Color moneyOut(BuildContext c) =>
    Theme.of(c).brightness == Brightness.dark ? _moneyOutDark : _moneyOutLight;

/* ⚠️ 위험한 동작(지우기·탈퇴·나가기)을 가리키는 빨강.
   실측해 보니 `Colors.redAccent` 는
     · 카드 위 글씨 — 밝은 화면 3.19
     · **위험 단추의 흰 글씨 — 밝음·어두움 둘 다 3.19**
   으로 기준(4.5:1)에 못 미쳤다. **되돌릴 수 없는 단추의 글씨가 가장 안 읽히던 셈이다.**
   글씨는 화면 밝기에 따라 바뀌어야 하고(돈 색과 같은 짝),
   단추 «바탕»은 흰 글씨를 얹으므로 밝기와 상관없이 진한 빨강 하나면 된다. */
Color dangerText(BuildContext c) => moneyOut(c);

/* 💬 말풍선 «안»의 인용 띠 — 답장을 달았을 때 원래 대화를 보여 주는 자리.
   ⚠️ 글씨와 «같은 색»을 옅게 깔면 둘이 서로 가까워져 안 읽힌다.
   내 말풍선은 글씨가 onPrimary 인데 띠도 onPrimary 16%를 깔고 있었다.
   실측: 12테마 × 밝음/어두움 **24개 짝이 전부 미달**(최저 2.83, 기준 4.5).
   띠는 글씨의 «반대쪽»으로 눌러야 한다 — 밝은 화면은 검정, 어두운 화면은 흰색.
   그러면 최저가 6.40으로 오른다. */
/// 밝기만 주면 되는 «순수한» 쪽 — 시험이 이걸 그대로 써서 방향까지 붙든다.
Color quoteTintFor(Brightness b) =>
    b == Brightness.dark ? Colors.white : Colors.black;

Color quoteTint(BuildContext c) => quoteTintFor(Theme.of(c).brightness);

/// 줄(Row) 안에 넣는 작은 단추 — 가로를 꽉 채우지 않는다.
/// (테마의 기본값은 «가로 꽉 채우기»라, 그대로 두면 옆 글자가 0폭으로 눌린다)
final inlineButtonStyle = FilledButton.styleFrom(
  minimumSize: const Size(0, 40),
  padding: const EdgeInsets.symmetric(horizontal: 14),
  visualDensity: VisualDensity.compact,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// 인용 띠의 진하기 — 시험이 이 값으로 겹쳐 재기 때문에 여기 한 곳에만 둔다.
const quoteTintAlpha = 0.16;

/// 위험 단추의 바탕 — 흰 글씨와 5.62
const dangerBg = Color(0xFFC62828);

/// 시험이 견주기 위한 목록 (밝음, 어두움)
const moneyColors = <String, (Color, Color)>{
  '들어온 돈': (_moneyInLight, _moneyInDark),
  '나간 돈': (_moneyOutLight, _moneyOutDark),
};

ThemeData buildTheme(String? key, {bool dark = false}) {
  final t = themeOf(key);
  /* 말풍선·버튼처럼 「강조색 위에 글씨」를 얹는 곳은 대비가 중요하다.
     밝은 화면에서 옅은 강조색(t.acc) 위에 흰 글씨를 쓰면 대비가 2.5:1밖에 안 나와
     밝은 데서 글씨가 안 읽힌다(기준 4.5:1). 그래서
       · 밝은 화면 → 진한 강조색 바탕 + 흰 글씨 (약 5:1)
       · 어두운 화면 → 옅은 강조색 바탕 + 검정 글씨 (약 6.5:1)
     로 짝을 바꾼다. (웹앱도 같은 방식이었다) */
  final primary = dark ? t.acc : t.accText;
  final onPrimary = dark ? onAccentDark : Colors.white;
  final scheme = ColorScheme.fromSeed(
    seedColor: t.acc,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
  );
  final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF16181C) : t.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF1E2126) : Colors.white,
      foregroundColor: dark ? Colors.white : const Color(0xFF2A2E35),
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF23262C) : Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    // 하단 탭바는 반드시 불투명 — 반투명으로 두면 뒤 카드가 비쳐 글씨가 안 읽힌다
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF1E2126) : Colors.white,
      indicatorColor: dark ? t.acc.withValues(alpha: .28) : t.accLight,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 62,
    ),
    /* ⚠️ 여기서 색을 박으면 **「살짝 채운 단추」(FilledButton.tonal)까지** 그 색이 된다.
       그러면 참석/불참·회비 받기처럼 «고른 것만 진하게» 보여 주려던 단추가
       **고른 것과 안 고른 것이 똑같아져** 회원이 자기가 투표했는지 알 수 없다.
       (2026-08-22 실측: 밝음·어두움 둘 다 같은 색)
       색은 이미 ColorScheme 의 primary/onPrimary 로 정해 두었으므로 여기서 다시 안 박는다 —
       진한 단추는 그대로 primary, 살짝 채운 단추는 옅은 짝을 쓴다. */
    /* ⚠️ 아래 filledButtonTheme 의 `Size.fromHeight(50)` 은 **가로를 꽉 채우라**는 뜻이다.
       큰 단추(저장·가입)는 그래야 하지만, **줄(Row) 안에** 그 단추를 두면
       옆에 있는 글이 폭 0으로 눌려 «한 글자씩 세로로» 쪼개진다
       (2026-08-24 에뮬레이터에서 회비 화면이 실제로 그랬다).
       줄 안에서 쓰는 단추는 반드시 이 style 을 얹는다. */
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF23262C) : Colors.white,
      /* 적는 칸의 «테두리». 손으로 고른 회색이었는데 실측해 보니
         바탕과 1.12~1.68 밖에 안 나와, 카드 안에 놓인 칸은 **테두리가 안 보였다**
         (어두운 화면에서는 칸 바탕까지 카드와 같은 색이라 칸의 자리를 알 수 없었다).
         scheme.outline 은 Material 이 바로 이 자리에 쓰라고 주는 색이고
         테마 색이 섞여 나와 12테마 모두 4.2 이상이 나온다. */
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? const Color(0xFF23262C) : t.accLight,
      /* 「고른 칩」도 버튼과 «같은 짝»을 써야 한다.
         옅은 강조색(t.acc) 위에 흰 글씨를 얹으면 밝은 화면에서 대비가 2~3:1밖에 안 나와
         (레몬은 1.93:1) 밖에서 무엇을 골랐는지 안 보인다. 기준은 4.5:1.
         버튼은 이미 primary/onPrimary 짝으로 고쳐 두었는데 칩만 빠져 있었다. */
      selectedColor: primary,
      labelStyle: TextStyle(color: dark ? Colors.white70 : t.accText, fontWeight: FontWeight.w600),
      secondaryLabelStyle: TextStyle(color: onPrimary, fontWeight: FontWeight.w700),
      /* ⚠️ 안 고른 칩은 «테두리»가 없으면 자리를 알 수 없다.
         2026-08-22 실측: 어두운 화면에서 칩 바탕(0xFF23262C)이 카드 색과 **완전히 같아** 대비 1.00.
         「모두 받기 / 공지만 / 끄기」처럼 고르는 칩이 **글씨만 둥둥 떠 있는 것**으로 보여
         누를 수 있는 것인 줄 모른다. 밝은 화면도 1.06~1.11 로 사실상 없는 것과 같았다.
         고른 칩은 색이 진해져 이미 드러나므로 테두리를 두르지 않는다. */
      side: WidgetStateBorderSide.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? BorderSide.none
              : BorderSide(color: scheme.outline)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2A2E35),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
