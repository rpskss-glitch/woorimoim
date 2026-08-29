import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'config.dart';
import 'state.dart';
import 'store.dart';

/// 앱이 꺼져 있거나 뒤에 있을 때 오는 푸시를 받아 알림을 띄운다.
///
/// 서버(pushOnMsgApsan)는 웹 브라우저에 맞춰 **데이터만** 보낸다.
/// 그 형태는 안드로이드가 스스로 알림을 띄워주지 않기 때문에, 여기서 직접 띄워야 한다.
/// (이게 없으면 앱을 닫아둔 회원에게는 알림이 아예 오지 않는다)
///
/// 이 함수는 앱과 따로 도는 자리에서 불리므로 Firebase를 다시 켜야 한다.
/* 🔔 알림에 쓰는 아이콘.
   ⚠️ **앱 아이콘(@mipmap/ic_launcher)을 쓰면 안 된다.**
   안드로이드는 알림 아이콘의 «색을 버리고 모양만» 쓴다(5.0부터).
   앱 아이콘은 파란 바탕이 92%를 채우고 있어서, 알림창에는 라켓이 아니라
   **흰 사각형 덩어리**가 뜬다 (2026-08-22 실측: 알파가 찬 픽셀 92%).
   그래서 «흰 라켓 + 투명 바탕»짜리를 따로 만들어 쓴다. */
const notifyIcon = '@drawable/ic_stat_notify';

@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage m) async {
  /* ⚠️ 여기는 앱과 **따로 도는 자리**라 `main()`에서 정해둔 것이 하나도 넘어오지 않는다.
     (Cfg의 값들은 각 자리마다 따로 있다 — 여기서는 전부 처음 상태다)
     그래서 어느 앱인지도 여기서 «다시» 알아내야 한다. 안 그러면 앞산 앱이
     「우리 모임」 열쇠로 Firebase를 켜서 알림이 뜨다 말거나 아예 안 뜬다. */
  /* ⚠️ 여기서 오류가 새어 나가면 **아무도 못 받는다** — 그 알림 한 통이 조용히 사라지고,
     안드로이드가 이 뒷자리를 접으면 뒤이은 알림까지 안 올 수 있다.
     그래서 걸음마다 따로 받아 낸다: «준비»가 실패해도 «띄우기»는 해 본다
     (알림 띄우기 자체는 Firebase 가 없어도 된다). */
  final local = FlutterLocalNotificationsPlugin();
  try {
    await Cfg.detectBrand();
    await Firebase.initializeApp(options: Cfg.options);
  } catch (_) {/* 열쇠를 못 켜도 알림은 띄울 수 있다 */}
  try {
    await local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(notifyIcon),
      ),
    );
    await local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(Push.channel);
  } catch (_) {/* 길을 못 만들어도 아래에서 띄워 본다 */}
  try {
    final d = m.data;
    // 앞에 있을 때와 «같은 자리»를 쓴다 — 안 그러면 뒤에서 온 알림만 따로 쌓인다
    final tag = Push.tagOf(d['tag']);
    await local.show(
      id: Push.slotFor(tag),
      title: (d['title'] as String?) ?? m.notification?.title ?? '새 소식',
      body: (d['body'] as String?) ?? m.notification?.body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(Push.channelId, Push.channelName,
            tag: tag, importance: Importance.high, priority: Priority.high),
      ),
    );
  } catch (_) {/* 이 한 통은 못 띄웠다 — 그래도 여기서 «던지지는» 않는다 */}
}

/// 푸시 알림 — 서버 쪽은 이미 돌아가는 pushOnMsgApsan 함수를 그대로 쓴다.
/// 그 함수는 모임 문서의 `push.{uid}.token`을 읽어 보내므로, 앱은 토큰만 같은 자리에 적어두면 된다.
/// (웹앱과 완전히 같은 구조라 서버는 손댈 필요가 없다)
class Push {
  Push._();
  static final Push i = Push._();

  /* 알림 묶음 — 앱이 켜져 있을 때와 꺼져 있을 때가 같은 묶음을 써야 설정이 하나로 유지된다.
     ⚠️ 이름을 «한 곳에서» 정한다. 예전에는 세 군데에 따로 적혀 있었는데,
     한 곳만 바뀌면 **안드로이드가 없는 묶음이라며 알림을 조용히 버린다**(오류도 안 난다). */
  static const channelId = 'club_msgs';
  static const channelName = '모임 알림';

  static const channel = AndroidNotificationChannel(
    channelId,
    channelName,
    description: '새 대화·공지 알림',
    importance: Importance.high,
  );

  /// 자국만 남기고 넘어간다 — 알림 준비가 안 되는 것은 «고장»이 아니라 «지금은 못 함»인 경우가 많다
  static void _note(Object e, String what) {
    // ignore: avoid_print
    print('알림($what): $e');
  }

  /* ⚠️ 필드로 두면 `Push.i` 를 만지는 그 순간 파이어베이스를 붙잡는다 —
     그러면 설정 화면 하나를 시험으로 띄우는 것조차 「No Firebase App」으로 터진다
     (Store 도 같은 함정이 있었다). 쓸 때만 잡는다. */
  FirebaseMessaging get _fm => FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /* 🔔 알림이 «겹칠 자리».

     서버는 알림마다 `tag` 를 함께 보낸다(지금은 대화 알림 하나뿐 — `club-msg`).
     웹은 그 값으로 **같은 갈래를 한 자리에 덮어쓴다** — 대화가 오갈 때 알림이 하나로 갱신된다.
     앱은 **메시지마다 다른 번호**를 써서 알림이 그대로 쌓였다 —
     단체방에서 대화 오십 마디면 알림창에 **오십 개**가 쌓이고 회원이 하나씩 지워야 한다.
     같은 갈래는 같은 자리에 덮어쓴다(웹과 같게). 갈래가 늘면 자리도 저절로 나뉜다. */
  static const defaultTag = 'club-msg';

  static int slotFor(Object? tag) {
    final t = tag is String ? tag.trim() : '';
    return (t.isEmpty ? defaultTag : t).hashCode;
  }

  static String tagOf(Object? tag) {
    final t = tag is String ? tag.trim() : '';
    return t.isEmpty ? defaultTag : t;
  }

  /// 받는 범위 — 단체방이라 시끄러우면 줄일 수 있게.
  static const modes = [
    ['all', '모두 받기', '새 대화가 올라오면 모두 알려드려요'],
    ['admin', '공지만', '방장·운영진이 보낸 것만 알려드려요'],
    ['off', '끄기', '알림을 보내지 않아요 (앱에서는 그대로 보여요)'],
  ];

  /* 「알림 칸」을 읽는 셈만 떼어냈다 — 서버 없이 시험할 수 있게
     (`Store.planPend`·`Store.planAfterDelete` 와 같은 방식). */
  static Map? seatIn(Map? push, String uid) => push?[uid] as Map?;

  /* 서버(`functions/index.js`)와 **똑같이** 읽어야 한다.
       const mute = v.mute || 'all';
       if (mute === 'off') continue;
       if (mute === 'admin' && !senderIsStaff) continue;
     즉 서버는 «off 도 admin 도 아니면 전부 모두 받기»로 본다 — 빈 글자도 그렇다.

     ⚠️ 예전에는 `?? 'all'` 이라 **적힌 것이 없을 때만** 「모두 받기」였다. 그래서
       · 빈 글자(`''`) — 값이 망가져 들어오면 우리 다듬기가 «스스로» 만드는 값이다
       · 모르는 값(다음 판 앱·웹이 적은 값)
     일 때 설정 화면의 칩이 **셋 다 안 골라진 채**로 보였다.
     그동안 알림은 «전부» 오고 있는데도 회원은 무엇이 켜져 있는지 알 수 없다. */
  static String modeIn(Map? push, String uid) {
    final m = seatIn(push, uid)?['mute'];
    return (m == 'off' || m == 'admin') ? m as String : 'all';
  }

  /// 이 폰이 «정말로» 알림을 받을 수 있는 상태인지 — 서버에 토큰이 적혀 있어야 한다.
  ///
  /// ⚠️ [modeIn]은 적힌 것이 없으면 'all'을 돌려준다. 그래서 알림을 한 번도 켠 적 없는 회원에게도
  /// 설정 화면이 「모두 받기」를 **켜진 것처럼** 보여 줬다 — 토큰이 없어 한 통도 안 오는데도.
  /// 「끄기」는 토큰이 없어도 말이 맞으므로 이 값과 상관없다.
  static bool readyIn(Map? push, String uid) {
    final t = seatIn(push, uid)?['token'];
    return t is String && t.isNotEmpty;
  }

  Map? get _push => AppState.i.couple?['push'] as Map?;

  String get mode => modeIn(_push, Store.i.myUid);

  bool get ready => readyIn(_push, Store.i.myUid);

  /// 이미 권한이 있으면 조용히 토큰만 갱신 (첫 화면을 막지 않게).
  Future<void> setupIfAllowed() async {
    final s = await _fm.getNotificationSettings();
    if (s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional) {
      await setup();
    }
  }

  /* 설정에서 「알림 켜기」를 눌렀을 때 — 권한을 묻고 토큰을 저장한다.

     ⚠️ **터져서 밖으로 나가면 안 된다.** 이 안에서 부르는 것들은 기기 사정으로 흔히 실패한다:
        회사폰 정책으로 알림이 막혀 있거나, 애플 토큰이 안 오거나, 파이어베이스가 안 서 있거나.
        그때 예외가 위로 새면 **설정 화면이 통째로 빨간 화면이 된다** — 알림 하나 켜려다
        앱을 못 쓰게 되는 것이다. 안 됐으면 «안 됐다»고만 돌려주고, 화면이 안내하게 한다.
        (2026-08-29: 화면의 단추를 하나씩 눌러 보는 시험이 이 자리를 잡아냈다) */
  Future<bool> setup() async {
    try {
      return await _setup();
    } catch (e) {
      _note(e, '켜기');
      return false;
    }
  }

  Future<bool> _setup() async {
    final code = AppState.i.code;
    if (code == null) return false;
    final settings = await _fm.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.denied) return false;

    await _initLocal();

    // 아이폰은 애플(APNs) 토큰이 먼저 와야 FCM 토큰이 나온다.
    // 비행기모드·느린 망에서는 몇 초 늦게 오므로 잠깐 기다렸다 다시 물어본다.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      /* 앱을 보고 있을 때 뜨는 알림은 **우리가 직접** 띄운다.
         시스템에 맡기면(alert:true) 채팅을 보는 중에도 무조건 떠서 성가시고,
         「채팅 볼 때는 띄우지 않기」 같은 규칙을 넣을 수가 없다. */
      await _fm.setForegroundNotificationPresentationOptions(
          alert: false, badge: true, sound: false);
      for (var i = 0; i < 5; i++) {
        if (await _fm.getAPNSToken() != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    String? token;
    try {
      token = await _fm.getToken();
    } catch (_) {
      token = null;
    }
    if (token == null) return false;
    final cur = (AppState.i.couple?['push'] as Map?)?[Store.i.myUid] as Map?;
    // 토큰이 그대로면 쓰지 않는다 — 쓰기 1번이 구독 중인 회원 수만큼 읽기 요금으로 곱해진다
    if (cur?['token'] != token) {
      /* ⚠️ 알림 토큰은 «그 방 회원»만 적을 수 있다 —
         **아직 승인 전이면 서버가 거절한다.** 그런데 이 자리는 앱을 켤 때마다 저절로 불리므로
         (`setupIfAllowed`), 감싸지 않으면 대기 중인 회원에게서 **아무도 안 받는 오류**가 계속 샌다.
         거절은 「지금은 못 적는다」는 뜻이지 고장이 아니다 — 승인되는 순간 다시 부른다. */
      try {
        await Store.i.setCouple(code, {
          'push': {
            /* 「알림 범위」는 여기서 쓰지 않는다 — 이 자리가 고치는 건 «토큰»뿐이다.
               set(merge:true)는 안쪽 묶음을 합쳐 주므로 안 보낸 칸은 그대로 남고,
               적힌 것이 없으면 앱도 서버도 'all'로 본다(modeIn / functions index.js).
               옛 코드는 «화면이 들고 있는 사본»에서 범위를 퍼다 같이 썼는데,
               앱을 켠 지 2초 만에 불리는 자리라 **모임 문서가 아직 안 왔으면 사본이 비어**
               'all'이 얹혔다 → 회원이 「끄기」·「공지만」으로 해 둔 것이 되살아났다. */
            Store.i.myUid: {
              'token': token,
              'at': DateTime.now().millisecondsSinceEpoch,
            }
          }
        });
      } catch (e) {
        _note(e, '토큰 적기');
        return false;
      }
    }
    // 듣기는 «한 번만» 건다 — setup()은 첫 화면·홈 카드·설정에서 저마다 불리므로
    // 그대로 두면 듣는 자리가 겹겹이 쌓여 토큰이 갱신될 때마다 같은 쓰기가 여러 번 나간다
    if (_refreshBound) return true;
    _refreshBound = true;
    _fm.onTokenRefresh.listen((t) async {
      final c = AppState.i.code;
      if (c == null) return;
      // 여기도 거절될 수 있다(탈퇴된 뒤 토큰이 갱신되는 경우) — 뒤에서 도는 자리라 더더욱 새면 안 된다
      try {
        await Store.i.setCouple(c, {
          'push': {
            // 여기도 «토큰»만 고친다 — 범위를 같이 쓰면 뒤에서 조용히 되돌려 놓는다
            Store.i.myUid: {'token': t, 'at': DateTime.now().millisecondsSinceEpoch}
          }
        });
      } catch (e) {
        _note(e, '토큰 갱신');
      }
    });
    return true;
  }

  /// 알림 받는 범위 바꾸기 — 됐는지 «돌려준다».
  /// 감싸지 않으면 서버가 거절했을 때 화면이 그 오류에 걸려
  /// **눌렀는데 아무 일도 안 일어나는 단추**가 된다 (75회차와 같은 갈래).
  Future<bool> setMode(String m) async {
    final code = AppState.i.code;
    if (code == null) return false;
    try {
      await Store.i.setCouple(code, {
        'push': {
          Store.i.myUid: {'mute': m}
        }
      });
      return true;
    } catch (e) {
      _note(e, '알림 범위 바꾸기');
      return false;
    }
  }

  /// 알림을 눌러 앱이 열렸을 때 채팅으로 데려간다.
  /// (앱이 아예 꺼져 있었던 경우까지 챙기려면 getInitialMessage도 함께 봐야 한다)
  Future<void> bindTaps() async {
    if (_tapsBound) return;
    _tapsBound = true;
    /* 앱이 «꺼져 있다» 알림으로 켜진 경우 — 직접 그린 알림은 위의 콜백이 안 불릴 수 있어
       (앱이 그때 막 살아나는 중이다) 켜질 때 한 번 물어본다. */
    try {
      final launched = await _local.getNotificationAppLaunchDetails();
      if (launched?.didNotificationLaunchApp == true) _goChat();
    } catch (_) {/* 못 물어봐도 알림 자체는 그대로 뜬다 */}
    final first = await _fm.getInitialMessage();
    if (first != null) _goChat();
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _goChat());
  }

  bool _tapsBound = false;
  bool _refreshBound = false;
  bool _msgBound = false;

  void _goChat() => AppState.i.openTab.value = 1;

  Future<void> _initLocal() async {
    if (_ready) return;
    const android = AndroidInitializationSettings(notifyIcon);
    // 아이폰은 권한을 FirebaseMessaging 쪽에서 이미 물었으므로 여기서 또 묻지 않는다
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      /* 👆 **여기를 안 이으면 알림을 눌러도 아무 일도 안 일어난다.**
         서버는 «자료만»(data-only) 보낸다 → 시스템이 알림을 안 그리고 **앱이 직접 그린다**.
         그래서 `onMessageOpenedApp`·`getInitialMessage` 는 이 앱에서는 **한 번도 안 불린다** —
         직접 그린 알림의 누름은 이 자리로 온다.
         (`bindTaps` 는 남겨 둔다 — 나중에 서버가 `notification` 을 함께 보내면 그쪽이 쓰인다) */
      await _local.initialize(
          settings: const InitializationSettings(android: android, iOS: ios),
          onDidReceiveNotificationResponse: (_) => _goChat());
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      _ready = true; // 끝까지 됐을 때만 「됐다」고 적는다 — 미리 적으면 한 번 실패한 뒤
      //               앱을 보는 중에 알림이 «조용히» 영영 안 뜬다
    } catch (_) {
      return; // 다음에 다시 해본다
    }

    if (_msgBound) return;
    _msgBound = true;
    // 앱이 열려 있을 때 온 푸시 — 안드로이드·아이폰 모두 여기서 직접 띄운다(규칙을 하나로 두려고)
    FirebaseMessaging.onMessage.listen((m) {
      // 채팅을 보고 있는데 알림까지 뜨면 성가시다 — 그 대화는 이미 화면에 나와 있다
      if (AppState.i.currentTab == 1) return;
      final d = m.data;
      final title = (d['title'] as String?) ?? m.notification?.title ?? '새 소식';
      final body = (d['body'] as String?) ?? m.notification?.body ?? '';
      // 같은 갈래는 «한 자리»에 덮어쓴다 — 안 그러면 대화마다 알림이 쌓인다
      final tag = tagOf(d['tag']);
      _local.show(
        id: slotFor(tag),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(channelId, channelName,
              tag: tag, importance: Importance.high, priority: Priority.high),
          iOS: const DarwinNotificationDetails(
              presentAlert: true, presentSound: true, threadIdentifier: defaultTag),
        ),
      );
    });
  }
}
