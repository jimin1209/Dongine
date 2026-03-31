# 데모 직전 Smoke — 푸시 / 지도 / Google Calendar

> **목적**: 커튼 직전 **약 1–2분**에 푸시·지도·(선택) Google Calendar만 확인한다.  
> **문서 흐름**: [README — 시제품 데모 준비](../README.md#시제품-데모-준비--문서-진입-경로) → **본 문서** → (시드 후) [demo-walkthrough.md](./demo-walkthrough.md).

**본 문서(smoke) vs 3–5분 워크스루**: smoke는 **환경이 살아 있는지**만 짧게 검증한다. 로그인·가족·시드·채팅·할 일·장보기·가계부·캘린더를 순서대로 보여 주는 **스토리 시연**은 [demo-walkthrough.md](./demo-walkthrough.md)에만 있다.

**당일 전제**: 안정 네트워크 · 계정 2개 **같은 가족** · 푸시 smoke 전 B를 홈/다른 화면으로 보낼 것 · (선택) 이전 시연 잔여 시 Debug **홈 → 설정** (`/settings`) → **`[DEMO]` 데모 데이터 초기화** 후 재시드.

앱 **내장 일정·시드**만 쓰면 아래 **Google Calendar**는 생략한다.

---

## 30초 체크리스트

- [ ] **푸시**: 기기 A 채팅 전송 → 기기 B(다른 화면) **알림 또는 스낵바** → 탭 시 **채팅** (`/chat`)으로 이동
- [ ] **지도**: 하단 **지도** 탭 (`/map`, 앱바 「가족 위치」) → 권한 배너 정상 → **위치 공유 ON** → **내 마커** (2대면 상대도 ON 후 가족 마커)
- [ ] **Google**(대본에 넣을 때만): 하단 **캘린더** 탭 (`/calendar`) → 앱바 **톱니바퀴**(툴팁 `Google Calendar 설정`, 가족 **설정** `/settings`와 **다름**) → 바텀시트에서 **Google Calendar 연결** → **동기화** → 월간 뷰 반영

---

<a id="smoke-push"></a>

## 1. 푸시

1. A·B 로그인, 같은 가족. B는 홈/다른 탭으로 보낸다.
2. A에서 **채팅 메시지** 전송 → B에 수신 표시 확인 → 알림 탭 시 **채팅**으로 이동하는지 확인.

**우회 시연**: 푸시가 안 오면 **채팅 화면을 양쪽에 띄운 채** 실시간 수신·읽음만 보여주고, 백그라운드에서는 FCM으로 온다고 구두로 넘긴다. 기기 1대면 동일하게 구두.

**짧은 복구**: Firebase Functions 로그 → Firestore `users/{uid}.fcmTokens` → 기기 알림 권한 → 앱 재시작(토큰 갱신).

---

<a id="smoke-map"></a>

## 2. 지도

1. 하단 **지도** 탭 (`/map`).
2. 상단 권한 배너가 **경고 없이** 통과하는지 확인(있으면 안내 버튼으로 설정).
3. **위치 공유** ON → 지도에 **내 마커**. 2대면 상대 기기에서도 ON → **상대 마커**.

**우회 시연**: 지도·마커가 막히면 **탭·배너·토글 UI**만 보여주고 마커는 구두로 넘기거나, 워크스루대로 **채팅·홈** 등 다음 흐름으로 바로 진행한다.

**짧은 복구**: 네이버맵 Client ID 플레이스홀더 여부([manual-build-inputs.md](./manual-build-inputs.md)) · GPS 켜짐 · 위치 권한(앱 사용 중 이상).

---

<a id="smoke-google"></a>

## 3. Google Calendar (선택)

1. 하단 **캘린더** 탭 (`/calendar`) → 앱바 우측 **톱니바퀴** → 바텀시트 **「Google Calendar 설정」**에서 **Google Calendar 연결**(가져오기) → 계정·권한.
2. 월간 뷰에 반영 확인. (시간 있으면) 앱 일정 상세에서 **Google Calendar로보내기** 확인.

**우회 시연**: 로그인·동기화가 안 되면 **시드 `[DEMO]` 일정·앱 CRUD·플래너**만으로 캘린더 단계를 시연하고, Google 연동은 “Cloud Console에서 OAuth·Calendar API 설정 후” 한 줄로 설명한다.

**데모 직전 연동 실패 시 점검**(짧게):

- **빌드와 콘솔 일치**: Android는 **지금 설치한 APK/AAB 서명**과 같은 **SHA-1**이 OAuth 클라이언트에 있는지, iOS는 번들 ID가 **`com.dongine.dongine`** 인지.
- **API·동의**: 프로젝트에 **Google Calendar API** 사용 설정, 동의 화면 **테스트 사용자**에 시연 Google 계정 포함 여부.
- **시간**: 콘솔 저장 후 **수 분** 지연 시 재시도, 앱 **재설치·재로그인**(Google 세션) 후 캘린더 설정 화면에서 다시 연결.

전체 순서·명령은 [manual-build-inputs.md §2-7](./manual-build-inputs.md#google-calendar-oauth) 참고.

---

<a id="smoke-fallback"></a>

## 우회 한눈에

| 실패 | 시연에서 이렇게 넘김 |
|------|---------------------|
| 푸시 | 채팅 실시간 동기화(양쪽 화면) + 구두 |
| 지도 | UI만 또는 다음 탭으로 스킵 |
| Google | 앱 캘린더·시드만 |

깊은 점검은 [release-checklist.md](./release-checklist.md), 사전 검증은 [real-device-validation-matrix.md](./real-device-validation-matrix.md).
