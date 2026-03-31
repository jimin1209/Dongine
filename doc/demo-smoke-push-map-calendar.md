# 데모 직전 Smoke — 푸시 / 지도 / Google Calendar

> **목적**: 커튼 직전 **1~2분**에 푸시·지도·(선택) Google Calendar만 확인한다.  
> **문서 흐름**: [README — 시제품 데모 준비](../README.md#시제품-데모-준비--문서-진입-경로) → **본 문서** → 시연 [demo-walkthrough.md](./demo-walkthrough.md).

**당일 전제**: 안정 네트워크 · 계정 2개 **같은 가족** · (선택) Debug **설정** → `[DEMO]` 데모 데이터 초기화.

앱 **내장 일정·시드**만 쓰면 아래 **Google Calendar**는 생략한다.

---

## 30초 체크리스트

- [ ] **푸시**: 기기 A 채팅 전송 → 기기 B(다른 화면) **알림 또는 스낵바** → 탭 시 채팅으로 이동
- [ ] **지도**: **지도** 탭 → 권한 배너 정상 → **위치 공유 ON** → **내 마커** (2대면 상대도 ON 후 가족 마커)
- [ ] **Google**(대본에 넣을 때만): **캘린더** 탭 → **가져오기** → 로그인·동의 → 월간 뷰 반영

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

1. **캘린더** 탭 → **Google Calendar 가져오기** → 계정·권한.
2. 월간 뷰에 반영 확인. (시간 있으면) 앱 일정 → **Google로 보내기** 확인.

**우회 시연**: 로그인·동기화가 안 되면 **시드 `[DEMO]` 일정·앱 CRUD·플래너**만으로 캘린더 단계를 시연하고, Google 연동은 “OAuth·Calendar API 설정 후” 한 줄로 설명한다.

**짧은 복구**: Google Cloud OAuth(Android SHA·iOS 번들)·Calendar API 사용 설정·테스트 사용자(동의 화면이 테스트 모드일 때).

---

<a id="smoke-fallback"></a>

## 우회 한눈에

| 실패 | 시연에서 이렇게 넘김 |
|------|---------------------|
| 푸시 | 채팅 실시간 동기화(양쪽 화면) + 구두 |
| 지도 | UI만 또는 다음 탭으로 스킵 |
| Google | 앱 캘린더·시드만 |

깊은 점검은 [release-checklist.md](./release-checklist.md), 사전 검증은 [real-device-validation-matrix.md](./real-device-validation-matrix.md).
