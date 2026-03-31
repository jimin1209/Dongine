# 수동 빌드 입력 항목 정리

이 문서는 **코드만 받아서는 자동으로 채워지지 않는 값**과, 빌드/배포 전에 **사람이 직접 준비해야 하는 항목**만 따로 모아둔 문서입니다.

- 데모 문서 **전체 순서**는 [README.md § 시제품 데모 준비](../README.md#시제품-데모-준비--문서-진입-경로)를 본다.
- 빠른 체크리스트가 필요하면: [release-checklist.md](./release-checklist.md)
- Functions 배포 절차가 필요하면: [deploy-functions.md](./deploy-functions.md)
- 데모 직전 smoke: [demo-smoke-push-map-calendar.md](./demo-smoke-push-map-calendar.md)

## 1. 꼭 직접 넣어야 하는 항목

| 항목 | 어디에 넣는지 | 언제 필요한지 | 비고 |
|------|---------------|---------------|------|
| Firebase Android 설정 파일 | `android/app/google-services.json` | Android 빌드/실행 | `.gitignore` 대상 |
| Firebase iOS 설정 파일 | `ios/Runner/GoogleService-Info.plist` | iOS 빌드/실행 | `.gitignore` 대상 |
| FlutterFire 설정 파일 | `lib/firebase_options.dart` | Flutter 앱 실행 전체 | 보통 `flutterfire configure`로 생성 |
| 네이버맵 Client ID (Android) | `android/gradle.properties`의 `NAVER_MAP_CLIENT_ID` | Android 지도 기능 | 현재 placeholder 상태 |
| 네이버맵 Client ID (iOS Debug) | `ios/Flutter/Debug.xcconfig`의 `NAVER_MAP_CLIENT_ID` | iOS Debug 지도 기능 | 현재 placeholder 상태 |
| 네이버맵 Client ID (iOS Release) | `ios/Flutter/Release.xcconfig`의 `NAVER_MAP_CLIENT_ID` | iOS Release 지도 기능 | 현재 placeholder 상태 |
| 네이버맵 Dart define | `--dart-define=NAVER_MAP_CLIENT_ID=...` | 앱 내부 `AppConstants.naverMapClientId` 사용 시 | native 설정과 별도로 맞추는 쪽이 안전 |
| MQTT 브로커 주소 | `--dart-define=MQTT_BROKER_URL=...` | IoT 데모/운영 시 | 없으면 IoT 화면이 “미설정”으로 동작 |
| MQTT 브로커 포트 | `--dart-define=MQTT_BROKER_PORT=...` | IoT 데모/운영 시 | 기본값 `1883` |
| Android release signing | `android/key.properties` + keystore 파일 | Android release/AAB 생성 | 현재 코드는 debug signing 상태 |
| iOS 서명/배포 자격 | Apple Developer / Xcode Signing 설정 | iOS 기기 배포 / TestFlight | 코드 저장소 안에서 해결되지 않음 |
| APNs 키 | Firebase Console > Cloud Messaging | iOS 푸시 수신 | Apple Developer에서 직접 발급 |
| Google Calendar OAuth 설정 | Google Cloud Console(동일 Firebase 프로젝트 권장) | 캘린더 연동 | [§2-7](#google-calendar-oauth) 준비 순서: API·동의 화면 → Android(SHA·패키지명) → iOS(번들 ID) |
| Firebase 배포 | Firebase CLI / Console | rules, indexes, storage, functions 반영 | 코드만 수정해도 서버엔 자동 반영되지 않음 |

## 2. 항목별 상세

### 2-1. Firebase 설정 파일

이 저장소에는 아래 파일들이 보통 포함되지 않습니다.

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

준비 방법:

```bash
# 프로젝트 루트(이 저장소의 최상위)에서 실행
flutterfire configure --project=dongine-13214
```

확인 명령:

```bash
test -f android/app/google-services.json && echo "OK: android" || echo "MISSING: android/app/google-services.json"
test -f ios/Runner/GoogleService-Info.plist && echo "OK: ios" || echo "MISSING: ios/Runner/GoogleService-Info.plist"
test -f lib/firebase_options.dart && echo "OK: flutterfire" || echo "MISSING: lib/firebase_options.dart"
```

### 2-2. 네이버맵 Client ID

현재 저장소에는 아래 3곳이 placeholder 상태입니다.

- `android/gradle.properties`
- `ios/Flutter/Debug.xcconfig`
- `ios/Flutter/Release.xcconfig`

직접 넣어야 하는 값:

```text
NAVER_MAP_CLIENT_ID=실제_발급받은_Client_ID
```

추가로 앱 내부 Dart 쪽에서도 `AppConstants.naverMapClientId`를 읽기 때문에, 실행 시 아래 값도 같이 맞추는 쪽이 안전합니다.

```bash
flutter run --dart-define=NAVER_MAP_CLIENT_ID=실제_발급받은_Client_ID
```

확인 명령:

```bash
grep -q 'YOUR_NAVER_MAP_CLIENT_ID' android/gradle.properties && echo "MISSING: Android 네이버맵 키" || echo "OK: Android 네이버맵 키"
grep -q 'YOUR_NAVER_MAP_CLIENT_ID' ios/Flutter/Debug.xcconfig && echo "MISSING: iOS Debug 네이버맵 키" || echo "OK: iOS Debug 네이버맵 키"
grep -q 'YOUR_NAVER_MAP_CLIENT_ID' ios/Flutter/Release.xcconfig && echo "MISSING: iOS Release 네이버맵 키" || echo "OK: iOS Release 네이버맵 키"
```

참고:

- xcconfig 파일 주석에는 `Local.xcconfig` 오버라이드를 언급하지만, 현재 저장소에는 해당 include 구조가 기본으로 연결되어 있지 않습니다.
- 가장 단순한 방법은 `Debug.xcconfig`, `Release.xcconfig`의 placeholder를 실제 값으로 교체하는 것입니다.

### 2-3. MQTT 브로커 값

IoT 기능은 코드만으로는 연결되지 않습니다.

필요한 값:

```bash
--dart-define=MQTT_BROKER_URL=tcp://브로커주소
--dart-define=MQTT_BROKER_PORT=1883
```

예시:

```bash
flutter run \
  --dart-define=MQTT_BROKER_URL=tcp://192.168.0.10 \
  --dart-define=MQTT_BROKER_PORT=1883
```

미설정 시 동작:

- 앱은 MQTT 연결을 시도하지 않습니다.
- IoT 화면에는 “브로커 미설정” 배너가 보입니다.

### 2-4. Android release signing

현재 `android/app/build.gradle.kts`는 release 빌드에서도 debug signing을 쓰도록 되어 있습니다.

직접 준비해야 하는 것:

- release keystore 파일
- `android/key.properties`
- `build.gradle.kts`의 release signing 설정 교체

예시 `android/key.properties`:

```properties
storePassword=실제비밀번호
keyPassword=실제비밀번호
keyAlias=release
storeFile=/절대경로/your-release-key.jks
```

주의:

- keystore와 `key.properties`는 저장소에 커밋하지 않는 것이 안전합니다.
- 현재 코드는 release signing TODO 상태이므로, 스토어 제출 전 수동 교체가 필요합니다.

### 2-5. iOS 서명 / TestFlight / 배포 자격

iOS는 코드만으로 끝나지 않고, 아래 항목을 Apple Developer / Xcode에서 직접 맞춰야 합니다.

- Team 선택
- Bundle Identifier 일치 확인
- Signing Certificate / Provisioning Profile
- Device 등록 또는 TestFlight 배포 설정

즉, `flutter build ios`가 된다고 바로 배포 가능한 상태는 아닙니다.

### 2-6. APNs / iOS 푸시

iOS 푸시를 실제로 받으려면 Apple과 Firebase 콘솔 설정이 추가로 필요합니다.

직접 해야 하는 것:

1. Apple Developer 포털에서 APNs 인증 키 발급
2. Firebase Console > 프로젝트 설정 > Cloud Messaging에 업로드
3. iOS 앱 식별자와 푸시 권한 확인

코드 쪽 준비만 되어 있고, 콘솔 등록 전에는 iOS 푸시가 동작하지 않을 수 있습니다.

### 2-7. Google Calendar OAuth

<a id="google-calendar-oauth"></a>

Google Calendar 연동은 `google_sign_in`으로 **Calendar API**만 요청하며, 앱의 Firebase 이메일 로그인과는 별개입니다. `GoogleCalendarService`는 `GoogleSignIn(scopes: [calendarScope])`만 사용하고, **웹 클라이언트 ID(`serverClientId`)는 코드에 넣지 않습니다.** 플랫폼별 **OAuth 2.0 클라이언트**가 Cloud Console에 맞게 있어야 합니다.

**앱 식별자(콘솔 입력값과 반드시 일치)**

| 플랫폼 | 항목 | 값(현재 저장소 기준) |
|--------|------|----------------------|
| Android | 패키지 이름 | `com.dongine.dongine` (`android/app/build.gradle.kts`의 `applicationId`) |
| iOS | 번들 ID | `com.dongine.dongine` (Xcode **Signing & Capabilities** / `PRODUCT_BUNDLE_IDENTIFIER`) |

**준비 순서(권장)**

1. **Google Cloud 프로젝트**를 연다. Firebase와 **동일 프로젝트**를 쓰는 것이 관리에 유리하다(`firebase.json`의 `projectId`: `dongine-13214`).
2. **[Google Calendar API](https://developers.google.com/workspace/calendar/api/guides/overview)** 를 해당 프로젝트에서 **사용 설정**한다.
3. **OAuth 동의 화면**을 구성한다. 앱이 **테스트** 상태이면 동의 화면에 **테스트 사용자**로 시연 계정을 넣는다([동의 화면 설정](https://console.cloud.google.com/apis/credentials/consent)).
4. **Android용 OAuth 클라이언트**를 만든다: 유형 **Android**, 패키지 이름 `com.dongine.dongine`, **앱 서명 인증서 지문**에 디버그·릴리스에 맞는 **SHA-1**(필요 시 SHA-256)을 등록한다. 지문은 `cd android && ./gradlew signingReport` 또는 `keytool`로 확인한다.
5. **iOS용 OAuth 클라이언트**를 만든다: 유형 **iOS**, **번들 ID** `com.dongine.dongine`.
6. 저장 후 **몇 분** 반영 지연이 있을 수 있으므로, **캘린더** 탭 앱바 **설정**으로 연 **Google Calendar 설정**에서 **연결·동기화**를 다시 시도한다.

참고: [Google Cloud Console — 사용자 인증 정보](https://console.cloud.google.com/apis/credentials)

이 설정이 빠지거나 SHA·번들 ID가 빌드와 다르면 계정 선택은 떠도 **토큰·Calendar API 호출이 실패**할 수 있습니다.

### 2-8. Firebase rules / indexes / functions 배포

저장소 파일을 바꿔도 Firebase 서버에는 자동 반영되지 않습니다.

직접 해야 하는 명령 예시:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions --project=dongine-13214
```

또는 개별 배포:

```bash
firebase deploy --only firestore:rules --project=dongine-13214
firebase deploy --only firestore:indexes --project=dongine-13214
firebase deploy --only storage --project=dongine-13214
firebase deploy --only functions --project=dongine-13214
```

추가로 필요한 것:

- `firebase login`
- 프로젝트 권한
- Functions 배포 시 Blaze 플랜 / 권한 / 리전 요건

## 3. 빌드 전에 최소 확인하면 좋은 순서

### Android 디버그 빌드 전

1. `google-services.json` 존재 확인
2. `lib/firebase_options.dart` 존재 확인
3. `NAVER_MAP_CLIENT_ID` 실제 값 입력 확인
4. 필요하면 `MQTT_BROKER_URL` 준비
5. Google Calendar를 시연할 때만: 디버그 키 **SHA-1**이 Cloud Console **Android OAuth 클라이언트**에 등록됐는지 확인([§2-7](#google-calendar-oauth))
6. `flutter run` 또는 `flutter build apk`

예시:

```bash
# 프로젝트 루트에서
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter run --dart-define=NAVER_MAP_CLIENT_ID=실제키
```

### Android release 빌드 전

1. 위 디버그 항목 전부 확인
2. `android/key.properties` 준비
3. keystore 준비
4. `build.gradle.kts` release signing 교체
5. `flutter build appbundle` 또는 `flutter build apk --release`

### iOS 빌드 전

1. `GoogleService-Info.plist` 존재 확인
2. `Debug.xcconfig` / `Release.xcconfig`의 `NAVER_MAP_CLIENT_ID` 확인
3. APNs 키가 Firebase에 등록됐는지 확인
4. Apple Signing / Provisioning 설정 확인
5. 필요하면 `flutter run --dart-define=NAVER_MAP_CLIENT_ID=실제키`
6. Google Calendar를 시연할 때만: Cloud Console **iOS OAuth 클라이언트** 번들 ID가 `com.dongine.dongine`인지 확인([§2-7](#google-calendar-oauth))

## 4. 한 번에 점검하는 빠른 명령

아래 항목들을 자동으로 점검하는 **preflight 스크립트**가 `tool/preflight.sh`에 준비되어 있습니다.

```bash
# 프로젝트 루트(pubspec.yaml이 있는 곳). 클론 경로가 다르면 아래 한 줄로 통일해도 됨.
cd "$(git rev-parse --show-toplevel)"
bash tool/preflight.sh
```

**Git으로 루트 찾기**(저장소 안 어느 디렉터리에 있든 동일):

```bash
cd "$(git rev-parse --show-toplevel)"
bash tool/preflight.sh
```

**분석·테스트 전에 게이트로 쓰기**:

```bash
cd "$(git rev-parse --show-toplevel)"
bash tool/preflight.sh || exit 1
flutter pub get
flutter analyze
flutter test
```

스크립트는 **읽기 전용**이며 어떤 파일도 수정하지 않습니다. 점검 항목:

- Firebase 설정 파일 3종 존재 여부 (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `lib/firebase_options.dart`)
- 네이버맵 Client ID placeholder 여부 (`YOUR_NAVER_MAP_CLIENT_ID` 문자열 검사): Android `gradle.properties`, iOS `Flutter/Debug.xcconfig`, `Flutter/Release.xcconfig`
- `android/key.properties` 존재 여부 (release 빌드용) — **없으면 경고(⚠)만** 나가며, 이 경우만으로는 종료 코드가 **0**일 수 있음

**종료 코드**: 위에서 **실패(✗)** 가 1건이라도 있으면 **1**. 경고(⚠)만 있으면 **0**. CI나 로컬 빌드 스크립트에서 `bash tool/preflight.sh || exit 1` 형태로 쓰면 된다.

<details>
<summary>수동으로 개별 확인하기</summary>

```bash
# 프로젝트 루트에서
test -f android/app/google-services.json && echo "✓ android google-services.json" || echo "✗ android google-services.json"
test -f ios/Runner/GoogleService-Info.plist && echo "✓ ios GoogleService-Info.plist" || echo "✗ ios GoogleService-Info.plist"
test -f lib/firebase_options.dart && echo "✓ firebase_options.dart" || echo "✗ firebase_options.dart"

grep -q 'YOUR_NAVER_MAP_CLIENT_ID' android/gradle.properties && echo "✗ Android 네이버맵 키 미설정" || echo "✓ Android 네이버맵 키 설정"
grep -q 'YOUR_NAVER_MAP_CLIENT_ID' ios/Flutter/Debug.xcconfig && echo "✗ iOS Debug 네이버맵 키 미설정" || echo "✓ iOS Debug 네이버맵 키 설정"
grep -q 'YOUR_NAVER_MAP_CLIENT_ID' ios/Flutter/Release.xcconfig && echo "✗ iOS Release 네이버맵 키 미설정" || echo "✓ iOS Release 네이버맵 키 설정"

test -f android/key.properties && echo "✓ android/key.properties" || echo "✗ android/key.properties"
```

</details>

## 5. 요약

빌드 직전에 사람이 직접 챙겨야 하는 핵심은 아래와 같습니다.

1. Firebase 설정 파일
2. 네이버맵 Client ID
3. MQTT 브로커 값
4. Android release signing
5. iOS APNs / 서명
6. Firebase 배포
7. (선택) Google Calendar: 위 [**2-7**](#google-calendar-oauth) 순서대로 OAuth 클라이언트·Calendar API

위 항목들은 현재 코드 저장소만으로 자동 해결되지 않습니다.
