import 'package:flutter/material.dart';

import '../config.dart';
import '../state.dart';
import 'common.dart';

/* 📗 **회원 사용설명서** — 설정 안에 접힌 채로 늘 있다.

   왜 필요한가
     동호회 회원 대다수는 앱을 처음 쓴다. 「참석을 어디서 찍느냐」,
     「내 회비가 얼마나 밀렸는지 어디서 보느냐」를 방장에게 하나하나 묻고,
     방장은 같은 말을 서른 번 한다. 그 말을 앱 안에 적어 둔다.

   ⚠️ **접힌 채로 시작한다.** 설정 화면은 늘 보는 자리라, 펼친 채로 두면
      정작 찾으러 온 항목(알림·탈퇴)이 저 아래로 밀린다.
   ⚠️ 접힘 여부는 «이 기기»에만 남긴다 — 서버에 적으면 회원 목록을 건드리게 되고,
      권한 없는 회원은 아예 못 접는다.
   ⚠️ 방장 안내서(OwnerGuideCard)와 **다른 글**이다. 이쪽은 «할 수 있는 일»만 적는다 —
      회원에게 승인·직책·결제를 설명해 봐야 눌러도 안 되는 곳뿐이다. */
class MemberGuideCard extends StatefulWidget {
  const MemberGuideCard({super.key});

  @override
  State<MemberGuideCard> createState() => _MemberGuideCardState();
}

class _MemberGuideCardState extends State<MemberGuideCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final st = AppState.i;
    final feeAmount = ((st.couple?['fee'] as Map?)?['amount'] as num?)?.toInt() ?? 0;

    Widget item(String head, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(head,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              const SizedBox(height: 3),
              Text(body, style: TextStyle(height: 1.6, color: hint)),
            ],
          ),
        );

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /* 제목 줄 전체가 누르는 자리다 — 화살표만 누르게 하면
             손가락이 굵은 어르신은 몇 번을 헛짚는다. */
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('📗 앱 사용설명서',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more, color: hint),
                ],
              ),
            ),
          ),
          if (!_open)
            Text('참석 찍기·회비 확인·사진·투표 — 눌러서 펼쳐 보세요',
                style: TextStyle(fontSize: 12, color: hint))
          else ...[
            const SizedBox(height: 10),
            item('📅 일정 — 참석을 찍어요',
                '일정 탭에서 모임을 눌러 참석 · 미정 · 불참 중 하나를 고릅니다.\n'
                '· 마음이 바뀌면 언제든 다시 누르면 됩니다.\n'
                '· 모임이 끝나면 운영진이 출석을 확인합니다.'),
            item('💵 회비 — 내 것만 봐요',
                feeAmount > 0
                    /* ⚠️ 회원 화면 글과 같은 말로 — 회원은 표(📋)를 못 연다(회장·총무만), 그래서 표 설명은 뺀다(2026-09-26) */
                    ? '회비 탭 「내 회비」에 「밀린 회비가 없어요」 또는 「몇 달 밀렸어요」가 보입니다.\n'
                        '· 지금 회비는 1인 ${fmtWon(feeAmount)}입니다.\n'
                        '· 회비를 받았다고 적는 것은 회장·총무만 합니다. 낸 뒤에도 그대로면 총무에게 말씀하세요.\n'
                        '· 총무가 계좌를 적어 두었으면 「내 회비」 아래 계좌를 눌러 복사할 수 있어요.'
                    : '이 모임은 아직 회비가 정해져 있지 않습니다.'),
            item('💬 대화 — 글·사진·투표',
                '대화 탭에서 이야기를 나눕니다.\n'
                // ⚠️ 단추 자리를 실제대로 — 입력칸 «왼쪽»에 사진·투표 단추가 있다(2026-09-25 에뮬 확인)
                '· 입력칸 왼쪽의 🖼 단추로 사진을 올립니다(한 번에 5장까지).\n'
                '· 그 옆 📊 단추로 투표를 만듭니다(기간이 지나면 저절로 끝납니다).\n'
                '· 글을 꾹 누르면 지우거나 신고할 수 있습니다.\n'
                '· 「🔒 운영진」 방이 보이면 운영진만 쓰는 방입니다.'),
            item('🖼 사진첩',
                // ⚠️ 사진첩은 게시판 「사진」에 올린 것만 모인다 — 대화방 사진은 대화방에 남는다
                '게시판 탭의 「사진」에 올린 사진이 모입니다. 사진을 누르면 크게 보고, 옆으로 밀어 다음 사진을 봅니다.\n'
                '· 대화방에 보낸 사진은 대화방에서 눌러 넘겨 볼 수 있어요.'),
            item('🔔 알림',
                '설정에서 알림을 켜고 끕니다.\n'
                // ⚠️ 폰 설정 목록에는 «앱 이름»으로 나온다 — 모임 이름으로는 못 찾는다(2026-09-25 조사)
                '· 알림이 안 오면 폰 설정에서 「${Cfg.appName}」 알림이 꺼져 있는지 보세요.'),
            item('🙋 내 정보',
                '설정에서 이름 · 사진 · 생년월일을 바꿉니다.\n'
                '· 직책은 방장이 정합니다.\n'
                '· 모임을 그만두려면 설정의 「모임 탈퇴 · 내 자료 지우기」를 누릅니다.'),
            // ⚠️ 실제 권한대로: 직책은 방장만(members.dart), 회비 기록은 회장·총무(isTreasurer)
            Text('＊ 회원 승인은 방장·운영진이, 직책은 방장이, 회비 기록은 회장·총무가 합니다.',
                style: TextStyle(fontSize: 12, color: hint)),
          ],
        ],
      ),
    );
  }
}
