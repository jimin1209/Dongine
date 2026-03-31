# 시연 담당자 운영 체크리스트 (초압축)

> **역할**: 당일 **시간축(10분 전 → 시연 중)**만 틱으로 짚는다. **푸시·지도 절차**, **3–5분 대본**, **빌드 게이트**는 아래 링크 문서에만 있다.

| 문서 | 담당 |
|------|------|
| **본 문서** | 타이밍별 짧은 체크 + 실패 시 **어디를 펼칠지**만 안내 |
| [demo-smoke-push-map-calendar.md](./demo-smoke-push-map-calendar.md) | 직전 **1–2분** 푸시·지도·(선택) Google **구체 절차**·[우회 표](./demo-smoke-push-map-calendar.md#smoke-fallback) |
| [demo-walkthrough.md](./demo-walkthrough.md) | **3–5분** 시연 대본·탭 경로 ([준비 §0](./demo-walkthrough.md#walkthrough-demo-prep)) |
| [README — 데모 준비 표](../README.md#시제품-데모-준비--문서-진입-경로) | **1~9** 전체 순서(빌드·매트릭스·smoke·시드·시연) |

---

## 시작 10분 전

- [ ] **앱**: Debug `flutter run` — Release에는 시드 UI 없음 ([워크스루 §0](./demo-walkthrough.md#walkthrough-demo-prep))
- [ ] **계정·가족**: 시연용 2계정 **같은 가족** · 푸시용 기기 배치(2대 권장, 1대면 구두 우회) ([워크스루 §0](./demo-walkthrough.md#walkthrough-demo-prep))
- [ ] **빌드·환경**: 당일 처음이면 [README 표 1~6](../README.md#시제품-데모-준비--문서-진입-경로)까지 이미 통과했다고 가정; 미통과 시 그 표부터

---

## 시작 2분 전

- [ ] **데모 데이터**: **홈** → 톱니 → **설정** (`/settings`) → `[DEMO]` 잔여 시 **초기화** 후 **채우기** ([워크스루 §0](./demo-walkthrough.md#walkthrough-demo-prep))
- [ ] **Smoke(1–2분)**: [demo-smoke-push-map-calendar.md](./demo-smoke-push-map-calendar.md) **30초 체크리스트** — 푸시·지도·(대본에 넣을 때만) Google
- [ ] **네트워크·알림 권한**: B 기기 알림·백그라운드 허용 여부 한 번 확인 ([smoke 당일 전제](./demo-smoke-push-map-calendar.md))

---

## 시연 직전

- [ ] **화면**: 시연 시작 탭을 **홈** 또는 대본 첫 화면으로 맞춤 ([워크스루 1단계~](./demo-walkthrough.md#walkthrough-step-1))
- [ ] **실패 분기 숙지**: 푸시·지도·Google 중 막힌 항목 → [우회 표](./demo-smoke-push-map-calendar.md#smoke-fallback)만 열어 두기
- [ ] **청중 각도**: 케이블·밝기·방해 금지 모드

---

## 시연 중 fallback

- [ ] **푸시 안 됨** → 채팅 **양쪽 화면** 실시간 + FCM은 구두 ([우회 표](./demo-smoke-push-map-calendar.md#smoke-fallback))
- [ ] **지도·마커 이슈** → **탭·배너·공유 토글**만 보여 주고 다음 단계 ([우회 표](./demo-smoke-push-map-calendar.md#smoke-fallback))
- [ ] **Google Calendar 실패** → 앱 일정·`[DEMO]` 시드·플래너만 ([우회 표](./demo-smoke-push-map-calendar.md#smoke-fallback))
- [ ] **딥링크·화면 불일치** → [push-route-debug](./demo-smoke-push-map-calendar.md#push-route-debug) (시연 직후 메모용)
- [ ] **대본 이탈** → [demo-walkthrough.md](./demo-walkthrough.md) 목차로 복귀

---

**전 기능 QA·표**: [real-device-validation-matrix.md](./real-device-validation-matrix.md) · **통합 게이트**: [release-checklist.md](./release-checklist.md)
