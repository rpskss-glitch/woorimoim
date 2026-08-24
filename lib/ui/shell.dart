import 'package:flutter/material.dart';

import '../config.dart';
import '../demo.dart';
import '../fee.dart';
import '../logic.dart';
import '../state.dart';
import '../store.dart';
import 'board.dart';
import 'calendar.dart';
import 'chat.dart';
import 'common.dart';
import 'fee_screen.dart';
import 'home.dart';
import 'members.dart';
import 'settings.dart';
import 'wallet.dart';

/// 앱 본체 — 아래 탭 5개.
/// 탭바는 반드시 불투명이라야 한다 (반투명이면 뒤 카드가 비쳐 글씨가 안 읽힌다).
class ShellScreen extends StatefulWidget {
  final VoidCallback onTouch;
  const ShellScreen({super.key, required this.onTouch});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppState.i.currentTab = _tab;
    AppState.i.openTab.addListener(_onOpenTab);
    // 알림을 눌러 앱이 켜진 경우엔 이미 값이 들어와 있을 수 있다
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpenTab());
  }

  @override
  void dispose() {
    AppState.i.openTab.removeListener(_onOpenTab);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onOpenTab() {
    final t = AppState.i.openTab.value;
    if (t == null || !mounted) return;
    AppState.i.openTab.value = null;   // 한 번만 옮기고 신호를 비운다
    setState(() => _tab = t);
    AppState.i.currentTab = t;
    widget.onTouch();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.onTouch();
    // 화면을 벗어날 때 못 지운 사진 원본을 마저 정리한다
    if (state == AppLifecycleState.paused) Store.i.flushDeletes();
  }

  @override
  Widget build(BuildContext context) {
    final st = AppState.i;
    final title = (st.couple?['title'] as String?) ?? Cfg.appName;
    final pendingN = st.isAdmin ? st.pending.length : 0;

    final pages = [
      const HomeTab(),
      ChatTab(active: _tab == 1),
      const CalendarTab(),
      const WalletTab(),
      const BoardTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        title: Row(
          children: [
            const Emblem(basePx: 24, capScale: 1.25),
            const SizedBox(width: 8),
            Flexible(
              child: Text(title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '회원',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const MembersScreen())),
            icon: Badge(
              isLabelVisible: pendingN > 0,
              label: Text('$pendingN'),
              child: const Icon(Icons.group_outlined),
            ),
          ),
          IconButton(
            tooltip: '설정',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔍 체험 중이라는 표시 — 어느 탭에서나 같은 자리에 (샘플을 실제 모임으로 오해하지 않게)
          if (Demo.on) const _DemoBar(),
          // 💳 이용권이 꺼졌을 때 — 읽기는 그대로, 새로 쓰는 것만 멈춘다
          if (!Demo.on && Fee.locked) const _LockBar(),
          Expanded(child: IndexedStack(index: _tab, children: pages)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          AppState.i.currentTab = i;   // 채팅을 보는 중에는 알림을 안 띄우기 위해
          widget.onTouch();
        },
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unreadChat > 0 && _tab != 1,
              label: Text('$_unreadChat'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: '채팅',
          ),
          const NavigationDestination(
              icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: '일정'),
          const NavigationDestination(
              icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: '회비'),
          const NavigationDestination(
              icon: Icon(Icons.article_outlined), selectedIcon: Icon(Icons.article), label: '게시판'),
        ],
      ),
    );
  }

  int get _unreadChat {
    final st = AppState.i;
    final seen = st.lastSeenChat;
    return st
        .by('msg')
        /* 폰을 바꾸기 «전»에 내가 쓴 말은 «남의 말»이 아니다 —
           안 이으면 새 폰에서 **내가 쓴 말까지 안읽음으로 세어진다**
           (2026-08-23 실측: 남이 쓴 말 3개인데 배지가 8). */
        .where((m) =>
            !Logic.isMe(m['by'] as String?, Store.i.myUid) &&
            ((m['createdAt'] as num?) ?? 0) > seen)
        .length;
  }
}

/* 🔍 체험 모드 띠 — 화면 맨 위, 어느 탭에서나 같은 자리.
   ⚠️ 「나가기」가 없으면 둘러보러 들어온 사람이 **가입 화면으로 돌아갈 길을 잃는다**
      (앱을 지웠다 깔아야 한다). */
class _DemoBar extends StatelessWidget {
  const _DemoBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '🔍 체험 모드 — 샘플 자료예요. 실제 모임에는 아무 영향이 없어요',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: cs.onPrimary),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: cs.onPrimary,
                  backgroundColor: cs.onPrimary.withValues(alpha: 0.22),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  final ok = await confirmSheet(
                    context,
                    '체험을 끝낼까요?',
                    '둘러보며 남긴 것은 모두 사라지고 가입 화면으로 돌아가요.',
                    okLabel: '나가기',
                  );
                  if (!ok) return;
                  Store.i.stopAll();
                  Demo.stop();
                },
                child: const Text('나가기',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/* 💳 이용권이 꺼졌다는 띠.
   ⚠️ 회원에게 「결제하세요」라고 하면 안 된다 — 낼 사람은 방장이고 회원은 낼 수도 없다. */
class _LockBar extends StatelessWidget {
  const _LockBar();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.errorContainer,
      child: InkWell(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const FeeScreen())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: cs.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  Fee.lockedLine,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: cs.onErrorContainer),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: cs.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}
