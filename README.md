# 동이네 (Dongine)

가족 단위로 캘린더·채팅·파일·장보기 등을 묶어 쓰는 Flutter 앱(Android / iOS). 백엔드는 Firebase(Firestore, Storage, Auth, FCM, Cloud Functions)를 사용한다.

## 시제품 데모 준비 — 문서 진입 경로

아래는 **한 번에 끝까지 읽을 때의 권장 순서**다. 역할이 겹치지 않게 나뉘어 있다.

| 구분 | 순서 | 문서 | 역할 |
|------|------|------|------|
| **빌드·배포 전** | 1 | [doc/manual-build-inputs.md](./doc/manual-build-inputs.md) | Firebase·네이버맵·APNs·OAuth 등 **수동으로 넣을 값** |
| | 2 | `bash tool/preflight.sh` | 로컬 **파일·플레이스홀더** 읽기 전용 일괄 점검 ([manual-build-inputs.md 4절](./doc/manual-build-inputs.md#4-한-번에-점검하는-빠른-명령)) |
| | 3 | [doc/firebase-deploy-audit.md](./doc/firebase-deploy-audit.md) | 서버 반영 **전** Rules·Indexes·Storage·Functions dry-run(권장) |
| | 4 | [doc/release-checklist.md](./doc/release-checklist.md) | **통합 게이트** — Firebase·FCM·지도·Functions·Android/iOS 빌드·명령까지 한 줄기로 확인 |
| | 5 | [doc/deploy-functions.md](./doc/deploy-functions.md) | Functions만 따로 배포·검증할 때 |
| **실기기 검증** | 6 | [doc/real-device-validation-matrix.md](./doc/real-device-validation-matrix.md) | Android/iOS에서 **기능별 Pass/Fail 표**(53항). 릴허설·QA 주간용. 체크리스트·smoke와 **목록이 다름**(중복 없이 보완) |
| **데모 당일** | 7 | [doc/demo-smoke-push-map-calendar.md](./doc/demo-smoke-push-map-calendar.md) | 커튼 올리기 **직전 1~2분** — 푸시·지도·(선택) Google Calendar만 |
| **시연** | 8 | [doc/demo-walkthrough.md](./doc/demo-walkthrough.md) | **3–5분** 라우팅·탭 순서·대본·트러블슈팅 |

**맥락·백로그**: [doc/prototype-remaining-work.md](./doc/prototype-remaining-work.md), [doc/assistant-handoff.md](./doc/assistant-handoff.md), [doc/test-strategy.md](./doc/test-strategy.md).

---

## 문서 기준

이 README는 저장소 **현재 `main`에 있는 코드와 설정 파일**을 기준으로 정리했다. 배포·스토어 제출·운영 SLA를 보장하는 문서가 아니다.

위 표가 **데모·시제품 준비의 기본 길잡이**다. **빌드 전**은 preflight·체크리스트가 담당하고, **실기기 깊은 검증**은 매트릭스, **무대 직전**은 smoke, **말하면서 따라갈 순서**는 워크스루다. 그 외 참고 문서는 아래.

| 문서 | 용도 |
|------|------|
| [doc/test-strategy.md](./doc/test-strategy.md) | Flutter 테스트 누적 범위·공백 요약 |
| [doc/assistant-handoff.md](./doc/assistant-handoff.md) | 다음 세션 맥락·자동화 운영 인수인계 |

---

## 시제품 데모 가능 기능 (현재 코드 기준)

아래 기능은 코드가 구현되어 있고, 환경 설정만 갖추면 데모할 수 있다.

| 기능 | 핵심 동작 | 비고 |
|------|----------|------|
| 이메일 인증 | 가입·로그인·로그아웃 | Firebase Auth 이메일/비밀번호 |
| 가족 관리 | 생성·초대 코드·참가·복수 가족 전환 | 초대 코드 6자리, 7일 만료 |
| 채팅 | 실시간 메시지·읽음 처리·슬래시 커맨드 10종 | Firestore 실시간 |
| 캘린더 | 월간 뷰·일정 CRUD·유형 필터·플래너 탭 | TableCalendar |
| 할 일 | CRUD·담당자·마감일·완료 토글 | 채팅 `/todo`로도 생성 가능 |
| 장보기 | 품목 추가·추천·중복 병합·체크 | 빈도 기반 추천 |
| 가계부 | 지출 기록·월별 합계·차트·카테고리 필터 | 채팅 `/expense`로도 기록 가능 |
| 파일함 | 업로드·다운로드·폴더 탐색·검색·정렬 | 최대 100MB |
| 앨범 | 앨범 생성·사진 업로드·커버 자동 관리 | |
| 위치 공유 | 실시간 위치·권한 안내·공유 토글 | 네이버맵 + Geolocator |
| 홈 대시보드 | 한눈에 보기 카드·바로가기·미리보기 | |
| 푸시 알림 | 채팅·일정·할 일·장보기·가계부 생성 알림 | Cloud Functions 트리거 |

## 아직 운영 준비가 덜 된 부분

아래 항목은 코드가 있거나 일부 동작하지만, 데모/운영으로 쓰려면 추가 설정 또는 작업이 필요하다.

| 항목 | 현재 상태 | 데모/운영에 필요한 작업 |
|------|----------|----------------------|
| Google Calendar 연동 | 코드 구현 완료 | Google Cloud Console에서 OAuth 클라이언트 설정 (Android SHA, iOS 번들 ID 등록) |
| IoT (MQTT) | 코드 구현 완료, 미설정 시 안내 배너 표시 | 실제 MQTT 브로커 주소를 `--dart-define`으로 주입, 기기 펌웨어는 별도 |
| Android Release 서명 | debug 서명으로 빌드 가능 | `key.properties` + 프로덕션 keystore 준비 |
| iOS 배포 | debug 빌드 가능 | Apple Developer 계정, provisioning profile, App Store Connect 설정 |
| 네이버맵 키 | 플레이스홀더(`YOUR_NAVER_MAP_CLIENT_ID`) 상태 | 네이버 클라우드에서 Client ID 발급 후 gradle.properties·xcconfig에 입력 |
| iOS 푸시 (APNs) | 앱 코드 준비 완료 | Apple Developer에서 APNs 키 발급 → Firebase Console 등록 |
| Firebase 보안 규칙 | 개발용 규칙 작성 완료 | 운영 전 최종 검토·배포 필요 |
| Crashlytics / Analytics | 미설정 | 운영 모니터링에 필요하면 활성화 |

---

## 인증과 Google 로그인의 역할

- **로그인·회원가입**: Firebase Auth **이메일/비밀번호**만 앱 로그인 흐름에 사용한다 (`LoginScreen` → `signInWithEmail` / `signUpWithEmail`).
- **Google 계정**: `google_sign_in`은 **Google Calendar API 연동**(`GoogleCalendarService`)에서만 쓰인다. 앱 계정으로 Google 소셜 로그인을 제공하지 않는다.

---

## 가족·초대

- 가족 생성·초대 코드 참가, **복수 가족 소속** 및 설정 화면의 **가족 전환**.
- 초대 코드 길이·만료: `AppConstants` 기준 **6자리**, **7일** (`inviteCodeLength`, `inviteExpirationDays`).
- **만료 후 재발급**: 관리자가 가족 설정에서 새 코드를 발급하고, Firestore `invitations` 문서와 가족 문서의 코드·만료 시각을 갱신한다.
- 보안 규칙에서 `hasValidInvitation`으로 **만료·활성 여부**를 검사해 가입 경로를 제한한다 (`firestore.rules`).

---

## 채팅: 읽음 처리와 커맨드

- 메시지에 `readBy` 맵(사용자별 타임스탬프)을 두고, 채팅 화면에서 상대 메시지에 대해 **`markAsRead`**로 갱신한다.
- **내 메시지** 타임스탬프 옆에 다른 구성원 읽음 수(`읽음 N`) 또는 전송만 된 상태 표시를 둔다.
- **삭제**: 발신자·관리자 기준의 소프트 삭제(`isDeleted`). 일반 텍스트 메시지 **내용 편집 UI는 없다**(규칙상 발신자 update는 가능하나 앱에서 본문 수정 흐름은 구현되어 있지 않음).
- **슬래시 커맨드 10종**: `/todo`, `/remind`, `/location`, `/calendar`, `/poll`, `/meal`, `/date`, `/cart`, `/expense`, `/members` — 입력 시 제안 목록(`CommandSuggestions`), 파서·핸들러로 처리한다.

---

## 위치 공유: 프로세스가 살아 있는 동안(백그라운드 포함)

- 추적은 **`MainShell`이 마운트된 뒤** `familyLocationTrackingBootstrapProvider`에서 유지된다. **로그인·현재 가족·앱 내 위치 공유 토글이 모두 만족할 때만** `Geolocator.getPositionStream`으로 좌표를 받고, `AppConstants.locationUpdateIntervalSeconds`(기본 **30초**) 간격으로 Firestore 업로드를 스로틀한다.
- 토글을 끄면 스트림을 끊어 **즉시 중단**하고, 켜면 다시 시작한다.
- **Android**: 전면 위치 서비스용 알림(`AndroidSettings.foregroundNotificationConfig`)과 `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` 선언을 둔다(플러그인·OS 동작에 맞게 실제 런타임 권한은 기기/OS 버전별로 달라질 수 있음).
- **iOS**: `UIBackgroundModes`에 `location`, `NSLocationAlwaysAndWhenInUseUsageDescription`을 추가한다. **항상** 권한이 있으면 백그라운드 갱신에 유리하고, **사용 중**만 허용하면 백그라운드 유지가 제한될 수 있다.
- **보장하지 않는 것**: 사용자가 앱을 스와이프로 완전히 종료하거나, OS가 메모리 압박 등으로 프로세스를 죽인 뒤에는 갱신이 멈춘다. 지도는 네이버맵(`flutter_naver_map`), 위치는 Geolocator.
- **가족 위치 화면(`LocationScreen`)**: 상단에 기기 위치 서비스·앱 위치 권한 상태를 짧게 표시한다. 백그라운드 공유에 불리한 상태(예: iOS에서 「앱 사용 중만」)면 설명과 함께 `Geolocator.openAppSettings` / `openLocationSettings`로 이어지는 버튼을 둔다. 공유 토글은 Firestore와 동기화되지만, 권한이 부족하면 「켜짐(위치 불가)」「공유 중(백그라운드 제한)」처럼 실제 갱신 가능 여부를 라벨로 구분한다.

---

## 파일함: 검색·정렬·필터(현재 동작)

- **검색**: 현재 폴더 기준, 파일/폴더 **이름 부분 문자열**(대소문자 무시) 필터. 검색 UI는 앱바 토글로 연다.
- **정렬**: 이름순, 최신순, 오래된순, 큰 용량순(`FilesSortOption`).
- **유형 필터**: 전체 / **폴더만** / **파일만**(`FilesTypeFilter`). MIME 기반 “문서·이미지·영상” 카테고리 필터는 아니다.
- 폴더 탐색·브레드크럼, 그리드/리스트 전환, Storage 업로드/다운로드. 업로드 크기 상한은 `AppConstants.maxFileUploadSizeMB`(기본 **100MB**).

---

## 캘린더·Google Calendar·TODO·플래너

- **캘린더 탭**: 월간 뷰(TableCalendar), 일정 유형(일반·식사·나들이·기념일·병원 등), 종일/시간, 필터.
- **플래너 탭**: 식사·데이트·기념일·병원 등 플래너 전용 UI와 일정 연동.
- **Google Calendar**
  - **가져오기**: 로그인 후 기간 내 Google `primary` 캘린더 → Firestore 가족 일정으로 반영·갱신·(원격에 없으면) 삭제. `externalUpdatedAt`으로 덮어쓰기 여부 판단.
  - **보내기**: 앱에서 만든 일정을 Google에 생성/수정/삭제(`exportToGoogle` 등). 가져온 일정(`externalSource == google_calendar`)은 업데이트 경로가 맞게 이어진다.
- **FCM**: Cloud Functions에서 일정 생성 알림 시 `externalSource === 'google_calendar'`인 문서는 **알림을 보내지 않는다**(가져온 일정 스팸 방지).
- **TODO**: 별도 `/todo` 화면에서 CRUD, 담당·마감일·완료 토글. 채팅 `/todo`로도 생성 가능. 홈 탭에 미완료 개수·상위 목록 표시(홈에서는 **완료 토글 UI 없음**, 목록·바로가기만).

---

## 장보기: 추천과 중복 병합

- 목록 쿼리: `isChecked` → `createdAt` 순(복합 **인덱스** `firestore.indexes.json`에 정의).
- **추천**: 최근 **최대 100개** 장보기 문서에서 품목명 빈도를 세어 상위 **10개**를 칩으로 제안(`getFrequentItems`). 이미 목록에 있는 이름은 UI에서 걸러 낸다.
- **중복 병합**: 화면에서 추가 시 **`addOrMergeItem`** — 동일 이름·**미체크** 항목이 있으면 트랜잭션으로 `quantity`만 합산, 없으면 새 문서 생성.

---

## 가계부: 편집과 필터

- 지출 목록·월별 합계·차트, 항목 **수정·삭제** UI, 카테고리 **필터**(전체 또는 단일 카테고리). 채팅 `/expense`로 기록 가능.

---

## 앨범 커버 정합성

- 사진 업로드 시 **첫 사진이면** `coverPhotoUrl` 설정.
- 사진 삭제 시 삭제한 것이 커버이거나 사진이 없어지면, **남은 사진 중 최신**을 커버로 옮기거나 null로 맞춘다(`album_repository` 주석·로직).

---

## IoT(MQTT)

- 앱은 `AppConstants.mqttBrokerUrl` / `mqttBrokerPort`가 플레이스홀더가 아닐 때만 **`isMqttBrokerConfigured == true`** 로 간주한다.
- **미설정**이면 MQTT 연결을 시도하지 않고, IoT 화면에 **안내 배너**와 앱바 **“MQTT: 미설정”** 툴팁을 띄운다(`--dart-define=MQTT_BROKER_URL=...` 안내 문구 포함).
- 브로커가 설정된 경우에만 연결·재연결·제어 명령 publish 흐름이 의미 있다. **실제 브로커·토픽·기기 펌웨어는 이 저장소 밖 전제**다.

---

## FCM과 Cloud Functions

- **앱**: `firebase_messaging`으로 권한 요청, 포그라운드 수신 시 스낵바, 열기/초기 메시지에서 `data.route`로 라우팅. 사용자 문서에 FCM 토큰 arrayUnion/arrayRemove.
- **Functions** (`functions/index.js`, 리전 **asia-northeast3**): Firestore `onDocumentCreated`로  
  채팅 메시지, 캘린더 일정, TODO, 장보기 항목, 가계부 지출 생성 시 푸시.  
  무효 토큰 정리 로직이 포함되어 있다.
- **알림 라우트**(페이로드): 채팅 `/chat`, 일정 `/calendar`, **TODO 생성** `/todo`, 장보기 `/cart`, 가계부 `/expense` — TODO 생성 알림 탭 시 할 일 화면으로 이동한다.

---

## 홈(대시보드) 탭

- 가족 이름·초대 코드, **한눈에 보기** 2×2 카드: 남은 할 일 수, 장보기 미체크 수, 이번 달 지출(원화 표기), 오늘 0시 이후 일정 건수.
- **바로가기**: 장보기, 가계부, 앨범, IoT, 할 일.
- **오늘의 할 일**·**다가오는 일정** 각각 최대 5건 미리보기.

---

## 기술 스택(의존성 기준)

| 영역 | 내용 |
|------|------|
| 프레임워크 | Flutter(stable), Dart SDK `^3.11.4`(`pubspec.yaml`의 `environment.sdk`) |
| 상태·라우팅 | Riverpod, GoRouter |
| Firebase | Auth, Firestore, Storage, FCM, Cloud Functions |
| 캘린더 UI | TableCalendar |
| Google Calendar | googleapis, googleapis_auth, **google_sign_in**(캘린더 전용) |
| 지도 | flutter_naver_map |
| IoT | mqtt_client |
| CI | GitHub Actions(아래 참고) |

---

## CI (GitHub Actions, `main` 기준)

| 워크플로 | 트리거 요약 | 내용 |
|----------|----------------|------|
| **Flutter CI** (`.github/workflows/flutter-ci.yml`) | `main`에 push/PR, 경로에서 `functions/**`·`*.md` 제외 | `flutter pub get` → `flutter analyze` → `flutter test` |
| **Functions CI** (`.github/workflows/functions-ci.yml`) | `functions/**` 또는 해당 워크플로 변경 시 | Node **20**, `npm ci` → `npm run lint` → `npm test` |

---

## 데모 전 빠른 준비 (요약)

전체 항목·명령은 **[doc/release-checklist.md](./doc/release-checklist.md)** 에 따른다. 여기서는 뼈대만 적는다.

**권장 순서(요약)**: preflight → analyze/test → Firebase·Functions 반영 → (시간 있으면) **[실기기 매트릭스](./doc/real-device-validation-matrix.md)** → **[데모 직전 Smoke](./doc/demo-smoke-push-map-calendar.md)** → **Debug** `flutter run` → 로그인·가족 후 **설정**에서 데모 데이터 **초기화/채우기** → **[워크스루](./doc/demo-walkthrough.md)** 순 시연.

- 데모 시드·초기화 버튼은 **Debug 빌드 전용**이며, 홈 우상단 **설정** 하단에 있다.
- **채우기** 성공 시 할 일·장보기·가계부·일정 건수 요약이 대화상자로 뜬다. 이미 샘플이 있으면 중복 방지 안내 대화상자가 뜨고, **초기화** 성공 시 삭제 건수 요약과 다음 행동(탭 확인·다시 채우기) 안내가 대화상자로 뜬다.
- 데모 데이터 초기화는 제목/이름이 **`[DEMO]`** 로 시작하는 문서만 지우고, 사용자가 만든 실제 데이터는 건드리지 않는다.
- 앱 시작 흐름(스플래시 → 온보딩 또는 홈/가족 설정)과 단계별 대본은 [doc/demo-walkthrough.md](./doc/demo-walkthrough.md) 기준으로 맞춰 두었다.

---

## 설치·실행·로컬 검증 명령

**프로젝트 루트**(`pubspec.yaml`이 있는 디렉터리)에서 아래를 실행한다. 경로만 본인 클론 위치로 바꾸면 된다.

```bash
cd /home/jimin/git/Dongine-claude-release-demo-doc-polish

# 빌드 전 수동 입력 파일·플레이스홀더 일괄 점검(읽기 전용). 실패(✗)가 있으면 종료 코드 1.
bash tool/preflight.sh

# 통과한 뒤 CI와 같은 계열로 분석·테스트까지 한 번에
bash tool/preflight.sh && flutter pub get && flutter analyze && flutter test
```

```bash
# Flutter 의존성
flutter pub get

# 정적 분석·단위 테스트 (Flutter CI와 동일 계열)
flutter analyze
flutter test
```

```bash
# Cloud Functions (functions 디렉터리)
cd functions
npm ci
npm run lint
npm test
```

Firebase CLI로 앱에 연결하려면(예시):

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<프로젝트_ID>
```

실제 프로젝트 ID는 `firebase_options.dart` / `firebase.json`의 `flutter.platforms`와 맞출 것.

---

## 외부 설정(필수에 가까운 것)

항목별 위치·명령·배포 절차는 **[doc/manual-build-inputs.md](./doc/manual-build-inputs.md)** 에 모아 두었다. README에서는 앱 동작 이해용으로만 요약한다.

- **Firebase**: 플랫폼 설정 파일 + `lib/firebase_options.dart` (보통 저장소에 없음).
- **네이버맵**: Gradle / xcconfig 또는 `--dart-define=NAVER_MAP_CLIENT_ID=...`.
- **Google Calendar**: OAuth 클라이언트(앱 로그인과 별도). 데모에서 쓰지 않으면 체크리스트 §8·smoke 문서에서 생략 가능.
- **IoT**: `--dart-define=MQTT_BROKER_URL=...` (미설정 시 위 “IoT” 절과 동일하게 연결 안 함).

---

## Firebase 배포 시 수동으로 챙길 일

루트 **`firebase.json`**에 Firestore 규칙·인덱스, Storage 규칙, Functions가 연결되어 있다. **배포 명령·dry-run·주의사항**은 [doc/manual-build-inputs.md](./doc/manual-build-inputs.md)(§2-8)와 [doc/firebase-deploy-audit.md](./doc/firebase-deploy-audit.md)를 본다.

---

## Release 빌드 시 참고

- Android/iOS 릴리스 빌드에도 네이버맵 Client ID를 동일하게 주입한다(`--dart-define=...` 또는 xcconfig/gradle).
- Android 릴리스 서명: `key.properties` + keystore(저장소에 포함되지 않음).

---

## 프로젝트 구조(요약)

```
lib/
├── app/           # 앱 셸, 라우터, 스플래시, 테마
├── core/          # 상수, Firebase/MQTT 등 서비스
├── features/      # auth, family, chat, location, files, calendar, todo, cart, expense, album, iot
└── shared/        # 모델, 공용 위젯(MainShell·HomeTab)

functions/
├── index.js                    # FCM 트리거
├── notification_payloads.js
└── notification_payloads.test.js

firestore.rules
firestore.indexes.json
storage.rules
```

---

## 라이선스

Private Project
