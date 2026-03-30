# 동이네 (Dongine)

가족 전용 올인원 공유 허브 앱 - Android / iOS

## 주요 기능

| 기능 | 설명 |
|------|------|
| **그룹 채팅** | 가족 단체 대화방, 봇 커맨드 (`/todo`, `/poll`, `/meal` 등 10개), 특수 카드 UI |
| **위치 공유** | 네이버맵 실시간 위치, 앱 사용 중 30초 간격 갱신, ON/OFF 토글 |
| **파일 클라우드** | 파일 탐색기 UI, 폴더 관리, 업로드/다운로드 |
| **캘린더** | 월간 달력, 일정 유형 (일반/식사/데이트/기념일/병원) |
| **TODO** | 할 일 관리, 카테고리 필터, 리마인더 |
| **플래너** | 식사(메뉴 투표), 나들이(코스/예산), 기념일(D-day) |
| **장보기** | 공용 장보기 목록, 실시간 동기화, 카테고리별 분류 |
| **가계부** | 월별 지출, 카테고리별 차트, 금액 통계 |
| **가족 앨범** | 앨범 생성, 사진 업로드, 타임라인 피드 |
| **IoT** | 스마트 기기 등록/제어, MQTT, 자동화 규칙 |

## 알림 설정

- Android 13 이상은 `POST_NOTIFICATIONS` 권한이 필요합니다.
- iOS는 APNs/Push 설정이 필요하고, 원격 알림 수신을 위해 `remote-notification` 백그라운드 모드를 사용합니다.
- 앱 로그인 후 현재 디바이스의 FCM 토큰을 사용자 문서에 등록하고, 포그라운드 수신 시 인앱 스낵바로 알림을 표시합니다.
- `functions/index.js`는 채팅, 일정, 할 일, 장보기, 가계부 생성 시 가족 구성원에게 FCM을 발송합니다.
- 알림 payload의 기본 `route` 값은 채팅은 `/chat`, 일정/할 일은 `/calendar`, 장보기는 `/cart`, 가계부는 `/expense`입니다.

### Functions 설치 및 배포

```bash
cd functions
npm install
npm run lint
cd ..
firebase deploy --only functions --project=dongine-13214
```

## 기술 스택

| 영역 | 기술 |
|------|------|
| 프레임워크 | Flutter 3.41+ (Dart 3.11+) |
| 상태관리 | Riverpod |
| 라우팅 | GoRouter |
| 백엔드 | Firebase (Auth, Firestore, Storage, FCM, Cloud Functions) |
| 지도 | 네이버맵 (`flutter_naver_map`) |
| 위치 | Geolocator |
| 캘린더 | TableCalendar |
| IoT | MQTT (`mqtt_client`) |

## 사전 준비

1. **Flutter SDK** 3.41 이상
2. **Firebase 프로젝트** 생성 및 설정 완료
3. **Naver Cloud Platform** 계정 + Maps API Client ID
4. **Android Studio** 또는 **Xcode** (빌드용)

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

## 위치 공유 정책

- 위치 공유는 **포그라운드 전용**입니다.
- 앱이 화면에 보이는 동안에만 약 30초 간격으로 현재 위치를 갱신합니다.
- 앱이 백그라운드로 내려가면 위치 갱신을 중단합니다.
- Android는 `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`만 사용하고, 백그라운드 위치 권한은 요청하지 않습니다.
- iOS는 `NSLocationWhenInUseUsageDescription`만 사용합니다.

### MQTT 브로커 (IoT)

IoT 기능 사용 시:
```bash
flutter run --dart-define=MQTT_BROKER_URL=브로커주소
```
또는 `lib/core/constants/app_constants.dart`에서 직접 설정.

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
│   ├── auth/                 # 인증 (로그인/회원가입)
│   ├── family/               # 가족 그룹 관리/초대/전환
│   ├── chat/                 # 채팅 + 봇 커맨드
│   ├── location/             # 네이버맵 위치 공유
│   ├── files/                # 파일 탐색기
│   ├── calendar/             # 캘린더 + 플래너 + Google Calendar
│   ├── todo/                 # TODO 리스트
│   ├── cart/                 # 장보기
│   ├── expense/              # 가계부
│   ├── album/                # 가족 앨범
│   └── iot/                  # IoT (MQTT + 자동화)
└── shared/
    ├── models/               # 공유 데이터 모델
    ├── providers/            # 공유 Provider
    └── widgets/              # 공용 위젯 (MainShell, HomeTab)

functions/
└── index.js                  # Firestore 트리거 기반 FCM 발송
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
- 보안 규칙 파일: `firestore.rules`, `storage.rules`

## 라이선스

Private Project
