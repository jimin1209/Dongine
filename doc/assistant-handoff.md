# Assistant Handoff

이 문서는 다음 세션에서 이전 작업 맥락을 빠르게 복원하기 위한 운영 메모입니다.

## 프로젝트 기준 경로

- 저장소: `/home/jimin/git/Dongine`
- 기본 브랜치: `main`
- 문서 디렉터리: `doc/`

## 사용자 선호

- 한국어 사용
- 존댓말 사용
- 친절하고 부드러운 말투 선호
- 하트 이모지 사용: `🩵`

## 진행 방식

- 사용자가 말을 걸지 않아도 자동으로 작업을 계속 진행하는 흐름을 선호함
- 진행 척도는 `main`에 실제로 반영된 커밋 수 기준으로 설명
- 진행 상황을 보고할 때 아래 항목을 함께 설명
  - 이번 확인 이후 늘어난 `main` 커밋 수
  - 어떤 기능/테스트/문서 작업이 반영되었는지
  - 현재 진행 중인 작업
  - 대기 중이거나 재시도 중인 작업

## 개발/운영 원칙

- 기능 작업만 하지 말고 테스트와 문서도 같이 챙길 것
- README 같은 문서 업데이트도 작업 큐에 포함할 것
- 커밋 수와 체감 진행 상황이 최대한 비례하도록 운영할 것
- 작업이 실제 변경을 만들지 않으면 `retry`로 맴돌게 하지 말고 `no-op`로 닫는 방향 선호

## 자동화 원칙

- 기본적으로 자동화가 다음 작업을 계속 큐에 넣어야 함
- `Claude` 사용량 초과/장애 시 `Cursor`로 전환
- `Cursor` 사용량 초과/장애 시 `Claude`로 전환
- 가능하면 실행 중 로그를 보고 빠르게 다른 러너로 넘기는 쪽을 선호

## 현재 자동화 관련 파일

- 오케스트레이터: `/home/jimin/dongine_continuous_orchestrator.sh`
- supervisor: `/home/jimin/dongine_orchestrator_supervisor.sh`
- 자동화 루트: `/home/jimin/dongine-autopilot`
- 상태 파일: `/home/jimin/dongine-autopilot/state`
- 작업 큐: `/home/jimin/dongine-autopilot/tasks`
- 백로그 큐: `/home/jimin/dongine-autopilot/backlog`
- 오케스트레이터 로그: `/home/jimin/dongine-autopilot/logs/orchestrator.log`
- supervisor 로그: `/home/jimin/dongine-autopilot/logs/supervisor.log`
- 2분 상태 로그: `/home/jimin/dongine-autopilot/logs/status-report.log`

## 다음 세션 시작 방법

다음 세션에서는 아래 순서로 맥락을 복원하면 됨.

1. 이 파일 `doc/assistant-handoff.md`를 읽기
2. 저장소 상태 확인
   - `git -C /home/jimin/git/Dongine status -sb`
   - `git -C /home/jimin/git/Dongine log --oneline -10`
3. 자동화 상태 확인
   - `pgrep -af 'dongine_continuous_orchestrator.sh|dongine_orchestrator_supervisor.sh'`
   - `tail -n 40 /home/jimin/dongine-autopilot/logs/orchestrator.log`
   - `tail -n 40 /home/jimin/dongine-autopilot/logs/supervisor.log`
4. 필요 시 현재 실행/재시도 작업을 보고 다음 조치 결정

## 진행 상황 보고 템플릿

아래 형식으로 답변하면 사용자 기대에 맞음.

- 이번 확인 이후 `main`에 늘어난 커밋 수
- 방금 반영된 기능/테스트/문서 작업
- 현재 실행 중인 작업 수와 작업 이름
- 대기/재시도 중인 작업 수와 작업 이름

## 주의 메모

- 사용자는 자동화가 실제로 계속 돌아가길 기대함
- 채팅창에 먼저 말을 거는 것은 플랫폼상 불가능하므로, 대신 백그라운드 자동화와 로그 기반 운영으로 이어갈 것
- 사용자가 진행 상황을 물어보면 `커밋 수`를 먼저 말하고, 그 뒤에 어떤 기능이 반영됐는지 친절하게 설명할 것
