# 테스트 맵 (자동화 누적 기준)

실무 메모. `flutter test`(Flutter CI)에 올라간 범위만 기준으로 한다. Functions는 별도 워크플로(`functions/**`).

## 이미 들어간 영역 (짧게)

| 구역 | 테스트 파일(대표) | 비고 |
|------|-------------------|------|
| Auth | `auth_repository_test`, `login_screen_test` | 온보딩·라우터 전체는 없음 |
| Family | `family_settings_helpers_test` | 설정 헬퍼만. setup/설정 화면·repo·provider 없음 |
| Chat | `chat_unread_test`, `command_parser_test` | 파서·읽음. `command_handler`/화면/repo 없음 |
| Location | `location_*` 3종 | 권한 UI 모델·공유 동기·멤버 데이터 |
| Files | `files_provider_test`, `file_transfer_*`, `files_item_actions_regression_test` | 전송·액션 회귀 포함 |
| Calendar | `calendar_*` 4종 | 복원·뷰 프리퍼런스·헬퍼·GCal sync prefs |
| Cart | `cart_regression_test` | 회귀 위주 |
| Expense | `expense_model_test`, `expense_insight_test` | 화면·repo·provider 없음 |
| Album | `bulk_delete_test`, `album_bulk_delete_flow_test` | 일괄 삭제 위주 |
| IoT | `iot_device_management_test` | |
| Shared | `*_model_test`(family/event/album/location/todo), `home_status_model_test` | 도메인 모델·홈 상태 |
| Core | `notification_service_test` | |
| Smoke | `widget_test.dart` | 기본 위젯 스모크 |

## 비어 있거나 매우 얕은 영역

- **Todo 기능**: `todo_model`만. `todo_screen` / `todo_provider` / `todo_repository` 없음.
- **플래너 탭·시트**: `calendar_tab_planner`, 생성 시트 등 UI/로직 테스트 없음.
- **가족 흐름 전체**: 초대·가입·`family_setup_screen`·`family_repository`·`family_provider`.
- **채팅 나머지**: `command_handler`, `chat_screen`, `chat_repository`, 슬래시 커맨드별 핸들러(파서 제외).
- **캘린더 심화**: `google_calendar_service`·동기화/보내기 통합, 일정 생성 시트·TODO 탭 UI.
- **가계부/장보기 심화**: `expense_screen`·`expense_repository`·`cart_repository`·헬퍼 단위 테스트 부족.
- **앨범 UI**: 리스트/상세 화면·업로드·커버 정합성(로직은 repo 쪽, 테스트 없음).
- **앱 셸**: `MainShell`, GoRouter, 스플래시·테마.
- **온보딩**: `onboarding_screen`.

## 다음 세션에서 공백 잡을 때

1. 위 표에서 **없는 파일/기능**부터 `lib/features/**`와 1:1로 대조.
2. 회귀 후보는 **Firestore/Storage와 엮인 화면 액션**·**상태 복원**·**권한 분기** 우선.
3. CI는 `flutter analyze` + 전체 `flutter test` — 새 테스트 추가 시 전체 그린 유지.
