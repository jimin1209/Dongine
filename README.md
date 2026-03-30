# 동이네 (Dongine)

가족 전용 올인원 공유 허브 앱 — Android / iOS

## 현재 구현 상태

| 분야 | 상태 | 비고 |
|------|------|------|
| 인증 / 가족 관리 | 구현 완료 | 초대 만료·재발급, 가족 설정 고도화 |
| 채팅 | 구현 완료 | 봇 커맨드 10종, 메시지 편집/삭제, 읽음 상태 |
| 위치 공유 | 구현 완료 | 포그라운드 전용, 최신성 표시, 수동 새로고침 |
| 파일 클라우드 | 구현 완료 | 검색, 정렬, 유형 필터, 그리드/리스트 뷰 |
| 캘린더 / TODO / 플래너 | 구현 완료 | Google Calendar 양방향 동기화, TODO 전용 화면 |
| 장보기 | 구현 완료 | 빈도 기반 추천, 중복 방지, 항목 편집 |
| 가계부 | 구현 완료 | 월별 통계, 카테고리 필터, 지출 편집 |
| 앨범 | 구현 완료 | 앨범 생성, 사진 타임라인, 커버 사진 |
| IoT | 구현 완료 | MQTT 기기 등록/제어, 자동화 규칙 |
| 알림 (FCM) | 구현 완료 | 5개 이벤트 트리거, 인앱 스낵바, 클릭 라우팅 |
| 홈 대시보드 | 구현 완료 | 요약 카드 4종, 빠른 접근, 오늘의 TODO |
| CI | 구현 완료 | Functions lint + test (GitHub Actions) |

---

## 핵심 기능

### 인증 / 가족

- Firebase Auth 기반 이메일/비밀번호 + Google 로그인
- 온보딩 화면에서 주요 기능 소개 → 로그인 → 가족 생성/참가 순서로 안내
- 6자리 초대 코드로 가족 참가, **초대 코드 7일 만료 + 관리자 재발급** 지원
- 가족 설정 화면: 구성원 목록·역할 표시, 초대 코드 복사, 만료 시간 표시
- 관리자/멤버 역할 구분 (초대 관리, 구성원 삭제, 리소스 삭제 권한)
- 복수 가족 소속 및 가족 전환 지원
- 가족 탈퇴 기능
- 한국어 에러 메시지

### 채팅

- Firestore 기반 가족 단체 대화방
- 메시지 편집 / 삭제 / 읽음·안읽음 상태 추적
- 봇 커맨드 10종 (`/todo`, `/remind`, `/location`, `/calendar`, `/poll`, `/meal`, `/date`, `/cart`, `/expense`, `/members`)
- 커맨드 입력 시 드롭다운 자동 완성
- 특수 카드 UI (투표, 위치, 일정, 식사 투표, 리마인더 등)

### 위치 공유

> **포그라운드 전용** — 앱이 화면에 보이는 동안에만 약 30초 간격으로 위치를 갱신합니다.
> 앱이 백그라운드로 내려가면 갱신을 중단합니다.
> 백그라운드 위치 권한은 요청하지 않습니다.

- 네이버맵에 가족 구성원 실시간 위치 표시
- **위치 최신성 표시**: Fresh (< 2분) / Recent (2~10분) / Stale (> 10분)
- 구성원별 배터리·정확도·주소·마지막 갱신 시각 표시
- 수동 새로고침 버튼
- ON/OFF 토글로 공유 제어
- Android: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`만 사용
- iOS: `NSLocationWhenInUseUsageDescription`만 사용

### 파일 클라우드

- 파일 탐색기 UI (폴더 계층 탐색, 브레드크럼)
- Firebase Storage 업로드/다운로드 (진행률 표시)
- **파일 검색** (이름 기반 실시간 검색)
- **정렬** (이름, 날짜, 크기 등)
- **유형 필터** (문서, 이미지, 영상 등)
- 그리드 / 리스트 뷰 전환
- 100MB 업로드 제한, 업로더 또는 관리자만 삭제 가능

### 캘린더 / TODO / 플래너

**캘린더**
- 월간 달력 뷰 (TableCalendar)
- 일정 유형 5가지: 일반, 식사, 나들이, 기념일, 병원
- 종일/시간 지정 일정, 카테고리 필터링

**Google Calendar 동기화**
- Google OAuth 연동 후 양방향 동기화
- 가져오기(Import): Google Calendar → 가족 캘린더
- 내보내기(Export): 가족 일정 → Google Calendar
- 중복 방지 (externalUpdatedAt 추적), 삭제 동기화
- Google 가져오기 일정은 FCM 알림에서 제외 (스팸 방지)

**TODO**
- 전용 TODO 화면 (CRUD)
- 가족 구성원 할당, 마감일, 완료 상태 토글
- 채팅 `/todo` 커맨드로도 생성 가능
- 홈 대시보드에 미완료 TODO 수 표시

**플래너**
- 식사 플래너: 메뉴 투표
- 나들이 플래너: 코스, 예산 계획
- 기념일: D-day 카운트

### 장보기

- 공용 장보기 목록, 실시간 동기화
- **빈도 기반 추천**: 자주 추가하는 품목을 드롭다운으로 빠르게 재추가
- **중복 방지**: 같은 품목이 미체크 상태로 존재하면 수량을 합산
- 항목 체크/해제, **편집** (이름·수량·카테고리), 삭제
- 카테고리별 분류
- 홈 대시보드에 미체크 항목 수 표시

### 가계부

- 지출 기록 (제목, 금액, 날짜, 카테고리)
- **월별 합계** (홈 대시보드에 이번 달 지출 표시, 원화 포맷)
- 카테고리별 차트
- **지출 편집 / 필터링 / 삭제**
- 채팅 `/expense` 커맨드로도 기록 가능

### 앨범

- 앨범 생성 (커버 사진 설정)
- 사진 업로드, 타임라인 피드
- 사진 삭제 시 커버·카운트 자동 정합
- 생성자 또는 관리자만 앨범 삭제 가능

### IoT

- MQTT 프로토콜 기반 스마트 기기 등록/제어
- 기기 유형 (조명, 스위치, 센서 등), 방 분류
- 자동화 규칙 생성 (트리거 → 액션)
- MQTT 연결 상태 배지 (연결/재연결/오류)
- 기기 탭 + 자동화 탭 2-탭 구성

### 알림 / Cloud Functions

- **FCM 트리거 5종**:

| 이벤트 | 알림 대상 | 라우팅 |
|--------|-----------|--------|
| 채팅 메시지 생성 | 가족 (발신자 제외) | `/chat` |
| 캘린더 일정 생성 | 가족 (생성자 제외, Google 가져오기 제외) | `/calendar` |
| TODO 생성 | 가족 (생성자 제외) | `/calendar` |
| 장보기 항목 추가 | 가족 (추가자 제외) | `/cart` |
| 가계부 기록 | 가족 (기록자 제외) | `/expense` |

- 포그라운드: 인앱 스낵바 표시
- 백그라운드: 클릭 시 해당 화면으로 라우팅
- 멀티 디바이스 FCM 토큰 관리 (로그인/로그아웃 시 자동 등록/해제)
- 유효하지 않은 토큰 자동 정리

### 홈 대시보드

- **요약 카드 4종** (2×2 그리드):
  - 남은 할 일 수 → `/todo`
  - 장보기 남은 항목 수 → `/cart`
  - 이번 달 지출 (원화) → `/expense`
  - 다가오는 일정 수 → `/calendar`
- 빠른 접근 버튼 5종 (장보기, 가계부, 앨범, IoT, Todo)
- 오늘의 TODO 섹션 (상위 5개, 완료 체크 가능)
- 가족 이름, 초대 코드, 가족 전환 UI

---

## 기술 스택

| 영역 | 기술 |
|------|------|
| 프레임워크 | Flutter 3.41+ (Dart 3.11+) |
| 상태관리 | Riverpod |
| 라우팅 | GoRouter |
| 백엔드 | Firebase (Auth, Firestore, Storage, FCM, Cloud Functions) |
| 지도 | 네이버맵 (`flutter_naver_map`) |
| 위치 | Geolocator |
| 캘린더 | TableCalendar, Google Calendar API |
| IoT | MQTT (`mqtt_client`) |
| CI | GitHub Actions (Functions lint + test) |

---

## 사전 준비

1. **Flutter SDK** 3.41 이상
2. **Firebase 프로젝트** 생성 및 설정 완료
3. **Naver Cloud Platform** 계정 + Maps API Client ID
4. **Android Studio** 또는 **Xcode** (빌드용)
5. **Node.js 20** (Cloud Functions 개발/CI용)

## 설치 및 실행

```bash
# 1. 클론
git clone https://github.com/jimin1209/Dongine.git
cd Dongine

# 2. 의존성 설치
flutter pub get

# 3. Firebase 설정
# 다른 Firebase 프로젝트를 사용하려면:
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_PROJECT_ID

# 4. 실행
flutter run
```

## 외부 설정 (API 키 등)

모든 외부 키는 코드에 직접 넣지 않고, **빌드 설정 파일**에서 관리합니다.

### 네이버맵 Client ID

NCP 콘솔에서 발급받은 Client ID를 아래 **3곳**에 설정하세요:

| 플랫폼 | 파일 | 설정 방법 |
|--------|------|----------|
| **Android** | `android/gradle.properties` | `NAVER_MAP_CLIENT_ID=실제키` |
| **iOS** | `ios/Flutter/Debug.xcconfig` | `NAVER_MAP_CLIENT_ID=실제키` |
| **iOS** | `ios/Flutter/Release.xcconfig` | `NAVER_MAP_CLIENT_ID=실제키` |

설정 후 자동으로 다음 경로에 반영됩니다:
- Android: `gradle.properties` → `build.gradle.kts` (manifestPlaceholders) → `AndroidManifest.xml`
- iOS: `xcconfig` → `Info.plist` (`$(NAVER_MAP_CLIENT_ID)`)
- Dart: `--dart-define=NAVER_MAP_CLIENT_ID=실제키` 또는 `app_constants.dart`의 `String.fromEnvironment` fallback

**dart-define으로 실행하기** (설정 파일 수정 없이):
```bash
flutter run --dart-define=NAVER_MAP_CLIENT_ID=실제키
```

### Firebase 설정 파일

| 파일 | 위치 | 비고 |
|------|------|------|
| `google-services.json` | `android/app/` | Firebase 콘솔에서 다운로드 |
| `GoogleService-Info.plist` | `ios/Runner/` | Firebase 콘솔에서 다운로드 |
| `firebase_options.dart` | `lib/` | `flutterfire configure`로 자동 생성 |

이 파일들은 `.gitignore`에 포함되어 저장소에 올라가지 않습니다.

### MQTT 브로커 (IoT)

IoT 기능 사용 시:
```bash
flutter run --dart-define=MQTT_BROKER_URL=브로커주소
```
또는 `lib/core/constants/app_constants.dart`에서 직접 설정.

---

## Cloud Functions

### 설치 및 배포

```bash
cd functions
npm install
npm run lint
npm test
cd ..
firebase deploy --only functions --project=dongine-13214
```

### CI (GitHub Actions)

`functions/` 하위 파일이 변경되면 PR·push 시 자동으로 lint + test가 실행됩니다.
워크플로: `.github/workflows/functions-ci.yml`

---

## Release 빌드

### Android

1. **서명 키 생성**:
   ```bash
   keytool -genkey -v -keystore ~/dongine-release.jks -keyalg RSA -keysize 2048 -validity 10000
   ```

2. **`android/key.properties`** 파일 생성:
   ```properties
   storePassword=비밀번호
   keyPassword=비밀번호
   keyAlias=upload
   storeFile=/path/to/dongine-release.jks
   ```

3. **빌드**:
   ```bash
   flutter build apk --dart-define=NAVER_MAP_CLIENT_ID=실제키
   flutter build appbundle --dart-define=NAVER_MAP_CLIENT_ID=실제키
   ```

### iOS

1. Xcode에서 `Runner.xcworkspace` 열기
2. Signing & Capabilities에서 Apple Developer Team 설정
3. **빌드**:
   ```bash
   flutter build ios --dart-define=NAVER_MAP_CLIENT_ID=실제키
   ```

### Firestore / Functions 배포

```bash
firebase deploy --only firestore:rules,storage,functions --project=dongine-13214
```

---

## 프로젝트 구조

```
lib/
├── main.dart
├── app/
│   ├── app.dart              # MaterialApp 설정
│   ├── router.dart           # GoRouter 라우팅
│   ├── splash_screen.dart    # 세션 게이팅 (자동 라우팅)
│   └── theme.dart            # Material3 테마
├── core/
│   ├── constants/            # 앱 상수, Firestore 경로
│   └── services/             # Firebase, MQTT, EventBus
├── features/
│   ├── auth/                 # 로그인/회원가입, 온보딩
│   ├── family/               # 가족 관리/초대/전환/설정
│   ├── chat/                 # 채팅 + 봇 커맨드 + 카드 UI
│   ├── location/             # 네이버맵 위치 공유 (포그라운드 전용)
│   ├── files/                # 파일 탐색기 (검색/정렬/필터)
│   ├── calendar/             # 캘린더 + 플래너 + Google Calendar 동기화
│   ├── todo/                 # TODO 전용 화면
│   ├── cart/                 # 장보기 (추천/중복 방지)
│   ├── expense/              # 가계부 (편집/필터)
│   ├── album/                # 가족 앨범
│   └── iot/                  # IoT (MQTT + 자동화)
└── shared/
    ├── models/               # 공유 데이터 모델
    ├── providers/            # 공유 Provider
    └── widgets/              # 공용 위젯 (MainShell, HomeTab)

functions/
├── index.js                  # Firestore 트리거 기반 FCM 발송
├── notification_payloads.js  # 알림 페이로드 생성
└── notification_payloads.test.js  # 페이로드 단위 테스트
```

## 채팅 봇 커맨드

채팅창에서 `/`를 입력하면 커맨드 목록이 표시됩니다:

| 커맨드 | 예시 | 동작 |
|--------|------|------|
| `/todo` | `/todo 우유 사오기` | TODO 생성 |
| `/remind` | `/remind 6시 약 먹기` | 리마인더 설정 |
| `/location` | `/location` | 현재 위치 공유 |
| `/calendar` | `/calendar 4/5 가족 외식` | 일정 등록 |
| `/poll` | `/poll 저녁 뭐먹지 피자 초밥 치킨` | 투표 생성 |
| `/meal` | `/meal 저녁` | 식사 플래너 |
| `/date` | `/date 이번 주말` | 나들이 플래너 |
| `/cart` | `/cart 우유` | 장보기 추가 |
| `/expense` | `/expense 외식 45000` | 가계부 기록 |
| `/members` | `/members` | 가족 상태 확인 |

## Firebase 보안 규칙

- Firestore: 가족 구성원만 해당 가족 데이터 접근 가능
- Storage: 가족 구성원만 파일 접근, 100MB 업로드 제한
- 초대 코드 만료 검증 (Firestore rules 레벨)
- 보안 규칙 파일: `firestore.rules`, `storage.rules`

## 라이선스

Private Project
