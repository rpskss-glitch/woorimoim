import 'package:flutter/material.dart';

import '../fee.dart';
import '../state.dart';
import '../store.dart';
import 'common.dart';

/* 📖 **방장 안내서** — 모임을 새로 만든 방장에게만, 홈 맨 위에 한 번 뜬다.

   왜 필요한가
     방장이 되면 갑자기 할 일이 여럿 생긴다 — 회원 부르기, 승인, 직책 정하기,
     회비 정하기, 이용권 결제. 그런데 그 길이 화면 여기저기에 흩어져 있어
     «어디부터 손대야 하는지» 알 수가 없었다. 첫 모임을 만들어 놓고
     회원을 못 부른 채 며칠을 흘려보내는 일이 그래서 생긴다.

   ⚠️ **방장에게만** 보인다 — 평회원에게는 할 수도 없는 일 목록이라 성가심일 뿐이다.
   ⚠️ **닫을 수 있어야 한다.** 닫으면 이 기기에서 다시 안 뜬다(설정에서 다시 볼 수 있다).
      닫지 못하는 안내는 며칠만 지나면 «치울 수 없는 광고»가 된다.
   ⚠️ 닫았다는 표시는 «이 기기»에만 남긴다 — 서버에 적으면 폰을 바꿀 때마다 다시 뜬다.
      (그 대신 새 폰에서 한 번 더 보게 되는데, 그편이 덜 나쁘다) */
class OwnerGuideCard extends StatefulWidget {
  /// 닫았을 때 홈이 다시 그리도록
  final VoidCallback onClosed;

  /// 탭 옮기기 (0홈 1채팅 2일정 3회비 4게시판)
  final ValueChanged<int> onGo;

  const OwnerGuideCard({super.key, required this.onClosed, required this.onGo});

  /* 접어 두었는가 (이 기기에만 남는 값).
     ⚠️ 예전에는 «닫기»였다 — 한 번 닫으면 카드가 통째로 사라져,
        설정에 「다시 보기」가 있는 줄 모르는 방장은 영영 못 봤다.
        이제는 **접기**다. 제목 줄은 늘 남아 있어 언제든 다시 편다. */
  static const _key = 'club_owner_guide_done';

  static bool get folded => Store.i.getInt(_key) == 1;
  static void fold() => Store.i.setInt(_key, 1);
  static void unfold() => Store.i.setInt(_key, 0);

  /// 다시 보기 (설정에서 부른다) — 펼친 채로 되돌린다
  static void reset() => unfold();

  /// 방장이면 «접혔든 펴졌든» 자리는 있다
  static bool shouldShow() => AppState.i.isOwner;

  @override
  State<OwnerGuideCard> createState() => _OwnerGuideCardState();
}

class _OwnerGuideCardState extends State<OwnerGuideCard> {
  late bool _folded = OwnerGuideCard.folded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final st = AppState.i;
    final title = (st.couple?['title'] as String?) ?? '모임';
    final code = st.code ?? '';
    final feeAmount = ((st.couple?['fee'] as Map?)?['amount'] as num?)?.toInt() ?? 0;
    final members = st.memberList.length;

    Widget step(String num, String head, String body, {Widget? action}) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                child: Text(num,
                    style: TextStyle(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(head,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(body,
                        style: TextStyle(
                            height: 1.6, color: Theme.of(context).hintColor)),
                    if (action != null) ...[const SizedBox(height: 6), action],
                  ],
                ),
              ),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('👑 방장이 되셨어요 — 이대로만 하시면 돼요',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                IconButton(
                /* 접기·펴기 — 물어보지 않는다. 되돌리기가 한 번 누르기라
                   확인 창은 성가시기만 하다(지우는 일이 아니다). */
                tooltip: _folded ? '펼치기' : '접기',
                onPressed: () {
                  setState(() => _folded = !_folded);
                  if (_folded) {
                    OwnerGuideCard.fold();
                  } else {
                    OwnerGuideCard.unfold();
                  }
                  widget.onClosed();
                },
                icon: Icon(_folded ? Icons.expand_more : Icons.expand_less),
                ),
              ],
            ),
            /* 📕 접으면 «제목 줄만» 남는다 — 카드가 통째로 사라지지 않으니
               방장은 언제든 다시 펼 수 있다(설정까지 찾아가지 않아도 된다). */
            if (_folded)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('눌러서 펼치면 할 일이 차례대로 나와요',
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).hintColor)),
              )
            else ...[
              const SizedBox(height: 4),
              Text('「$title」을 만드셨습니다. 아래 차례대로 하시면 모임이 바로 굴러갑니다.',
                  style: TextStyle(height: 1.6, color: Theme.of(context).hintColor)),
              const SizedBox(height: 16),

              step('1', '회원을 부르세요',
                  '회원에게 모임 이름 「$title」만 알려주시면 됩니다. '
                  '회원이 그 이름으로 가입 신청을 하면 방장님께 승인 요청이 옵니다.\n'
                  '· 대소문자·띄어쓰기가 달라도 찾아옵니다.\n'
                  '· 초대 코드($code)는 «방장을 넘길 때»만 쓰세요 — '
                  '이 코드로 처음 들어온 사람이 방장이 됩니다.'),

              step('2', '가입 신청을 승인하세요',
                  members <= 1
                      ? '아직 회원이 방장님 한 분입니다. 신청이 오면 홈 맨 위에 뜹니다.'
                      : '지금 회원 $members명입니다. 신청은 홈 맨 위 「가입 승인 대기」에서 처리합니다.',
                  action: OutlinedButton(
                    onPressed: () => widget.onGo(0),
                    child: const Text('홈에서 확인'),
                  )),

              step('3', '직책을 정하세요',
                  '회원 관리(👥)에서 회원을 눌러 「직책 정하기」를 고릅니다.\n'
                  '· 회장·총무는 고르는 순간 운영진 권한도 함께 붙습니다 '
                  '(회원 승인·일정 관리·회비 기록).\n'
                  '· 그 밖의 직책은 권한을 줄지 물어봅니다.\n'
                  '· 목록에 없으면 「직접 입력」으로 적으세요.\n'
                  '· 방장님이 모임을 떠나면 회장→총무→부회장→가입 순으로 '
                  '방장이 자동으로 넘어갑니다.'),

              step('4', '회비를 정하세요',
                  feeAmount > 0
                      ? '지금 1인 ${fmtWon(feeAmount)}으로 정해져 있습니다. '
                          '총무가 회비 탭에서 받은 것을 기록합니다.'
                      : '아직 회비가 정해지지 않았습니다. 회비를 안 걷는 모임이면 그대로 두셔도 됩니다.',
                  action: OutlinedButton(
                    onPressed: () => widget.onGo(3),
                    child: const Text('회비 탭 열기'),
                  )),

              step('5', '모임 일정을 올리세요',
                  '일정(📅) 탭에서 「모임 만들기」를 누릅니다.\n'
                  '· 매주·격주처럼 「반복」으로 만들면 한 번만 적어도 계속 잡힙니다.\n'
                  '· 회원은 참석·미정·불참을 찍고, 끝난 뒤 출석 체크를 합니다.',
                  action: OutlinedButton(
                    onPressed: () => widget.onGo(2),
                    child: const Text('일정 탭 열기'),
                  )),

              if (!Fee.exempt)
                step('6', '모임 이용권을 결제하세요',
                    '이용권은 방장님만 내십니다 (회원은 한 푼도 내지 않습니다). '
                    '월 ${Fee.wonText}이고 언제든 끊을 수 있습니다.\n'
                    '· 결제 전에도 먼저 만들어 보실 수 있습니다.\n'
                    '· 끊어도 그동안의 대화·사진·회비 기록은 그대로 볼 수 있습니다.'),

              const SizedBox(height: 4),
              Text(
                '＊ 이 안내서는 방장님에게만 보입니다. 회원 화면에는 나오지 않아요.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
