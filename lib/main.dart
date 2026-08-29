import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'demo.dart';
import 'logic.dart';
import 'push.dart';
import 'state.dart';
import 'store.dart';
import 'theme.dart';
import 'ui/onboarding.dart';
import 'ui/shell.dart';
import 'ui/wait.dart';

bool _bgBound = false;

/* 🚀 앱이 서 있으려면 있어야 할 것들 — 시작할 때와 「다시 시도」가 **같은 길**을 쓴다.
   ⚠️ 여기서 하나라도 터지면 `runApp` 이 아예 안 불려 **흰 화면**이 된다.
      회원에게는 아무 말도 안 보이고, 껐다 켜도 그대로다(빠져나올 길이 없다).
      실제로 터질 수 있는 자리가 여럿이다:
        · `SharedPreferences.getInstance()` — 기기에 남은 값이 깨져 있을 때
        · `Firebase.initializeApp` — 갈래(woori/apsan)와 열쇠가 어긋난 앱일 때
      그래서 통째로 받아 내고 「다시 시도」 화면으로 보낸다.
   ⚠️ 「다시 시도」가 `Store.init` 만 다시 부르면, Firebase 가 안 선 경우에는
      아무리 눌러도 살아나지 않는다 — 그래서 이 함수를 통째로 다시 부른다. */
/* ⏱️ 시작 시각 지킴이 — 이만큼 안에 못 서면 «안 선 것»으로 친다.

   ⚠️ `try/catch` 만으로는 못 막는 길이 있다: 인터넷이 반쯤 죽은 곳(응답이 «오지 않는» 곳)에서는
      Firebase 가 **던지지도, 끝나지도 않는다.** 그러면 `runApp` 이 영영 안 불려 **흰 화면**이 된다.
      실제로 애플 심사장은 막힌 망 뒤에 있는 경우가 많아, 이 자리가 2.1(미완성) 반려로 이어진다.
      그래서 시간을 재고, 넘으면 「인터넷 확인」 화면으로 보낸다 — 거기서 다시 시도할 수 있다. */
const _bootLimit = Duration(seconds: 15);

/* 「다시 시도」는 **더 오래 기다린다.**

   ⚠️ 2026-08-29 확인: 15초를 못 지킨 망에서 「다시 시도」를 눌러도 **또 15초 만에** 접었다.
      느린 망(지하 체육관·시골 운동장)에서는 아무리 눌러도 영영 못 들어간다 —
      회원이 할 수 있는 게 «앱 지우기»밖에 없어진다.
      첫 번을 짧게 두는 까닭은 흰 화면을 막기 위해서지 «빨리 포기하려고»가 아니다.
      회원이 스스로 「기다리겠다」고 누른 뒤에는 넉넉히 준다. */
const _retryLimit = Duration(seconds: 45);

Future<bool> bootstrap({Duration limit = _bootLimit}) {
  return _bootstrapOnce().timeout(limit, onTimeout: () {
    // ignore: avoid_print
    print('앱 시작이 $limit 안에 안 끝났다 — 인터넷 확인 화면으로 보낸다');
    return false;
  });
}

Future<bool> _bootstrapOnce() async {
  try {
    // 어느 앱인지 «먼저» 알아야 한다 — Firebase 열쇠가 앱마다 다르기 때문
    await Cfg.detectBrand();
    await Firebase.initializeApp(options: Cfg.options);
    if (!_bgBound) {
      _bgBound = true;
      // 앱이 꺼져 있을 때 오는 알림을 받으려면 시작할 때 미리 걸어둬야 한다
      FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
    }
    if (!await Store.i.init()) return false;
    await AppState.i.loadProfile();
    return true;
  } catch (e) {
    // ignore: avoid_print
    print('앱 시작 실패: $e');
    return false;
  }
}


/* 체험 모임을 세운 뒤 홈→대화→일정→회비→게시판 순서로 스스로 넘어간다.

   ⚠️ 밖(워크플로)과 «시각을 맞추려 들지 않는다». 앱이 서는 데 걸리는 시간은 판마다 달라서,
      「25초에 홈, 35초에 대화」식으로 맞추면 몇 초만 어긋나도 **같은 화면이 두 장** 찍힌다
      (2026-08-25 실제로 그렇게 찍혔다). 그래서 밖에서는 2초마다 계속 찍고,
      **똑같은 그림끼리 묶어** 다섯 덩이를 골라낸다. 여기서는 «머무는 시간»만 넉넉히 준다. */
void _startShotTour() {
  Demo.start();
  var i = 0;
  /* ⚠️ 첫 화면(홈)에 «오래» 머문다. 앱이 서는 데 12초쯤 걸리는데 바로 넘겨 버리면
     밖에서 첫 장을 찍기도 전에 대화 탭으로 가 있어 **홈이 통째로 안 찍힌다**
     (2026-08-25 실제로 그랬다 — 채팅·일정·회비·게시판 넷만 나왔다). */
  Timer(const Duration(seconds: 40), () {
    AppState.i.openTab.value = ++i;
    Timer.periodic(const Duration(seconds: 12), (t) {
      if (i >= 4) {
        t.cancel();
        return;
      }
      AppState.i.openTab.value = ++i;
    });
  });
}

/* 🚪 앱의 문.

   ⚠️ 여기서 `await bootstrap()` 을 «먼저» 하면 안 된다 — 그게 끝나기 전에는 **아무것도 안 그린다.**
      2026-08-29 실측(인터넷을 끊고 켬): 첫 화면이 나오기까지 **2분 6초**가 걸렸고,
      15초 지킴이가 찍은 글도 118초 뒤에야 나왔다 — 파이어베이스 초기화가 본 실을 붙들어
      **타이머조차 못 돌았기** 때문이다(로그: Firebase Background Thread 가 잠금을 76초 붙듦).
      그동안 회원이 보는 것은 안드로이드 기본 스플래시뿐이라 「앱이 고장났다」로 읽힌다.

   그래서 **그리는 일을 먼저** 시작한다. 첫 프레임(로고와 「불러오는 중」)이 곧바로 나오고,
   준비는 그 뒤에 돈다. 준비가 끝나면 그 결과에 따라 화면을 바꾼다. */
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootApp());
}

/// 준비되는 동안 보여줄 화면 — 준비가 끝나면 스스로 다음 화면으로 넘어간다.
class BootApp extends StatefulWidget {
  const BootApp({super.key});
  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  bool? _ready; // null = 아직 준비 중

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    var ok = false;
    try {
      // 시각 지킴이는 `bootstrap` 안에 있다 — 여기서 또 재면 두 겹이라 어느 쪽이 잘랐는지 못 읽는다
      ok = await bootstrap();
    } catch (_) {
      ok = false;
    }
    if (ok && Cfg.shotMode) _startShotTour();
    if (!mounted) return;
    setState(() => _ready = ok);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ready;
    if (ready == null) return const _BootingApp();
    return ready ? const WooriApp() : const NeedNetworkApp();
  }
}

/// 「불러오는 중」 — 방을 아직 모르니 테마 색은 기본이지만 **밝기는 폰을 따라간다**
/// (어두운 방에서 켠 회원에게 흰 화면이 통째로 번쩍이지 않게).
class _BootingApp extends StatelessWidget {
  const _BootingApp();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Cfg.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(null),
      darkTheme: buildTheme(null, dark: true),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🏸', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 18),
              const SizedBox(
                  width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)),
              const SizedBox(height: 14),
              Builder(
                builder: (c) => Text('불러오는 중…',
                    style: TextStyle(color: Theme.of(c).hintColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 인터넷이 없어 서버에 붙지 못했을 때 — 흰 화면 대신 이 안내를 보여준다.
class NeedNetworkApp extends StatefulWidget {
  const NeedNetworkApp({super.key});
  @override
  State<NeedNetworkApp> createState() => _NeedNetworkAppState();
}

class _NeedNetworkAppState extends State<NeedNetworkApp> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Cfg.appName,
      debugShowCheckedModeBanner: false,
      /* ⚠️ `darkTheme` 을 빼면 MaterialApp 은 폰이 어두운 화면이어도 «밝은 테마»를 그대로 쓴다.
         이 화면은 앱을 켜자마자(모임 문서를 받기도 전에) 나오는 자리라,
         어두운 방에서 켠 회원에게 흰 화면이 통째로 번쩍인다.
         방을 아직 모르므로 테마 색은 기본(null)이지만 «밝기»는 폰을 따라가야 한다. */
      theme: buildTheme(null),
      darkTheme: buildTheme(null, dark: true),
      /* 💥 `Builder` 를 빼면 안 된다 — 안쪽 단추가 쓰는 `context` 가 **MaterialApp 보다 위**가 되어
         `ScaffoldMessenger.of(context)` 가 「없다」며 **그 자리에서 터진다.**
         그러면 「다시 시도」는 눌러도 아무 일도 안 일어나는 **죽은 단추**가 되고,
         인터넷이 잠깐 끊겨 이 화면에 온 회원은 앱을 껐다 켜는 수밖에 없다.
         (2026-08-29 확인 — 이미 나간 판에 그대로 들어 있었다.
          시험 950개가 다 통과하는데도 살아 있었다: 아무도 이 단추를 «눌러 보지» 않았다) */
      home: Builder(
        builder: (context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📶', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 16),
                const Text('모임 정보를 받지 못했어요',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  '인터넷이 느리거나 잠깐 끉겼을 수 있어요.\n'
                  '연결을 확인한 뒤 아래를 눌러주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.6, color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          // 기다린 뒤에는 context가 사라졌을 수 있으니 미리 잡아 둔다
                          final bar = ScaffoldMessenger.of(context);
                          setState(() => _busy = true);
                          // 터져도 «도는 중»을 반드시 푼다 —
                          // 안 그러면 「연결하는 중…」인 채로 굳어 다시 눌리지도 않는다
                          var ok = false;
                          try {
                            /* ⚠️ 「눌린 티」를 최소한 이만큼은 보여 준다.
                               2026-08-29 확인: 곧바로 실패하는 경우(서버가 바로 거절)에는
                               「연결하는 중…」이 **한 프레임도 안 보였다.** 회원 눈에는
                               «눌러도 아무 일이 없는» 단추라, 앱이 고장난 줄 알고 계속 누른다. */
                            final seen = Future<void>.delayed(
                                const Duration(milliseconds: 600));
                            // 회원이 스스로 기다리겠다고 누른 자리 — 넉넉히 준다
                            ok = await bootstrap(limit: _retryLimit);
                            await seen;
                          } catch (_) {
                            ok = false;
                          }
                          if (!mounted) return;
                          if (ok) {
                            runApp(const WooriApp());
                            return;
                          }
                          setState(() => _busy = false);
                          bar.showSnackBar(
                            const SnackBar(
                                content: Text('아직 연결이 안 돼요 — 신호가 좋은 곳에서 다시 눌러주세요')),
                          );
                        },
                  child: Text(_busy ? '연결하는 중…' : '다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class WooriApp extends StatefulWidget {
  const WooriApp({super.key});
  @override
  State<WooriApp> createState() => _WooriAppState();
}

/// 자리가 없어진 이유마다 회원에게 할 말.
String goneMessage(SeatGone why, Object? name) {
  final who = name is String && name.isNotEmpty ? '$name님, ' : '';
  return switch (why) {
    SeatGone.moved => '새 폰으로 옮겼어요 — 이 폰에서는 모임이 닫힙니다',
    SeatGone.rejected => '가입 신청이 받아들여지지 않았어요 — 다시 신청할 수 있어요',
    SeatGone.kicked => '$who모임 이용이 중지됐어요 — 다시 신청할 수 있어요',
  };
}

/// 설정·회원 같은 「위에 열린 화면」을 닫기 위한 열쇠.
/// 탈퇴 처리되면 뿌리 화면만 가입 화면으로 바뀌고, 위에 열린 화면은 그대로 남는다.
final navKey = GlobalKey<NavigatorState>();

class _WooriAppState extends State<WooriApp> {
  final st = AppState.i;

  /// 살아있는 값(입력중·읽음·접속·푸시토큰)만 바뀐 건지 견주기 위한 직전 문서.
  Map<String, dynamic>? _prevDoc;

  /// 직전에 「승인 대기」였는지 — 승인되는 순간을 알아채기 위해
  bool _wasPending = false;

  @override
  void initState() {
    super.initState();
    st.addListener(_onState);
    _armMidnight();
    if (st.code != null) _enter();
  }

  @override
  void dispose() {
    _midnight?.cancel();
    st.removeListener(_onState);
    super.dispose();
  }

  void _onState() => setState(() {});

  /// 모임에 들어가 구독을 건다 — 웹앱의 App.enter와 같은 자리.
  void _enter() {
    final code = st.code;
    if (code == null) return;
    Store.i.stopAll();
    /* 방을 옮기면 «그 방의 것»은 처음부터 다시 센다.
       · `_prevDoc` : 앞 방 문서와 견주면 「가벼운 갱신」으로 잘못 넘겨 화면이 안 바뀐다.
       · `_lastTouch`: 접속 표시는 5분에 한 번만 보내는데, 그 막이가 남아 있으면
         **새 방에는 「내가 있다」는 표시가 최대 5분 동안 안 적힌다** →
         그 사이 다른 회원이 글을 쳐도 「입력 중」이 나에게 안 나간다(볼 사람이 없다고 본다).
       · `_wasPending`: 앞 방에서 승인 대기였다는 표시가 남으면, 새 방 첫 스냅샷을
         「방금 승인됐다」로 잘못 보고 알림 준비를 한 번 더 한다. */
    _prevDoc = null;
    _lastTouch = 0;
    _wasPending = false;

    Store.i.subCouple(code, (c) {
      final before = _prevDoc;
      _prevDoc = c;
      /* 모임 문서가 사라졌다 = 총괄이 방을 지웠거나 코드가 잘못된 것.
         그냥 두면 회원은 «텅 빈 모임» 화면에 갇혀 왜 아무것도 없는지 알 수 없다. */
      if (c == null) {
        Store.i.stopAll();
        st.clearProfile();
        navKey.currentState?.popUntil((r) => r.isFirst);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('이 모임이 없어졌어요 — 방장에게 확인해주세요'),
          ));
        }
        return;
      }

      final isMember = (c['members'] as Map? ?? {}).containsKey(Store.i.myUid);
      final isPending = (c['pending'] as Map? ?? {}).containsKey(Store.i.myUid);

      /* 승인되는 순간 알림 준비를 «다시» 한다.
         알림 토큰은 그 방 회원만 적을 수 있는데, 처음 준비할 때는 아직 승인 전이라 서버가 거부한다.
         여기서 다시 하지 않으면 앱을 껐다 켤 때까지 **알림이 하나도 안 온다.** */
      if (isMember && _wasPending) {
        _wasPending = false;
        Push.i.setupIfAllowed();
      }
      _wasPending = isPending && !isMember;

      // 아직 승인 전 — 구독을 그대로 둔 채 대기 화면을 보여준다.
      // (여기서 프로필을 지우면 대기 화면이 안 뜨고 가입 화면으로 되돌아가, 승인돼도 못 들어온다)
      if (!isMember && isPending) {
        st.setCouple(c);
        return;
      }

      // 내 자리가 없어졌다 — 쓰던 중이어도 즉시 막고 되돌린다.
      // ⚠️ «왜» 없어졌는지는 셋으로 갈린다. 한 문장으로 뭉뚱그리면
      //    폰을 바꾼 사람은 잘린 줄 알고, 신청이 거절된 사람은 쓴 적도 없는 「이용 중지」를 듣는다.
      if (!isMember) {
        final wasName = st.profile?['name'];
        final why = AppState.whyGone(c, Store.i.myUid);
        Store.i.stopAll();
        st.clearProfile();
        // 설정·회원 화면을 열어둔 채 잘렸다면 그 화면들도 닫는다
        // (안 닫으면 이제 내 것이 아닌 모임의 설정 화면에 그대로 남는다)
        navKey.currentState?.popUntil((r) => r.isFirst);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(goneMessage(why, wasName))));
        }
        return;
      }

      // 입력중·읽음·접속시각·푸시토큰만 바뀌는 일이 대부분이다. 그때마다 홈·회비·일정까지
      // 다시 계산하면 회원 수에 비례해 무거워지므로, 그 값들만 바뀌었으면 채팅만 가볍게 갱신한다.
      if (_onlyLive(before, c)) {
        st.setCoupleLive(c);
        return;
      }
      st.setCouple(c);
    });

    Store.i.subItems(code, (arr) => st.setItems(arr));

    // 지난번에 못 지운 사진 원본을 마저 지운다 (삭제할 때만 정리하면 앱을 껐다 켠 사이 것이 영영 남는다)
    Future.delayed(const Duration(seconds: 4), () => Store.i.flushDeletes());
    Future.delayed(const Duration(seconds: 2), () => Push.i.setupIfAllowed());
    Push.i.bindTaps();   // 알림을 누르면 채팅으로 가도록
    _touch();
  }

  /* 「가벼운 갱신」으로 넘길 값들 — 채팅만 살짝 고치고 다른 화면은 그대로 둔다.
     ⚠️ push(알림 토큰·받는 범위)는 **넣으면 안 된다.**
     넣었더니 알림 범위를 바꿔도 설정 화면의 표시가 그대로였고, 홈의 「알림 켤까요」 카드도 안 사라졌다.
     push는 어차피 자주 바뀌지 않아(토큰 갱신·범위 변경뿐) 그냥 전체를 다시 그리는 편이 낫다. */
  static const _liveKeys = {'typing', 'lastRead', 'lastSeen'};

  bool _onlyLive(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null || b == null) return false;
    String strip(Map<String, dynamic> c) {
      final m = Map<String, dynamic>.from(c)..removeWhere((k, _) => _liveKeys.contains(k));
      final keys = m.keys.toList()..sort(); // 스냅샷마다 키 순서가 달라도 같게 보이도록
      return jsonEncode({for (final k in keys) k: m[k]});
    }

    return strip(a) == strip(b);
  }

  int _lastTouch = 0;

  /* 🌅 날이 바뀌면 화면을 깨운다.
     「다가오는 모임」·「지난 회차」·「이번 달 순위」·「밀린 달」은 모두 «오늘»을 기준으로 세는데,
     자정에는 서버에서 아무것도 안 온다 → **다시 그릴 까닭이 없어 어제 것이 그대로 남는다.**
     · 앱을 켜 둔 채 자정을 넘기면 → 아래 시계가 깨운다
     · 밤 11시 58분에 접었다가 12시 1분에 다시 열면 → 「접속 표시」는 5분에 한 번이라
       아무 쓰기도 안 나가서 화면이 어제 것 그대로였다 → 다시 열 때도 여기서 본다
     (137회차의 「입력 중」과 같은 병 — 시간으로 정해지는 것은 스스로 깨워야 한다) */
  String _day = ymd(DateTime.now());
  Timer? _midnight;

  void _armMidnight() {
    _midnight?.cancel();
    // 2초를 더 기다린다 — 딱 자정에 깨면 기기 시계 오차로 «아직 어제»일 수 있다
    _midnight = Timer(
        Duration(milliseconds: Logic.msUntilNextDay(DateTime.now()) + 2000), () {
      _rollDay();
      _armMidnight();
    });
  }

  void _rollDay() {
    final today = ymd(DateTime.now());
    if (_day == today) return;
    _day = today;
    // 모든 탭이 다시 그린다 — Logic 의 표들은 «날»이 열쇠라 저절로 다시 세어진다
    st.refresh();
  }

  /// 내가 앱을 보고 있다는 표시 — 5분에 한 번만 (자주 쓰면 회원 수만큼 읽기 요금이 곱해진다)
  void _touch() {
    _rollDay(); // 다시 열었을 때 날이 바뀌었을 수 있다 (아래 5분 막이보다 «먼저» 본다)
    final n = DateTime.now().millisecondsSinceEpoch;
    if (n - _lastTouch < 300000 || st.code == null) return;
    _lastTouch = n;
    // 내 자리만 보낸다 — 사본을 통째로 보내면 그 안의 낡은 남의 값이 최신 값을 덮어쓴다
    Store.i.setCouple(st.code!, {
      'lastSeen': {Store.i.myUid: n}
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final themeKey = st.couple?['theme'] as String?;
    Widget home;
    if (st.code == null) {
      home = OnboardingScreen(onJoined: _enter);
    } else if (st.couple == null) {
      /* 모임 문서가 «아직 안 왔다». 그대로 본 화면을 그리면 회원 0명·통장 0원인
         **텅 빈 모임**이 잠깐 보여서 「내 모임이 사라졌나」로 읽힌다.
         (정말 없어진 방이면 구독이 알려주고 프로필이 지워져 가입 화면으로 간다 — 여기 안 머문다) */
      home = _LoadingScreen(onRetry: _enter);
    } else if (!st.approved) {
      home = const WaitScreen();
    } else {
      home = ShellScreen(onTouch: _touch);
    }
    return MaterialApp(
      title: Cfg.appName,
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(themeKey),
      darkTheme: buildTheme(themeKey, dark: true),
      home: home,
    );
  }
}

/// 모임 문서를 기다리는 잠깐 — 텅 빈 모임을 보여주지 않기 위해.
///
/// ⚠️ **여기 갇히는 길이 있어서는 안 된다.** 구독이 오류로 끝나면(권한·색인·연결)
/// 알려주는 값이 영영 안 와서 이 화면이 그대로 남는다. 그래서 잠시 뒤에
/// 「오래 걸려요」와 다시 시도할 길을 함께 보여준다.
class _LoadingScreen extends StatefulWidget {
  final VoidCallback onRetry;
  const _LoadingScreen({required this.onRetry});
  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen> {
  static const _slow = Duration(seconds: 8);
  bool _late = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(_slow, () { if (mounted) setState(() => _late = true); });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('모임을 불러오는 중이에요…',
                  style: TextStyle(color: Theme.of(context).hintColor)),
              if (_late) ...[
                const SizedBox(height: 18),
                Text('생각보다 오래 걸려요 — 연결을 확인해주세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                const SizedBox(height: 10),
                FilledButton.tonal(
                  onPressed: () {
                    setState(() => _late = false);
                    _t?.cancel();
                    _t = Timer(_slow, () { if (mounted) setState(() => _late = true); });
                    widget.onRetry();
                  },
                  child: const Text('다시 시도'),
                ),
                TextButton(
                  onPressed: () async {
                    Store.i.stopAll();
                    await AppState.i.clearProfile();   // 가입 화면으로 — 여기 갇히지 않게
                  },
                  child: const Text('가입 화면으로 돌아가기'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
