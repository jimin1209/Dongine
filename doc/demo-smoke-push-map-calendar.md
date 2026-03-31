# 데모 직전 Smoke — 푸시 / 지도 / Google Calendar

> **목적**: 커튼 직전 **약 1–2분**에 푸시·지도·(선택) Google Calendar만 확인한다.  
> **문서 흐름**: [README — 시제품 데모 준비](../README.md#시제품-데모-준비--문서-진입-경로) → **본 문서** → (시드 후) [demo-walkthrough.md](./demo-walkthrough.md).

**역할 정리(한 줄)**  
- **[실기기 매트릭스](./real-device-validation-matrix.md)**: 출시·데모 전 **전 기능** 손 점검 표(P/F).  
- **본 smoke**: 당일 **푸시·지도·(선택) Google**만 재확인.  
- **[워크스루](./demo-walkthrough.md)**: 청중 앞 **3–5분 대본**.

**당일 전제**: 안정 네트워크 · 계정 2개 **같은 가족** · 푸시 확인 전 B를 홈/다른 화면으로 보낼 것 · (선택) 이전 시연 잔여 시 Debug **홈 → 설정** (`/settings`) → **`[DEMO]` 데모 데이터 초기화** 후 재시드.

앱 **내장 일정·시드**만 쓰면 아래 **Google Calendar**는 생략한다.

---

## 30초 체크리스트

- [ ] **푸시**: A 채팅 1건 → B에서 알림/스낵바 → 탭 시 [아래 표](#smoke-push)대로 이동하는지(최소 **채팅 `/chat`**)
- [ ] **지도**: 하단 **지도** (`/map`) → 권한 배너 → **위치 공유 ON** → **내 마커** (2대면 상대 ON 후 가족 마커)
- [ ] **Google**(대본에 넣을 때만): **캘린더** (`/calendar`) 앱바 톱니 → **Google Calendar 연결·동기화** → 월간 뷰

---

<a id="smoke-push"></a>

## 1. 푸시

### 알림 탭 → 기대 화면(`data.route`)

| 알림 | `data.route` | 기대 화면 | 앱바(참고) |
|------|--------------|-----------|------------|
| 채팅 | `/chat` | **채팅** 탭 | 현재 가족 이름 |
| 캘린더(앱 내 일정 생성) | `/calendar` | **캘린더** 탭 | 「캘린더」 |
| 할 일(새 항목) | `/todo` | 할 일 화면 | 「할 일」 |
| 장보기 | `/cart` | 장보기 화면 | 「장보기 목록」 |
| 가계부 | `/expense` | 가계부 화면 | 「가계부」 |

**최소 smoke 절차**

1. A·B 같은 가족. B는 홈/다른 탭.
2. A에서 **채팅 한 줄** 전송 → B 알림 탭 → **`/chat`**·채팅 탭인지 확인.
3. (시간 있으면) A에서 **할 일·일정·장보기·가계부** 중 하나만 추가해 B에서 탭 → 위 표와 같은 화면인지 확인.

**우회 시연**: 푸시가 안 오면 채팅을 **양쪽에 띄운 채** 실시간만 보여 주고 FCM은 구두. 기기 1대도 동일.

<a id="push-route-debug"></a>

### `route` 불일치·딥링크가 안 열릴 때 (한곳)

| 확인 | 링크·위치 |
|------|-----------|
| 서버가 넣는 `route`·`type` | [functions/notification_payloads.js](../functions/notification_payloads.js) (`VALID_ROUTES`, `buildChatNotification` 등) |
| 앱이 허용하는 경로·정규화 | `lib/core/services/notification_service.dart` — `kDeeplinkAllowedRoutes`, `extractRoute` (허용 목록 밖이면 로그에 `알림 딥링크 무시`) |
| 트리거·배포 오류 | Firebase Console → **Functions** → **로그** |
| FCM·APNs·토큰·배포 게이트 | [release-checklist.md §2](./release-checklist.md#2-fcm-푸시-알림) |
| Functions만 배포·로컬 검증 | [deploy-functions.md](./deploy-functions.md) |
| 도메인별 손 표(푸시·탭) | [real-device-validation-matrix.md §9](./real-device-validation-matrix.md#section-9-push) |

**짧은 복구(수신은 되는데 화면이 다를 때)**: 위 표의 **서버·앱** 두 파일에서 `route` 문자열이 동일한지 확인 → Functions 로그에 실패 없는지 → 앱 **디버그 로그**에서 딥링크 무시/실패 문구 확인.

**짧은 복구(알림 자체가 안 올 때)**: Functions 로그 → Firestore `users/{uid}.fcmTokens` → 기기 알림 권한 → 앱 재시작(토큰 갱신). 상세는 [release-checklist.md §2](./release-checklist.md#2-fcm-푸시-알림).

---

<a id="smoke-map"></a>

## 2. 지도

1. 하단 **지도** (`/map`, 앱바 「가족 위치」).
2. 권한 배너 → 필요 시 설정으로 연결.
3. **위치 공유** ON → **내 마커** · 2대면 상대 ON → **가족 마커**.

**우회**: 마커 없으면 **탭·배너·토글**만 시연하고 다음 단계로.

**복구**: [manual-build-inputs.md](./manual-build-inputs.md) 네이버맵 Client ID · GPS · 위치 권한.

---

<a id="smoke-google"></a>

## 3. Google Calendar (선택)

**캘린더** (`/calendar`) 앱바 **톱니** → **Google Calendar 연결** → 동기화 → 월간 뷰. (선택) 일정에서 **Google로 보내기**.

**우회**: 앱 일정·`[DEMO]` 시드·플래너만 시연. OAuth는 [manual-build-inputs §2-7](./manual-build-inputs.md#google-calendar-oauth) — Android **SHA-1**·iOS 번들 **`com.dongine.dongine`**·Calendar API·테스트 사용자.

---

<a id="smoke-fallback"></a>

## 우회 한눈에

| 실패 | 시연에서 이렇게 넘김 |
|------|---------------------|
| 푸시 | 채팅 양쪽 화면 실시간 + 구두 |
| 지도 | UI만 또는 다음 탭 |
| Google | 앱 캘린더·시드만 |

**전 기능 QA**는 [real-device-validation-matrix.md](./real-device-validation-matrix.md), **빌드·배포 게이트**는 [release-checklist.md](./release-checklist.md).
