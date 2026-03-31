# Assistant Handoff

이 문서는 다음 세션에서 이전 작업 맥락을 빠르게 복원하고, 자동화 운영 방식을 동일하게 이어가기 위한 상세 인수인계 문서입니다.

## 1. 프로젝트 기준

- 메인 저장소(자동화·검증 기준): `/home/jimin/git/Dongine`
- 기본 브랜치: `main`
- 문서 디렉터리: `doc/`
- 주요 운영 문서:
  - `doc/assistant-handoff.md`
  - `doc/test-strategy.md`
- **문서 전용 클론/브랜치**: 동일 원격을 `/home/jimin/git/Dongine-claude-release-checklist-readme-sync` 등 다른 경로에 두고 작업할 수 있다. 명령은 항상 **현재 작업 중인 저장소 루트**(`git rev-parse --show-toplevel`)에서 실행하고, 문서 안의 절대 경로 예시는 로컬 환경에 맞게 치환한다.

다음 세션에서는 자동화 상태·`main` 반영 여부를 확인할 때 **메인 저장소** `/home/jimin/git/Dongine`를 기준으로 본다.
데모·릴리스 문서의 **진입 순서**는 README `시제품 데모 준비` 절을 따른다.

## 2. 사용자 선호

- 한국어 사용
- 존댓말 사용
- 말투는 친절하고 부드럽게
- 하트 이모지 `🩵`를 자연스럽게 사용
- 너무 딱딱하거나 건조한 보고는 선호하지 않음

## 3. 사용자가 원하는 진행 방식

- 사용자가 말을 걸지 않아도 자동으로 작업이 이어지길 원함
- 진행 척도는 `main`에 실제 반영된 커밋 수 기준으로 이해함
- 사용자가 진행 상황을 물어보면, 단순 상태보다 아래를 함께 설명할 것
  - 이번 확인 이후 `main`에 추가된 커밋 수
  - 방금 반영된 기능/테스트/문서
  - 현재 실행 중인 작업
  - 다음 대기 작업
  - 재시도/막힘 여부

즉, 사용자는 “자동화가 실제로 얼마나 전진했는지”를 `main` 커밋 수로 판단한다.

## 3-1. 세션 기억 강화 규칙

이 문서는 단순 메모가 아니라, 다음 세션의 보조 기억 장치 역할을 한다.
특히 사용자는 “이전 대화를 이어서 기억하는 느낌”을 매우 중요하게 본다.

다음 세션에서는 아래를 항상 먼저 복원할 것.

- 사용자의 말투 선호
- 진행 척도(`main` 커밋 수)
- 자동화 운영 상태
- 최근 무엇을 고쳤고, 무엇이 아직 막혀 있었는지
- 다음에 이어서 해야 할 우선순위

가능하면 매 세션 종료 전 아래 다섯 항목을 이 문서에 최신화한다.

- 최근 반영 커밋 묶음
- 최근 해결한 블로커
- 현재 자동화 상태(`running`, `paused`, `retry`)
- 다음 우선순위 작업
- 사용자가 새로 밝힌 선호/운영 규칙

## 3-2. 최근 3세션 핵심 맥락

### 세션 A 요약

- 사용자는 자동화가 스스로 계속 돌아가길 원한다고 명확히 요청함
- `Claude` 사용량 초과 시 `Cursor`로, `Cursor` 장애 시 `Claude`로 전환하는 유동 스위치가 필요하다고 요청함
- 진행 상황은 채팅 횟수가 아니라 `main`에 실제 반영된 커밋 수로 설명해달라고 요청함
- 말투는 존댓말 + 친절한 톤 + `🩵` 사용을 선호한다고 지정함

### 세션 B 요약

- 자동화 스크립트 쪽을 여러 차례 손봐서 backlog 자동 생성, runner 전환, 검증 게이트, pause 동작을 보강함
- 이 스크립트 변경은 저장소 밖(`/home/jimin`)에 있으므로 앱 저장소 커밋 수와 직접 1:1 대응하지 않는다는 점을 사용자에게 설명함
- 사용자는 “작업 수와 커밋 수가 어긋나면 신뢰하기 어렵다”고 분명히 말했음
- 따라서 이후 보고는 항상 `main`에 늘어난 커밋 수를 첫 줄에 적는 방식으로 맞춤

### 세션 C 요약

- 자동화로 생성된 일부 테스트/문서 커밋이 메인에 반영되었고, 검증 실패를 제대로 막는 쪽으로 운영이 바뀜
- 이번 세션에서는 검증 실패를 유발하던 로컬 변경들을 직접 고쳐서 `flutter analyze --no-pub`, `flutter test --no-pub`를 다시 모두 통과시킴
- 사용자는 다음 세션에서도 대화 맥락이 더 잘 이어지길 원해서, 이 handoff 문서를 “아주 구체적으로” 강화해달라고 요청함

## 3-3. 사용자가 중요하게 보는 설명 방식

사용자는 아래 설명을 좋아한다.

- “지금 얼마나 진행됐는지”를 수치로 먼저 말하는 것
- 기능/테스트/문서가 무엇이 반영됐는지 같이 말하는 것
- 현재 어떤 작업이 실제로 돌고 있는지 알려주는 것
- 자동화가 진짜 살아 있는지, 아니면 멈춰 있는지를 솔직하게 말하는 것

사용자는 아래 상황을 특히 싫어한다.

- 작업이 실제로 안 반영됐는데 진행된 것처럼 말하는 것
- 커밋 수와 작업 수가 어긋나는 이유를 설명하지 않는 것
- README/handoff 같은 문서가 코드 변화와 따로 노는 것

## 3-4. 다음 세션에서 바로 말해주면 좋은 첫 보고 형식

다음 세션 첫 응답은 아래 뼈대를 따르는 것이 좋다.

- 이번 확인 시점 기준 `main`에 늘어난 커밋 수
- 최근 반영된 기능/테스트/문서 2~5개
- 현재 자동화 상태
  - `running`
  - `paused`
  - `retry`
- 지금 실제 실행 중인 작업 이름
- 대기 중인 다음 작업 이름
- 막힌 점이 있으면 원인과 바로 다음 조치

예시:

- 이번 확인 기준 `main`에 `+2커밋` 반영되었어요🩵
- 가족 설정 테스트와 README 반영이 들어갔어요🩵
- 지금 자동화는 `running` 상태이고, 파일함 테스트와 TODO 편집 작업이 이어서 돌고 있어요🩵

## 4. 답변 스타일 규칙

진행 상황을 말할 때는 아래 순서를 우선한다.

1. `main`에 늘어난 커밋 수
2. 반영된 기능/테스트/문서 요약
3. 현재 실행 중인 작업
4. 대기/재시도 작업
5. 막힌 부분이 있으면 이유와 다음 조치

예시 톤:

- 이번에는 `main`에 `+3커밋` 반영되었어요🩵
- 가족 설정 테스트, 홈 네비게이션 테스트, 문서 정리가 들어갔어요🩵
- 지금은 다음 테스트 배치가 자동으로 돌고 있어요🩵

## 5. 개발/운영 원칙

- 기능 작업만 하지 말고 테스트와 문서도 같이 챙길 것
- README 같은 문서 업데이트도 작업 큐에 포함할 것
- handoff 문서도 수시로 최신화할 것
- 작업이 실제 변경을 만들지 않으면 `retry`로 맴돌게 하지 말고 `no-op`로 닫는 것이 좋음
- 자동화가 실패했을 때는 “왜 실패했는지”가 로그와 상태 파일에 남아야 함
- 사용자는 자동화가 실제로 계속 돌아가길 기대함

## 6. 자동화 아키텍처

현재 자동화는 저장소 바깥 운영 스크립트로 관리된다.

- 오케스트레이터: `/home/jimin/dongine_continuous_orchestrator.sh`
- supervisor: `/home/jimin/dongine_orchestrator_supervisor.sh`
- backlog generator: `/home/jimin/dongine_backlog_generator.sh`
- 자동화 루트: `/home/jimin/dongine-autopilot`

하위 구조:

- 작업 큐: `/home/jimin/dongine-autopilot/tasks`
- 백로그 큐: `/home/jimin/dongine-autopilot/backlog`
- 상태 파일: `/home/jimin/dongine-autopilot/state`
- 생성 이력: `/home/jimin/dongine-autopilot/generated`
- 로그 디렉터리: `/home/jimin/dongine-autopilot/logs`

핵심 로그:

- 오케스트레이터 로그: `/home/jimin/dongine-autopilot/logs/orchestrator.log`
- supervisor 로그: `/home/jimin/dongine-autopilot/logs/supervisor.log`
- generator 로그: `/home/jimin/dongine-autopilot/logs/generator.log`
- 상태 리포트 로그: `/home/jimin/dongine-autopilot/logs/status-report.log`

## 7. 자동화 동작 원칙

자동화는 아래 흐름으로 돌아간다.

1. 기존 task/state를 읽음
2. 필요 시 backlog generator가 코드 상태를 보고 새 작업을 backlog에 추가
3. pending 수가 낮아지면 backlog에서 task로 활성화
4. runner(`claude` 또는 `cursor`)를 선택해 작업 실행
5. worktree 진행이 감지되면 자동 커밋
6. `main`으로 cherry-pick
7. `flutter analyze --no-pub`
8. `flutter test --no-pub`
9. 성공 시 `git push origin main`
10. 실패 시 `PAUSED`로 중단

## 8. Claude / Cursor 전환 규칙

자동화는 고정 러너가 아니라 유동 전환을 목표로 한다.

- `Claude` 사용량 초과/네트워크 문제 감지 시 `Cursor`로 전환
- `Cursor` 사용량 초과/API·DNS 문제 감지 시 `Claude`로 전환

실제 로그에서 아래와 같은 패턴을 감지하면 전환한다.

- Claude:
  - `You're out of extra usage`
  - `usage limit`
  - `rate limit`
  - `reset`
  - `service unavailable`
- Cursor:
  - `EAI_AGAIN`
  - `api2.cursor.sh`
  - `usage limit`
  - `too many requests`
  - `temporarily unavailable`

## 9. 최근 자동화에서 보강한 점

다음 항목들은 이미 운영 로직에 반영된 내용이다.

- 코드 상태 기반 backlog 자동 생성
- 실행 중 로그를 보고 러너 문제 즉시 감지
- `Claude -> Cursor`, `Cursor -> Claude` 전환
- 무변경 작업을 `noop` 처리
- 검증 실패 시 push를 막고 `PAUSED`로 정지
- 루프 주기를 120초에서 30초로 단축

### 9-1. 현재 자동 생성 backlog 범위

최근에는 코드 상태를 보고 아래 성격의 작업까지 자동으로 씨앗을 뿌리도록 범위를 넓혔다.

- 파일/할 일/채팅/위치/Google Calendar 설정 화면의 widget 테스트
- 온보딩 화면 widget 테스트
- 가족 설정 시작 화면 widget 테스트
- 장보기 메인 화면 widget 테스트
- 앨범 목록 화면 widget 테스트
- 메인 캘린더 화면 widget 테스트

즉, 자동화는 이제 "최근 수정 파일 기반" 뿐 아니라
"아직 전용 테스트 파일이 없는 주요 화면"도 backlog로 자동 추가하려고 시도한다.

### 9-2. 2026-03-31 오전 기준 새로 추가된 자동 테스트 작업 ID

아래 작업 ID는 handoff 작성 시점에 generator가 새로 만들 수 있게 확장된 묶음이다.

- `420_claude_onboarding_screen_widget_tests`
- `430_claude_family_setup_screen_widget_tests`
- `440_claude_cart_screen_widget_tests`
- `450_claude_album_screen_widget_tests`
- `460_claude_calendar_screen_widget_tests`

다음 세션에서 자동화 상태를 점검할 때는 위 ID들이
`queued`, `running`, `integrated`, `retry` 중 어디에 있는지 먼저 확인하면 된다.

### 9-3. 시제품 완성도 기준으로 새로 반영한 자동 기능 backlog

사용자가 "시제품으로 보이려면 필요한 일"을 실제 작업 큐에 반영해달라고 요청했다.
그래서 자동화는 이제 테스트뿐 아니라 아래 시제품 우선순위도 backlog로 직접 추가한다.

- 첫 실행 경험 polish
- 프로필/가족 관리 화면 polish
- 알림 route / 딥링크 hardening
- debug 전용 데모 데이터 채우기
- 시제품 release readiness 문서화

해당 작업 ID는 아래와 같다.

- `470_claude_first_run_journey_polish`
- `480_claude_profile_family_polish`
- `490_claude_notification_deeplink_hardening`
- `500_claude_demo_seed_flow`
- `510_claude_prototype_release_readiness`

즉, 다음 세션에서는 "무슨 기능을 더 만들까?"를 다시 고르기보다
위 다섯 축이 자동으로 queue에 올라와 있는지 먼저 확인하면 된다.

### 9-4. 시제품 마감 2차 backlog

사용자가 이후에 "시제품 상태가 되려면 얼마나 더 필요한지"를 물었고,
추가 설명만 하지 말고 **실제 작업에 반영**해달라고 요청했다.

그래서 아래 항목들을 다음 자동 backlog 묶음으로 넣는다.

- `560_claude_demo_seed_entry_polish`
- `570_claude_empty_state_guidance_polish`
- `580_claude_real_device_validation_matrix`
- `590_claude_firebase_deploy_audit_doc`
- `600_claude_push_map_calendar_smoke_doc`

의도는 아래와 같다.

- 데모 데이터 진입 UX를 더 분명하게 다듬기
- 첫 실행/빈 상태에서 사용자가 다음 행동을 이해하게 만들기
- Android/iOS 실기기 검증을 사람이 그대로 따라할 수 있게 문서화하기
- Firebase rules/indexes/functions 반영 전 점검 절차를 따로 정리하기
- 푸시/지도/캘린더 smoke 시나리오를 문서화해 데모 전 리허설 비용을 낮추기

관련 프로젝트 문서는 `doc/prototype-remaining-work.md`를 기준으로 본다.

## 10. 중요한 운영 주의사항

### 10-1. `main` 커밋 수가 진행 척도

사용자는 자동화가 얼마나 전진했는지를 `main`에 반영된 커밋 수로 본다.
따라서 상태 보고 때는 항상 다음을 먼저 확인할 것.

- `git -C /home/jimin/git/Dongine log --oneline origin/main..main`
- `git -C /home/jimin/git/Dongine status -sb`

### 10-2. 검증 실패를 무시하면 안 됨

이전에는 테스트가 실패해도 `push`가 진행되는 허점이 있었다.
현재는 검증 실패 시 `PAUSED`로 멈추는 쪽이 맞다.

### 10-3. `PAUSED`가 있으면 새 작업을 계속 태우지 말 것

`/home/jimin/dongine-autopilot/PAUSED` 파일이 있으면,
우선 메인 저장소의 컴파일/테스트 오류를 해결한 뒤 해제해야 한다.

### 10-4. 운영 스크립트 수정은 앱 커밋 수에 안 잡힘

오케스트레이터/감시 스크립트 변경은 메인 저장소의 기능 커밋 수에 직접 반영되지 않는다.
사용자에게는 이 점을 분리해서 설명하는 것이 좋다.

### 10-5. 자동화가 멈춘 것처럼 보여도 실제 상태를 직접 확인할 것

과거에는 아래 같은 이유로 “겉으로는 멈춘 것처럼” 보인 적이 있었다.

- worktree에서 커밋은 생겼지만 아직 메인 반영이 안 된 경우
- 상태 파일이 `retry`로 남아 있으나 실제 작업은 이미 끝난 경우
- 검증 실패로 `PAUSED` 되었는데, 단순히 큐만 보고 진행 중으로 착각하는 경우

따라서 항상 아래를 교차 확인한다.

- `git -C /home/jimin/git/Dongine log --oneline origin/main..main`
- `/home/jimin/dongine-autopilot/PAUSED` 존재 여부
- `/home/jimin/dongine-autopilot/state/*.state`
- `orchestrator.log` 마지막 수십 줄

### 10-6. handoff 문서 자체도 실제 운영 산출물로 취급할 것

이 문서는 참고용 부록이 아니라, 자동화 운영 품질을 좌우하는 핵심 산출물이다.
따라서 아래 경우에는 handoff 업데이트를 작은 문서 작업으로 적극 포함한다.

- 사용자가 새 규칙을 정했을 때
- 자동화 구조를 바꿨을 때
- 커밋 기준 보고 방식이 달라졌을 때
- 다음 세션에서 헷갈릴 수 있는 블로커를 발견했을 때

## 11. 다음 세션 시작 체크리스트

다음 세션에서는 아래 순서로 복원할 것.

1. 이 문서 읽기
2. 저장소 상태 확인
   - `git -C /home/jimin/git/Dongine status -sb`
   - `git -C /home/jimin/git/Dongine log --oneline -12`
3. 자동화 상태 확인
   - `tail -n 80 /home/jimin/dongine-autopilot/logs/orchestrator.log`
   - `tail -n 40 /home/jimin/dongine-autopilot/logs/supervisor.log`
   - `tail -n 40 /home/jimin/dongine-autopilot/logs/generator.log`
4. 상태 파일 확인
   - `ls /home/jimin/dongine-autopilot/state`
   - `cat /home/jimin/dongine-autopilot/state/<task>.state`
5. `PAUSED` 존재 여부 확인
   - `test -f /home/jimin/dongine-autopilot/PAUSED && echo PAUSED`
6. 메인 검증 필요 시 실행
   - `flutter analyze --no-pub`
   - `flutter test --no-pub`

## 12. 문서 운영 원칙

- 기능이 늘어나면 README도 같이 갱신할 것
- 테스트 구조가 크게 바뀌면 `doc/test-strategy.md`도 갱신할 것
- 사용자가 “다음 세션에서도 기억하길 원함”이라고 말했으므로, 이 문서는 너무 짧게 유지하지 말고 실제 운영 기준을 계속 누적할 것
- handoff를 업데이트할 때는 “사용자가 다음 세션에서 어떤 질문을 가장 먼저 할지”까지 생각해서 적을 것
- 문서 업데이트만 있는 세션이라도, 의미가 크면 별도 커밋으로 남기는 것을 허용할 것

## 12-1. handoff에 계속 남겨야 하는 항목 체크리스트

매 세션 종료 전 가능하면 아래를 확인하고 최신화한다.

- 최근 반영 커밋 3~10개
- 최근 해결한 실패 테스트/분석 오류
- 아직 남아 있는 flaky test 또는 운영 리스크
- 자동화가 쓰는 러너 상태(`claude`, `cursor`, fallback 규칙)
- 현재 backlog 생성 규칙
- 다음 세션 첫 우선순위 3개

## 12-2. handoff가 답해야 하는 질문

이 문서를 잘 썼다면 다음 세션의 보조 에이전트는 아래 질문에 바로 답할 수 있어야 한다.

- 사용자는 어떤 말투를 원하나?
- 진행 상황을 어떤 숫자로 보나?
- 자동화는 어떤 스크립트가 돌리나?
- `Claude`가 막히면 무슨 일이 일어나나?
- 지금 메인이 깨끗한가?
- `PAUSED`면 왜 그런가?
- 다음으로 뭘 하면 되나?

답할 수 없다면 handoff가 충분히 구체적이지 않은 것이다.

## 13. 보고 템플릿

아래 형식을 유지하면 사용자 기대에 잘 맞는다.

- 이번 확인 이후 `main`에 늘어난 커밋 수
- 어떤 기능/테스트/문서가 들어갔는지
- 현재 실행 중인 작업 수와 작업 이름
- 대기/재시도 중인 작업 수와 작업 이름
- 막힌 점이 있으면 이유와 다음 조치

## 14. 현재 세션에서 자주 쓰는 확인 명령

저장소:

- `git -C /home/jimin/git/Dongine status -sb`
- `git -C /home/jimin/git/Dongine log --oneline -10`
- `git -C /home/jimin/git/Dongine log --oneline origin/main..main`

자동화:

- `tail -n 80 /home/jimin/dongine-autopilot/logs/orchestrator.log`
- `tail -n 40 /home/jimin/dongine-autopilot/logs/supervisor.log`
- `tail -n 40 /home/jimin/dongine-autopilot/logs/generator.log`
- `cat /home/jimin/dongine-autopilot/state/<task>.state`

검증:

- `flutter analyze --no-pub`
- `flutter test --no-pub`

## 15. 마지막 요약

다음 세션의 목표는 단순히 코드 수정이 아니라,

- 자동화가 실제로 계속 전진하고 있는지 확인하고
- 커밋 수 기준으로 진행 상황을 설명하며
- 테스트와 문서를 같이 유지하고
- 사용자가 아무 말 안 해도 다음 작업이 자연스럽게 이어지도록 운영하는 것

사용자는 “자동화가 진짜 돌아가고 있는지”를 매우 중요하게 보므로,
항상 로그, 상태 파일, `main` 커밋 수를 함께 확인하는 습관이 필요하다🩵

## 16. 현재 시점 메모

이 문서를 마지막으로 갱신한 시점 기준으로 기억해야 할 사실들:

- 메인 저장소 기준 경로는 반드시 `/home/jimin/git/Dongine`
- 사용자는 “내가 말을 안 걸어도 다음 작업 큐가 자동으로 이어지길” 기대함
- 동시에 “진행 척도는 결국 `main`에 늘어난 커밋 수”라고 명확히 정의함
- 따라서 자동화 품질은 아래 세 가지가 함께 맞아야 한다
  - 실제 작업 생성
  - 메인 반영 커밋 증가
  - 보고 내용과 실제 상태 일치
- handoff 강화 요청이 별도로 있었으므로, 이후 세션에서도 이 문서는 짧게 줄이지 말고 운영 맥락을 계속 누적하는 편이 맞다🩵
