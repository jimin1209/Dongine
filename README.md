# 동이네 (Dongine)

가족 전용 올인원 공유 허브 앱 - Android / iOS

## 주요 기능

| 기능 | 설명 |
|------|------|
| **그룹 채팅** | 가족 단체 대화방, 봇 커맨드 (`/todo`, `/poll`, `/meal` 등 10개), 특수 카드 UI |
| **위치 공유** | 네이버맵 실시간 위치, 30초 간격 자동 갱신, ON/OFF 토글 |
| **파일 클라우드** | 파일 탐색기 UI, 폴더 관리, 업로드/다운로드 |
| **캘린더** | 월간 달력, 일정 유형 (일반/식사/데이트/기념일/병원) |
| **TODO** | 할 일 관리, 카테고리 필터, 리마인더 |
| **플래너** | 식사(메뉴 투표), 나들이(코스/예산), 기념일(D-day) |
| **장보기** | 공용 장보기 목록, 실시간 동기화, 카테고리별 분류 |
| **가계부** | 월별 지출, 카테고리별 차트, 금액 통계 |
| **가족 앨범** | 앨범 생성, 사진 업로드, 타임라인 피드 |
| **IoT** | (예정) 스마트 기기 연동 |

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
# firebase_options.dart가 이미 포함되어 있음
# 다른 Firebase 프로젝트를 사용하려면:
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_PROJECT_ID

# 4. 네이버맵 Client ID 설정
# lib/core/constants/app_constants.dart 에서:
# naverMapClientId = 'YOUR_NAVER_MAP_CLIENT_ID' 를 실제 키로 교체

# 5. 실행
flutter run
```

## Android 추가 설정

`android/app/src/main/AndroidManifest.xml`에 권한 추가 (위치 공유용):

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```

네이버맵 Client ID를 `android/app/src/main/AndroidManifest.xml`의 `<application>` 안에 추가:

```xml
<meta-data
    android:name="com.naver.maps.map.CLIENT_ID"
    android:value="YOUR_NAVER_MAP_CLIENT_ID" />
```

## iOS 추가 설정

`ios/Runner/Info.plist`에 추가:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>가족 위치 공유를 위해 위치 권한이 필요합니다.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>백그라운드 위치 공유를 위해 권한이 필요합니다.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>사진 업로드를 위해 갤러리 접근이 필요합니다.</string>
<key>NSCameraUsageDescription</key>
<string>사진 촬영을 위해 카메라 접근이 필요합니다.</string>
<key>NMFClientId</key>
<string>YOUR_NAVER_MAP_CLIENT_ID</string>
```

## 프로젝트 구조

```
lib/
├── main.dart
├── app/
│   ├── app.dart              # MaterialApp 설정
│   ├── router.dart           # GoRouter 라우팅
│   └── theme.dart            # Material3 테마
├── core/
│   ├── constants/            # 앱 상수, Firestore 경로
│   └── services/             # Firebase 서비스
├── features/
│   ├── auth/                 # 인증 (로그인/회원가입)
│   ├── family/               # 가족 그룹 관리/초대
│   ├── chat/                 # 채팅 + 봇 커맨드
│   ├── location/             # 네이버맵 위치 공유
│   ├── files/                # 파일 탐색기
│   ├── calendar/             # 캘린더 + 플래너
│   ├── todo/                 # TODO 리스트
│   ├── cart/                 # 장보기
│   ├── expense/              # 가계부
│   ├── album/                # 가족 앨범
│   └── iot/                  # IoT (예정)
└── shared/
    ├── models/               # 공유 데이터 모델
    ├── providers/            # 공유 Provider
    └── widgets/              # 공용 위젯
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
