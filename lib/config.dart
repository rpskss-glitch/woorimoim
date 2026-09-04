import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 앱 전체 설정 — 웹앱(index.html)의 APP_CONFIG와 같은 값을 쓴다.
/// 같은 Firebase 방을 보기 때문에 웹으로 가입한 회원과 앱으로 가입한 회원이
/// 같은 모임에서 그대로 섞여 쓸 수 있다 (아이폰 회원은 웹, 안드로이드는 이 앱).
class Cfg {
  /* 어느 앱으로 만든 것인지 — **꾸러미 이름을 보고 스스로 안다.**
       com.taejinsoft.woorimoim  → 판매용 「우리 모임」
       com.taejinsoft.apsanclub  → 앞산 배드민턴 동호회용
     기능은 완전히 같고 이름만 다르다. 데이터도 같은 곳을 보므로 두 앱이 같은 모임에 섞여도 된다.

     ⚠️ 예전에는 `--dart-define=BRAND=…` 로 사람이 알려줬는데, 그걸 빠뜨리면
     **겉은 앞산인데 속은 우리 모임인 앱**(이름·Firebase 열쇠가 어긋난 앱)이 조용히 나왔다.
     이제 꾸러미 이름에서 스스로 알아내므로 어긋날 수가 없다. */
  static const _apsanPackage = 'com.taejinsoft.apsanclub';

  static String _package = '';

  /// 앱이 시작할 때 한 번 불러 꾸러미 이름을 알아 둔다 (Firebase를 켜기 «전»에).
  static Future<void> detectBrand() async {
    try {
      _package = (await PackageInfo.fromPlatform()).packageName;
    } catch (_) {
      /* 못 읽으면 **앞산으로 본다.** 지금 쓰는 앱이 앞산이기 때문이다.
         판매용으로 되돌리면, 앞산 회원 폰에서 이름을 못 읽었을 때
         **엉뚱한 Firebase 열쇠로 등록해 알림이 아예 안 온다.** */
      _package = _apsanPackage;
    }
  }

  static String get brand => isApsan ? 'apsan' : 'woori';

  static bool get isApsan => _package == _apsanPackage;

  static String get appName => isApsan ? '앞산 배드민턴' : '우리 모임';

  /// 화면에 보여줄 버전. **pubspec.yaml의 version과 같아야 한다.**
  /// (어긋나면 회원에게 버전을 물어봤을 때 엉뚱한 답을 듣고 엉뚱한 데를 찾게 된다)
  /// 시험(test/store_test.dart)이 둘을 견줘서 어긋나면 알려준다.
  static const version = '1.5.1';

  /// Firestore 경로 구분자 — 커플앱(hana-couple-v1)과 데이터가 섞이지 않게 하는 열쇠.
  /// 절대 바꾸면 안 된다: 바꾸는 순간 기존 모임 데이터가 안 보인다.
  static const appId = 'apsan-badminton-v1';

  /* 📸 «스토어 스크린샷 찍기» 모드 — `--dart-define=SHOTS=true` 로 지을 때만 참.
     ⚠️ `SHOTS=1` 로 주면 «안 켜진다» — `bool.fromEnvironment` 는 «true» 라는 글자만 참으로 읽는다.
        2026-08-25 이것 때문에 다섯 장이 전부 가입 화면으로 똑같이 찍혔다(빌드 45분을 날렸다). */
  static const shotMode = bool.fromEnvironment('SHOTS');

  /* 🔑 총괄 관리자 비밀번호는 **여기 두지 않는다.**

     예전에는 `adminPass = '123123'` 이 이 자리에 있었다. 그런데 앱에 적은 값은
     비밀이 아니다 — 설치 파일(APK·IPA)을 뜯으면 글자가 그대로 보인다.
     웹앱 쪽은 아예 브라우저에서 코드를 열면 읽혔다.
     그때는 「기기 한 대만」이 진짜 방어선이었는데, 그 폰을 잃으면
     **아무 기기에서도 총괄 콘솔에 못 들어갔다.**

     이제 아이디·이름·생년월일을 **서버 함수(adminLoginApsan)** 가 확인한다.
     값은 서버 시크릿에만 있고, 맞으면 그 기기를 «허락받은 기기»에 넣어 준다.
     그래서 어느 기기에서든 들어갈 수 있고, 잃어버린 기기는 콘솔에서 뺀다. */

  /// 웹앱과 같은 프로젝트. 안드로이드·아이폰이 각각 자기 열쇠를 쓴다
  /// (android/app/google-services.json, ios/Runner/GoogleService-Info.plist 와 같은 값).
  /* ⚠️ 앱마다 Firebase 열쇠가 다르다.
     앱을 둘로 나눈 뒤에도 열쇠를 하나로 두면, 앞산 앱이 「우리 모임」의 열쇠로 등록하게 되어
     **알림이 엉뚱한 곳으로 가거나 아예 안 온다.** 갈래에 맞는 것을 골라 쓴다.
     (값은 android/app/src/{woori,apsan}/google-services.json 과 같아야 한다 — 시험이 대조한다) */
  static const _androidWoori = FirebaseOptions(
    apiKey: 'AIzaSyAfcPqqeVz2STcl-yiHqZLJ2KSa0uPvFHY',
    appId: '1:267251126205:android:6f55ddd2d6c1ae8d5accd4', // woorimoim2 (판매용)
    messagingSenderId: '267251126205',
    projectId: 'wedding-246e7',
    storageBucket: 'wedding-246e7.firebasestorage.app',
  );

  static const _androidApsan = FirebaseOptions(
    apiKey: 'AIzaSyAfcPqqeVz2STcl-yiHqZLJ2KSa0uPvFHY',
    appId: '1:267251126205:android:62a5e7cea1a0b7a75accd4',
    messagingSenderId: '267251126205',
    projectId: 'wedding-246e7',
    storageBucket: 'wedding-246e7.firebasestorage.app',
  );

  static FirebaseOptions get _android => isApsan ? _androidApsan : _androidWoori;

  static const _ios = FirebaseOptions(
    apiKey: 'AIzaSyCDj_kJ1_Wg0-e8qUwFpC7JYAdsqh5qn_M',
    appId: '1:267251126205:ios:77145d72d6dbd5e85accd4',
    messagingSenderId: '267251126205',
    projectId: 'wedding-246e7',
    storageBucket: 'wedding-246e7.firebasestorage.app',
    iosBundleId: 'com.taejinsoft.woorimoim',
  );

  static FirebaseOptions get options =>
      defaultTargetPlatform == TargetPlatform.iOS ? _ios : _android;
}

/* 🏸 아바타를 «안 골랐을 때» 쓰는 얼굴.

   ⚠️ 아홉 곳에 같은 글자가 흩어져 있었다. 그중 한 곳은
     `((m['emoji'] …) ?? '🏸') == ((p['emoji'] …) ?? '🏸')`
   처럼 **기본값 «둘»을 서로 견주는** 자리다(같은 이름·같은 아바타 막기).
   그 둘이 어긋나면 «없는 아바타끼리»가 서로 다른 것으로 보여
   **겹침 검사가 조용히 멈춘다** — 같은 이름·같은 얼굴이 그대로 들어온다(184회차).
   한 곳에 두면 어긋날 수가 없다. */
const defaultAvatar = '🏸';

/// 회원 아바타로 쓰는 이모지 — 웹앱과 같은 목록이라야 서로 같은 얼굴로 보인다.
const avatarGroups = <String, List<String>>{
  '예쁨 · 잘생김': ['🧑', '👩', '👨', '👸', '🤴', '🧕', '👳', '👮', '🕵', '💂', '🥷', '👰'],
  '기본': ['🙂', '😊', '😎', '🤗', '🤓', '🧐', '😇', '🥳', '😺', '🐶', '🐰', '🦊'],
  '운동': ['🏸', '🎾', '⚽', '🏀', '⚾', '🏐', '🏓', '🥊', '🏊', '🚴', '🏃', '🧗'],
  '특별한 날': ['🎉', '🎂', '🎁', '🌸', '🌟', '🔥', '💎', '🍀', '🌈', '☀', '🌙', '⛄'],
};

List<String> get allAvatars =>
    avatarGroups.values.expand((e) => e).toList(growable: false);

/// 직책 — 권한(role)과는 별개. 방장만 지정할 수 있다.
const titlePresets = [
  '회장', '부회장', '총무', '경기이사', '재무이사', '섭외이사',
  '감사', '고문', '코치', '주장', '총무보', '회계',
];

/* 👑 **묻지 않고 바로 운영진이 되는 직책.**
   회장·총무는 모임을 실제로 굴리는 자리다. 권한 없이 직책만 주면
   회원 승인도 일정 관리도 못 해 «이름뿐인 직책»이 된다.
   ⚠️ 여기 넣는 직책은 «회원 승인·모임 설정»을 여는 것이라 함부로 늘리면 안 된다. */
const autoStaffTitles = ['회장', '총무'];

/// 이 직책을 고르면 운영진 권한도 같이 주자고 «물어본다» (위 둘은 안 묻고 바로 준다).
const adminTitles = ['회장', '부회장', '총무', '경기이사', '재무이사', '섭외이사'];

/* 📸 **남이 올린 사진을 지울 수 있는 직책.**
   사진은 한 번 지우면 되돌릴 수 없고 보관료도 걸려 있어, 운영진 «전부»가 아니라
   이 직책만 손대게 좁힌다. 방장은 직책과 무관하게 항상 가능하다.

   ⚠️ **직책만으로는 안 된다 — 운영진 권한(role)도 있어야 한다.**
   서버 규칙(`isStaffOf`)은 role 이 owner·admin 인지만 보고 직책은 안 본다.
   직책만 보고 단추를 보여 주면 평회원 「총무」에게는 **눌러도 서버가 거절하는 죽은 단추**가 된다.
   (회비 장부에서 실제로 그랬다 — logic.dart 의 canDeleteItem 설명 참고)
   직책을 「회장·총무」로 정하면 앱이 운영진 권한도 같이 줄지 물어본다(adminTitles). */
const photoBossTitles = ['회장', '총무'];

/// 회비를 다룰 수 있는 직책 (방장은 직책과 무관하게 항상 가능).
const treasurerTitles = ['총무', '재무이사', '총무보', '회계'];
