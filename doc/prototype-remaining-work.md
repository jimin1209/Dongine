# 시제품 완성까지 남은 작업

**현재 `main` 기준**으로 시제품 완성도를 더 끌어올릴 때 남은 작업을 정리한 문서다. 신규 기능 추가보다 **첫 실행·데모 흐름·실기기 검증·수동 설정 점검** 마감이 우선이다.

**문서 권장 순서(README·[release-checklist.md](./release-checklist.md)와 동일)**  
1 [manual-build-inputs.md](./manual-build-inputs.md) → 2 `bash tool/preflight.sh` ([§4](./manual-build-inputs.md#preflight-quick-command), [실행 전후·증상](./manual-build-inputs.md#preflight-human-checklist)) → 3 [firebase-deploy-audit.md](./firebase-deploy-audit.md) → 4 [release-checklist.md](./release-checklist.md)(§0~§6) → 5 (선택) [deploy-functions.md](./deploy-functions.md) → 6 [real-device-validation-matrix.md](./real-device-validation-matrix.md) → 7 [demo-smoke-push-map-calendar.md](./demo-smoke-push-map-calendar.md) (**약 1–2분 smoke**) → 8 Debug `flutter run` → **홈** 톱니 → **설정** (`/settings`)에서 데모 초기화·채우기 → 9 [demo-walkthrough.md](./demo-walkthrough.md) (**약 3–5분** 본 시연, `MainShell` 5탭 + `/todo`·`/cart`·`/expense` 등).

한눈 표: [README — 시제품 데모 준비](../README.md#시제품-데모-준비--문서-진입-경로). smoke와 본 시연 차이는 README 「3–5분 본 시연 vs 직전 smoke」와 [demo-walkthrough.md](./demo-walkthrough.md) 서두 표를 본다.

## 1. 지금 가장 중요한 코드 작업

### 1-1. 데모 데이터 진입 UX 정리

- 진입 버튼(설정 하단)이 찾기 쉬운지
- 기존 데이터가 있을 때 중복 경고가 충분한지
- 성공 후 요약 대화상자가 명확한지

### 1-2. 첫 실행 / 빈 상태 안내

로그인 전·가족 없음·데이터 없음에서 **다음 행동**이 바로 보이게 다듬는다.

### 1-3. 알림 / 딥링크 최종 검증

푸시 탭 시 화면 이동, 잘못된 `route` 내성, TODO·채팅·장보기·가계부·캘린더 페이로드 일관성.

## 2. 사람이 직접 해야 하는 검증

화면을 표로 돌릴 때는 [real-device-validation-matrix.md](./real-device-validation-matrix.md)만 쓰고, 빌드·콘솔·명령은 [release-checklist.md](./release-checklist.md)에 맡긴다(release-checklist §7은 표를 중복하지 않음). **위치 공유·백그라운드**는 매트릭스 §8과 함께 [location-background-demo.md](./location-background-demo.md)로 **권한 단계·배너·시연 vs 한계**를 맞춘다.

### 2-1. 실기기 빌드

Android debug/release, iOS debug, iOS release·서명.

<a id="manual-inputs-checklist-order"></a>

### 2-2. 수동 입력값(정리는 [manual-build-inputs.md](./manual-build-inputs.md) §1)

1. Firebase 설정 파일 3종·프로젝트 연결  
2. 네이버맵 Client ID(Android·iOS·선택 `--dart-define`)  
3. (선택) Google Calendar OAuth — [§2-7](./manual-build-inputs.md#google-calendar-oauth): Calendar API 사용 설정 → 동의 화면(테스트 사용자) → Android(SHA·패키지명) → iOS(번들 ID)  
4. (선택) MQTT `--dart-define`  
5. iOS APNs 키·푸시 capability  
6. Android release: `key.properties`·keystore  
7. iOS 서명·배포 자격  
8. Firebase rules·indexes·storage·functions 배포

### 2-3. 빌드 전 체크 순서(통합 게이트)

[release-checklist.md](./release-checklist.md) **§0~§6**과 같다: preflight → Firebase → FCM → 네이버맵 → Functions → Android → iOS. preflight **직전·직후**에 사람이 볼 체크와 **자주 빠지는 설정의 증상 표**는 [manual-build-inputs.md](./manual-build-inputs.md)([Preflight 실전](./manual-build-inputs.md#preflight-human-checklist), [증상 ↔ 위치](./manual-build-inputs.md#common-config-failure-symptoms))에만 상세히 둔다.

## 3. 자동 backlog 묶음

| 작업 ID | 목적 |
|--------|------|
| `560_claude_demo_seed_entry_polish` | 데모 시드 진입·피드백 UX |
| `570_claude_empty_state_guidance_polish` | 첫 실행·빈 상태 안내 |
| `580_claude_real_device_validation_matrix` | 실기기 검증 매트릭스 |
| `590_claude_firebase_deploy_audit_doc` | Firebase 배포 전 점검 문서 |
| `600_claude_push_map_calendar_smoke_doc` | smoke·워크스루 문서 및 교차 링크 |

## 4. 시제품 완료 판단 기준

- 첫 실행부터 홈까지 흐름이 끊기지 않는다
- 샘플 데이터로 3~5분 데모가 가능하다
- 푸시 탭 시 화면 이동이 자연스럽다
- Android 또는 iOS 중 최소 한 플랫폼에서 실기기 시연이 안정적이다
- Firebase·지도·푸시 누락을 문서·preflight로 바로 확인할 수 있다

## 5. 권장 순서 (README 표와 동일 1~9)

1. [manual-build-inputs.md](./manual-build-inputs.md) — 수동 입력값  
2. `bash tool/preflight.sh` — [§4](./manual-build-inputs.md#preflight-quick-command) · [실행 전후·증상](./manual-build-inputs.md#preflight-human-checklist)  
3. [firebase-deploy-audit.md](./firebase-deploy-audit.md) — dry-run 후 서버 반영  
4. [release-checklist.md](./release-checklist.md) — §0~§6 완료  
5. (선택) [deploy-functions.md](./deploy-functions.md)  
6. [real-device-validation-matrix.md](./real-device-validation-matrix.md)  
7. [demo-smoke-push-map-calendar.md](./demo-smoke-push-map-calendar.md) — 직전 smoke  
8. Debug `flutter run` → **홈** → **설정** (`/settings`) → 데모 초기화·채우기  
9. [demo-walkthrough.md](./demo-walkthrough.md) — 3–5분 본 시연
