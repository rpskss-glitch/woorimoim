# 우리 모임 (woorimoim)

동호회용 앱 — 채팅 · 일정(참석 투표 · 출석) · 회비 장부 · 게시판 · 사진첩.
하나의 소스로 **두 가지 앱**을 만든다.

| | 판매용 | 앞산 배드민턴 동호회용 |
|---|---|---|
| 앱 이름 | 우리 모임 | 앞산 배드민턴 |
| 꾸러미 이름 | `com.taejinsoft.woorimoim` | `com.taejinsoft.apsanclub` |
| 만들 때 | `--flavor woori` | `--flavor apsan` |

⚠️ **갈래(`--flavor`)를 반드시 적어야 한다.** 안 적으면 Flutter 가 `app-release.apk` 를
찾는데 갈래가 있으면 그 이름이 안 생겨 「.apk 를 못 찾겠다」며 멈춘다.

```
flutter build apk --release --flavor woori
```

## 문서

| 파일 | 내용 |
|---|---|
| [사용안내-앱만들기.md](사용안내-앱만들기.md) | 안드로이드·아이폰 앱 만드는 법, 서명 열쇠, 남은 일 |
| [앱나누기-안내.md](앱나누기-안내.md) | 하나의 소스로 두 앱을 만드는 구조 |

## 함께 쓰는 것들

- Firebase 프로젝트 `wedding-246e7` 를 **세 앱**(이 앱 · 웹앱 · 커플 앱)이 나눠 쓴다.
  경로 구분자는 `Cfg.appId = 'apsan-badminton-v1'` — **바꾸면 기존 모임 자료가 안 보인다.**
- 보안 규칙은 `Desktop/데이트장부/firestore.rules` 한 곳에 있다(세 앱 공용).
- 알림 서버 함수는 `Desktop/앞산배드민턴/functions/index.js` 의 `pushOnMsgApsan`.
  고칠 때는 **반드시 함수 이름까지** 붙여 올린다: `firebase deploy --only functions:pushOnMsgApsan`

## 점검

```
flutter analyze
flutter test
```

`test/` 에는 계산 시험뿐 아니라 **설정이 서로 어긋나지 않는지 보는 검사기**들이 들어 있다
(빌드 명령의 갈래 · 서명 열쇠 · 아이폰 값 · 서버 규칙과 직책 목록 · 어두운 모드 대비 등).
