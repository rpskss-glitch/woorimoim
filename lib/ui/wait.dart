import 'package:flutter/material.dart';

import '../state.dart';
import '../store.dart';
import 'common.dart';

/// ⏳ 승인 대기 — 모임 문서를 지켜보다가 members에 내가 생기면 자동으로 들어간다.
/// 승인되면 이미 걸려 있는 모임 구독이 알아서 알려주므로,
/// 이 화면은 따로 무언가를 기다리지 않고 안내만 한다.
class WaitScreen extends StatelessWidget {
  const WaitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppState.i;
    final title = (st.couple?['title'] as String?) ?? '모임';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⏳', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: title,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const TextSpan(text: '에 가입 신청을 보냈어요.\n방장·운영진의 승인을 기다리고 있어요'),
                  ]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 14),
                Text(
                  '승인되면 이 화면이 저절로 바뀌어요.\n앱을 닫았다 다시 열어도 괜찮아요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
                const SizedBox(height: 26),
                TextButton(
                  onPressed: () async {
                    final ok = await confirmSheet(
                      context,
                      '가입 신청을 취소할까요?',
                      '취소해도 나중에 다시 신청할 수 있어요',
                      okLabel: '신청 취소',
                    );
                    if (!ok) return;
                    final code = st.code;
                    if (code != null) {
                      /* ⚠️ 실패를 삼키면 안 된다. 서버에는 신청이 «그대로 남아 있는데»
                         화면만 가입 화면으로 돌아간다 → 방장에게는 취소한 사람의 신청이 계속 보이고,
                         회원은 취소된 줄 안다. 안 됐으면 안 됐다고 말하고 이 화면에 머문다. */
                      try {
                        await Store.i.patchCouple(code, {'pending.${Store.i.myUid}': null});
                      } catch (_) {
                        if (!context.mounted) return;
                        return toast(context, '신청을 취소하지 못했어요 — 잠시 후 다시 눌러주세요');
                      }
                    }
                    Store.i.stopAll();
                    await st.clearProfile();
                  },
                  child: const Text('가입 신청 취소하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
