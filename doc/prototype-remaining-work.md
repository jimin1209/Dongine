# 시제품 완성까지 남은 작업

이 문서는 **현재 `main` 기준으로 시제품 완성도를 더 끌어올리기 위해 남아 있는 작업**을 정리한 문서입니다.
이미 기능이 부족한 단계는 지났고, 이제는 **첫 실행 경험, 데모 흐름, 실기기 검증, 수동 설정 점검**을 마감하는 단계로 봅니다.

- 문서 **실사용 순서(한눈에)**: [README.md § 시제품 데모 준비](../README.md#시제품-데모-준비--문서-진입-경로)
- 수동 입력값: [manual-build-inputs.md](./manual-build-inputs.md)
- 데모 전 전체 확인: [release-checklist.md](./release-checklist.md)
- 배포 전 점검: [firebase-deploy-audit.md](./firebase-deploy-audit.md)
- 데모 직전 smoke: [demo-smoke-push-map-calendar.md](./demo-smoke-push-map-calendar.md)
- 실제 시연 순서: [demo-walkthrough.md](./demo-walkthrough.md)

## 1. 지금 가장 중요한 코드 작업

### 1-1. 데모 데이터 진입 UX 정리

현재 debug 전용 데모 데이터 채우기 흐름은 들어가 있지만, 실제 데모 전에는 아래가 더 명확하면 좋습니다.

- 진입 버튼 위치가 찾기 쉬운지
- 이미 데이터가 있을 때 중복 경고가 충분한지
- 성공 후 어떤 데이터가 들어갔는지 요약이 보이는지

### 1-2. 첫 실행 / 빈 상태 안내 다듬기

아래 상태가 처음 보는 사람에게도 자연스럽게 이해되어야 합니다.

- 로그인 전
- 로그인 후 가족 없음
- 가족은 있지만 아직 데이터 없음

우선순위는 새 기능 추가가 아니라 **다음 행동이 바로 보이게 만드는 것**입니다.

### 1-3. 알림 / 딥링크 최종 검증

코드와 테스트는 많이 보강되었지만, 데모 관점에서는 아래가 더 중요합니다.

- 푸시를 눌렀을 때 정확한 화면으로 들어가는지
- 잘못된 route 가 와도 앱이 깨지지 않는지
- TODO / 채팅 / 장보기 / 가계부 / 캘린더가 실제 payload 기준으로 일관적인지

## 2. 사람이 직접 해야 하는 검증

아래는 자동화만으로 닫히지 않습니다.

### 2-1. 실기기 빌드 확인

- Android debug 빌드
- Android release 빌드
- iOS debug 실행
- iOS release / signing 확인

### 2-2. 외부 서비스 준비

- Firebase 설정 파일 배치
- 네이버맵 Client ID 입력
- APNs 키 등록
- Google Calendar OAuth 콘솔 설정
- MQTT 브로커 값 준비

### 2-3. Firebase 서버 반영

- Firestore rules
- indexes
- storage rules
- functions 배포

## 3. 자동 backlog 에 반영된 후속 작업 묶음

자동화는 아래 항목들을 다음 우선순위로 다루도록 확장되어 있습니다.

| 작업 ID | 목적 |
|--------|------|
| `560_claude_demo_seed_entry_polish` | 데모 데이터 채우기 진입/피드백 UX 보강 |
| `570_claude_empty_state_guidance_polish` | 첫 실행·빈 상태 안내 UX 보강 |
| `580_claude_real_device_validation_matrix` | Android/iOS 실기기 검증 매트릭스 문서화 |
| `590_claude_firebase_deploy_audit_doc` | Firebase 서버 반영 전 점검 문서화 |
| `600_claude_push_map_calendar_smoke_doc` | 푸시/지도/캘린더 수동 smoke 시나리오 정리 — `doc/demo-smoke-push-map-calendar.md` 및 `doc/demo-walkthrough.md` 권장 순서와 교차 링크로 반영됨 |

## 4. 시제품 완료 판단 기준

아래 항목이 모두 충족되면, 현재 코드는 “보여줄 수 있는 시제품”이라고 말하기 쉬워집니다.

- 첫 실행부터 홈 진입까지 흐름이 끊기지 않는다
- 샘플 데이터를 바로 채워 3~5분 데모가 가능하다
- 푸시 알림 눌렀을 때 화면 이동이 자연스럽다
- Android / iOS 중 최소 한 플랫폼에서 실제 기기 시연이 안정적이다
- Firebase / 지도 / 푸시 설정 누락 여부를 문서와 preflight 스크립트로 바로 확인할 수 있다

## 5. 권장 순서

1. 수동 입력값 채우기 ([manual-build-inputs.md](./manual-build-inputs.md))
2. 프로젝트 루트에서 `bash tool/preflight.sh` 실행 ([manual-build-inputs.md 4절](./manual-build-inputs.md#4-한-번에-점검하는-빠른-명령))
3. Firebase rules·indexes·storage·functions 배포 상태 확인
4. **[demo-smoke-push-map-calendar.md](./demo-smoke-push-map-calendar.md)** 로 푸시·지도·(필요 시) Google Calendar 직전 점검
5. **Debug** 실기기 빌드로 앱 실행 — 홈 → **설정** → 데모 데이터 **초기화**(필요 시) → **채우기**
6. [demo-walkthrough.md](./demo-walkthrough.md) 기준 리허설
7. 필요 시 [release-checklist.md](./release-checklist.md) 재확인
