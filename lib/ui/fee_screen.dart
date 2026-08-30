import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../billing.dart';
import '../store.dart';
import '../fee.dart';
import '../state.dart';
import 'common.dart';

/* 💳 모임 이용권 화면 — 사고·되살리고·해지하는 길이 한자리에.

   스토어 심사가 여기서 보는 것(없으면 3.1.2 로 반려된다 — 장부의신이 실제로 당했다):
     · 상품 이름 · 기간 · **스토어가 준 가격 그대로**
     · 자동으로 갱신된다는 말과 **해지하는 방법**
     · **구매 복원** 단추 (3.1.1)
     · 이용약관(EULA)·개인정보 처리방침 링크
   그리고 회원(=낼 사람이 아닌 사람)에게는 결제 단추를 보이지 않는다. */
class FeeScreen extends StatefulWidget {
  const FeeScreen({super.key});

  static const eulaUrl = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const privacyUrl = 'https://apsan-badminton.netlify.app/privacy.html';

  @override
  State<FeeScreen> createState() => _FeeScreenState();
}

class _FeeScreenState extends State<FeeScreen> {
  @override
  void initState() {
    super.initState();
    Billing.i.start();
    Billing.i.lastMessage.addListener(_onMsg);
    AppState.i.addListener(_onData);
  }

  @override
  void dispose() {
    Billing.i.lastMessage.removeListener(_onMsg);
    AppState.i.removeListener(_onData);
    super.dispose();
  }

  void _onData() {
    if (mounted) setState(() {});
  }

  void _onMsg() {
    final m = Billing.i.lastMessage.value;
    if (m == null || !mounted) return;
    toast(context, m);
    Billing.i.lastMessage.value = null;
  }

  /* 🔗 약관·개인정보 링크를 연다.
     ⚠️ `launchUrl` 은 **던진다** — 브라우저가 없는 기기, 막아 둔 회사 폰 등.
        받아 내지 않으면 애플 심사원이 반드시 눌러 보는 그 자리에서
        아무 말 없이 아무 일도 안 나는 단추가 된다(3.1.2 로 되돌려보낸다). */
  Future<void> _open(String url) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) toast(context, '주소를 열지 못했어요 — 인터넷 연결을 확인해주세요');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final until = Fee.until();
    final ok = Fee.ok();
    final title = (AppState.i.couple?['title'] as String?) ?? '우리 모임';

    return Scaffold(
      appBar: AppBar(title: const Text('모임 이용권')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(ok ? Icons.verified : Icons.lock_outline,
                        color: ok ? cs.primary : Theme.of(context).hintColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        Fee.exempt
                            ? '무료로 쓰는 모임이에요'
                            : ok
                                ? '이용권이 켜져 있어요'
                                : '이용권이 꺼져 있어요',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  Fee.exempt
                      ? '「$title」은 이용료를 받지 않는 모임으로 정해져 있어요.'
                      : until == null
                          ? '「$title」의 이용권을 켜면 회원 모두가 그대로 쓸 수 있어요.'
                          : '${fmtDateFull(ymd(until))}까지 쓸 수 있어요.',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor, height: 1.5),
                ),
              ],
            ),
          ),
          if (!Fee.exempt) ...[
            const SizedBox(height: 12),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('모임 이용권 (한 달)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(Billing.i.priceText,
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900, color: cs.primary)),
                  const SizedBox(height: 10),
                  Text(
                    '· 모임을 만든 방장만 냅니다 — 회원은 한 푼도 내지 않아요.\n'
                    '· 한 달마다 자동으로 갱신돼요. 끝나기 24시간 전에 갱신됩니다.\n'
                    '· 언제든 끊을 수 있고, 끊어도 남은 기간은 그대로 쓸 수 있어요.\n'
                    '· 대화·사진·회비 기록은 이용권이 꺼져도 그대로 볼 수 있어요 (새로 쓰는 것만 멈춥니다).',
                    style: TextStyle(
                        fontSize: 13, height: 1.7, color: Theme.of(context).hintColor),
                  ),
                  const SizedBox(height: 14),
                  if (Fee.iPay)
                    ValueListenableBuilder<bool>(
                      valueListenable: Billing.i.busy,
                      builder: (c, busy, _) => FilledButton(
                        onPressed: busy ? null : () => Billing.i.buy(),
                        child: Text(busy ? '잠시만요…' : '이용권 결제하기'),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('이용권은 **방장**이 결제해요 — 회원은 따로 낼 것이 없어요.'
                          .replaceAll('**', ''),
                          style: const TextStyle(fontSize: 13)),
                    ),
                  const SizedBox(height: 8),
                  /* 🔄 구매 복원 — 자동갱신 구독이면 반드시 있어야 한다(3.1.1).
                     ⚠️ **결제가 도는 중에는 잠근다.** 눌러도 거절할 단추를 살려 두면
                        회원은 「눌렀는데 아무 일도 안 나네」로 읽는다. */
                  ValueListenableBuilder<bool>(
                    valueListenable: Billing.i.busy,
                    builder: (c, busy, _) => OutlinedButton(
                      onPressed: busy ? null : () => Billing.i.restore(),
                      child: const Text('🔄 구매 복원'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('해지하는 방법',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    '· 아이폰: 설정 → 내 이름 → 구독 → 「우리 모임」 → 구독 취소\n'
                    '· 안드로이드: Play 스토어 → 프로필 → 결제 및 정기 결제 → 정기 결제\n'
                    '앱에서 지우거나 모임을 나가는 것만으로는 해지되지 않아요.',
                    style: TextStyle(
                        fontSize: 13, height: 1.7, color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                    onPressed: () => _open(FeeScreen.eulaUrl), child: const Text('이용약관(EULA)')),
                const Text('·'),
                TextButton(
                    onPressed: () => _open(FeeScreen.privacyUrl),
                    child: const Text('개인정보 처리방침')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
