# 수동 빌드 입력 항목 정리

이 문서는 **코드만으로는 채워지지 않는 값**과 빌드·배포 전 **사람이 준비하는 항목**만 모은 것이다.

**데모·문서 권장 순서**(README·[release-checklist.md](./release-checklist.md)·[prototype-remaining-work.md](./prototype-remaining-work.md)와 동일):  
1 이 문서(수동 입력값) → 2 `bash tool/preflight.sh`([§4](#preflight-quick-command)) → 3 [firebase-deploy-audit.md](./firebase-deploy-audit.md) → 4 [release-checklist.md](./release-checklist.md)(§0~§6) → 5 (선택) [deploy-functions.md](./deploy-functions.md) → 6 [real-device-validation-matrix.md](./real-device-validation-matrix.md) → 7 [demo-smoke-push-map-calendar.md](./demo-smoke-push-map-calendar.md) → 8 Debug·설정에서 데모 초기화·채우기 → 9 [demo-walkthrough.md](./demo-walkthrough.md).  
한눈 표: [README — 시제품 데모 준비](../README.md#시제품-데모-준비--문서-진입-경로). **완료 vs 남음 허브**: [README — 데모 vs 배포](../README.md#readme-demo-vs-deploy-status).

<a id="demo-vs-deploy-conditions"></a>

## 데모 가능 조건 vs 배포 가능 조건

같은 저장소라도 **시제품 데모**와 **스토어·운영 배포**가 요구하는 완성도가 다르다. 아래는 조건을 **나란히** 두어 구분한다.

| 영역 | 데모 가능(시제품 시연) | 실제 배포·운영 가능 |
|------|------------------------|---------------------|
| **목적** | 당일 시연·smoke·3~5분 워크스루가 성립 | 스토어 제출·사용자 배포·사고 대응까지 고려 |
| **클라이언트 빌드** | Debug 실기기·에뮬로 대부분 충분 | Android release/AAB·iOS 서명·(TestFlight 등) 배포 산출물 |
| **Firebase 설정 파일** | 3종 존재·프로젝트와 일치 | 동일(필수) |
| **서버 반영** | 규칙·인덱스·Storage·Functions가 **실제로** 쓰는 프로젝트에 배포되어 동작 | 동일 + **운영 전** 규칙·비용·백업 정책 등 최종 검토 |
| **푸시(FCM)** | Android는 상대적으로 수월; iOS는 **APNs 등록·capability**까지 필요할 때만 “데모에서 푸시” 완결 | 양 플랫폼 **프로덕션** 알림 경로·토큰 정리·장애 시나리오 |
| **네이버맵** | Client ID 실값·지도 렌더 확인 | 동일 + 정책·키 관리(회전 등) |
| **Google Calendar** | 시연 안 하면 불필요([release-checklist §8](./release-checklist.md#8-optional-out-of-demo-scope)) | 기능을 스토어·사용자에게 공개할 때 OAuth·동의 화면·스토어 설명과 정합 |
| **IoT(MQTT)** | 브로커 없이 “미설정” UI로 데모 가능 | 실사용 시 `--dart-define`·브로커·기기 전제 |
| **Android 릴리스 서명** | 데모 APK는 debug로도 가능 | 스토어·내부 배포용 keystore·`key.properties`·빌드 설정([§2-4](#android-release-signing)) |
| **iOS 서명·배포** | debug/`--no-codesign` 빌드 검증 수준 가능 | Team·Provisioning·푸시·배포 채널([§2-5](#ios-signing-deploy)) |
| **관측·분석** | 없어도 데모 성립 | Crashlytics/Analytics 등 운영 시 권장([release-checklist §8](./release-checklist.md#8-optional-out-of-demo-scope)) |

절차 체크는 [release-checklist.md](./release-checklist.md) §0~§6(통합 게이트), 배포 쪽 추가는 같은 문서 §8과 위 표의 “배포” 열을 함께 본다.

<a id="preflight-human-checklist"></a>

## Preflight 실전: 실행 전·후에 사람이 확인할 것

스크립트는 [§4](#preflight-quick-command)에서 말한 대로 **파일 존재·네이버맵 placeholder·`key.properties` 유무**만 본다. 아래는 그 전후에 사람이 빠르게 거르는 **상황 예시**다.

### 실행 전에 할 일 (예시)

| 상황 | 사람이 먼저 확인할 것 |
|------|------------------------|
| 저장소를 막 클론한 PC | 이 머신에 `google-services.json` / `GoogleService-Info.plist` / `firebase_options.dart`가 아예 없을 수 있다. 팀이 쓰는 **Firebase 프로젝트 ID**로 `flutterfire configure` 할지, 보안 정책상 **기존 파일을 안전 경로에서 복사**할지 정한다. |
| 데모·QA 전날 | 네이버 클라우드 쪽에 **패키지명·번들 ID**가 등록돼 있는지, 발급한 Client ID가 **플레이스홀더만 바꾼 값과 동일**한지(콘솔 미등록이면 preflight는 통과해도 지도가 실패할 수 있음). |
| `flutter build` 릴리스 직전 | preflight는 `key.properties` **없음을 경고만** 한다. **릴리스를 돌릴 사람**은 keystore 경로·비밀번호가 이 환경에 있는지 별도로 본다([§2-4](#android-release-signing)). |
| iOS 푸시를 시연에 넣을 때 | 스크립트는 APNs를 검사하지 않는다. **Firebase Console → Cloud Messaging → APNs 인증 키** 등록 여부를 미리 눈으로 확인([§2-6](#apns-auth-key)). |

### 실행 후 출력 해석 (예시)

| 결과 | 의미 | 다음 액션 |
|------|------|-----------|
| **✗가 1건이라도** | 종료 코드 **1**. 빌드 파이프라인에서도 여기서 멈추는 것이 안전하다. | 실패로 찍힌 **파일 경로**를 열고 아래 [§2](#manual-item-details) 해당 절과 대조한다. |
| **✓만** | 필수 파일·네이버맵 placeholder는 통과. | [release-checklist.md](./release-checklist.md) **§1~**으로 넘어가 Firebase 콘솔·규칙 배포·FCM·실기기를 진행한다. preflight는 **서버 배포·APNs·Xcode 서명 적합성**을 검사하지 않는다. |
| **⚠(예: `key.properties` 없음)** | 종료 코드는 **0**일 수 있다. | **Debug 데모**만 할 때는 진행해도 되는 경우가 많다. **release/AAB**를 만들 거면 [§2-4](#android-release-signing)를 채운 뒤 다시 돌린다. |

통합 순서(표)는 [release-checklist.md §0~§6](./release-checklist.md)과 같다.

<a id="common-config-failure-symptoms"></a>

## 자주 빠지는 설정: 실패 증상과 확인 위치

같은 증상이면 아래 **확인 위치** 열부터 열어보면 시간을 덜 쓴다. 상세 절차는 각 §2 링크로 이어진다.

| 영역 | 흔한 증상 | 확인 위치 |
|------|-----------|-----------|
| **Firebase 설정 파일** | 앱 기동 직후 Firebase 초기화 실패, Android Gradle 단계에서 `google-services` 관련 오류, iOS 빌드가 plist 누락으로 중단 | [§2-1](#firebase-config-files) — 세 파일 경로·`flutterfire configure` 프로젝트. [firebase-deploy-audit.md](./firebase-deploy-audit.md)는 **서버 측** 규칙·인덱스다. |
| **Firebase 프로젝트 착오** | 로그인은 되는데 특정 환경에서만 데이터가 비어 있거나 권한 오류가 난다(다른 키를 넣은 빌드 산출물) | [§2-1](#firebase-config-files) — `firebase_options.dart`·plist/json의 **프로젝트 ID**가 Console과 같은지. |
| **네이버맵 Client ID** | 지도 탭이 비거나 인증 실패 로그, preflight에서 **placeholder ✗** | [§2-2](#naver-map-client-id) — `gradle.properties`, `Debug.xcconfig`/`Release.xcconfig`, (선택) `--dart-define`. 네이버 클라우드 콘솔의 **앱 패키지/번들 등록**과 짝이 맞는지. |
| **Android 릴리스 서명** | `flutter build appbundle` / release 단계에서 서명·keystore 오류, Play Console 업로드 시 서명 불일치 | [§2-4](#android-release-signing) — `key.properties`, keystore 경로, `build.gradle.kts` 릴리스 설정. preflight는 파일 **유무만** 경고한다. |
| **iOS 서명·프로비저닝** | Xcode **Signing & Capabilities** 경고, `flutter build ios`에서 provisioning/certificate 오류, 기기 설치 실패 | [§2-5](#ios-signing-deploy) — Team, Bundle ID `com.dongine.dongine`, 프로파일. |
| **APNs / iOS 푸시** | **Android는** 채팅 알림이 오는데 **iOS만** 안 온다, 또는 기기 토큰은 있는데 원격 수신 없음 | [§2-6](#apns-auth-key) — Apple **APNs 인증 키**를 Firebase **Cloud Messaging**에 올렸는지, Xcode **Push Notifications**·`remote-notification` 백그라운드([release-checklist §2](./release-checklist.md#release-checklist-fcm-apns)). |

## 1. 꼭 직접 넣어야 하는 항목

<a id="manual-build-section-1-items"></a>

| 항목 | 어디에 넣는지 | 언제 필요한지 | 비고 |
|------|---------------|---------------|------|
| Firebase Android 설정 파일 | `android/app/google-services.json` | Android 빌드/실행 | `.gitignore` 대상 |
| Firebase iOS 설정 파일 | `ios/Runner/GoogleService-Info.plist` | iOS 빌드/실행 | `.gitignore` 대상 |
| FlutterFire 생성 파일 | `lib/firebase_options.dart` | Flutter 앱 실행 전체(Android·iOS 공통) | 보통 `flutterfire configure`로 생성 |
| 네이버맵 Client ID (Android) | `android/gradle.properties`의 `NAVER_MAP_CLIENT_ID` | Android 지도 기능 | 현재 placeholder 상태 |
| 네이버맵 Client ID (iOS Debug) | `ios/Flutter/Debug.xcconfig`의 `NAVER_MAP_CLIENT_ID` | iOS Debug 지도 기능 | 현재 placeholder 상태 |
| 네이버맵 Client ID (iOS Release) | `ios/Flutter/Release.xcconfig`의 `NAVER_MAP_CLIENT_ID` | iOS Release 지도 기능 | 현재 placeholder 상태 |
| 네이버맵 Client ID (Dart define) | `--dart-define=NAVER_MAP_CLIENT_ID=...` | 앱 내부 `AppConstants.naverMapClientId` 사용 시 | 네이티브 설정과 별도로 맞추는 쪽이 안전 |
| MQTT 브로커 주소 | `--dart-define=MQTT_BROKER_URL=...` | IoT 데모/운영 시 | 없으면 IoT 화면이 “미설정”으로 동작 |
| MQTT 브로커 포트 | `--dart-define=MQTT_BROKER_PORT=...` | IoT 데모/운영 시 | 기본값 `1883` |
| Android 릴리스 서명 | `android/key.properties` + keystore 파일 | Android release/AAB 생성 | 현재 코드는 debug 서명 상태 |
| iOS 서명·배포 자격 | Apple Developer / Xcode Signing 설정 | iOS 기기 배포 / TestFlight | 코드 저장소 안에서 해결되지 않음 |
| APNs 인증 키 | Firebase Console > Cloud Messaging에 등록 | iOS 푸시 수신 | Apple Developer에서 발급 |
| Google Calendar OAuth | Google Cloud Console(동일 Firebase 프로젝트 권장) | 캘린더 연동 | [§2-7](#google-calendar-oauth) 참고 |
| Firebase 배포 | Firebase CLI / Console | rules, indexes, storage, functions 반영 | 코드만 수정해도 서버엔 자동 반영되지 않음 |

<a id="manual-build-platform-matrix"></a>

### 1-1. 플랫폼별 수동 준비 한눈에 (빠짐 방지)

| 수동 항목 | Android | iOS | 공통(플랫폼 무관) |
|-----------|---------|-----|-------------------|
| Firebase 플랫폼 설정 파일 | `android/app/google-services.json` | `ios/Runner/GoogleService-Info.plist` | `lib/firebase_options.dart` |
| 네이버맵 Client ID | `gradle.properties`의 `NAVER_MAP_CLIENT_ID` | `Debug.xcconfig` / `Release.xcconfig`의 `NAVER_MAP_CLIENT_ID` | (선택) `--dart-define=NAVER_MAP_CLIENT_ID=...` |
| FCM / 푸시 | `google-services.json`으로 FCM 연동 | APNs 인증 키를 Firebase에 등록, Push capability | Cloud Functions 배포·토큰 저장(앱·서버) |
| Google Calendar OAuth | Cloud Console **Android OAuth 클라이언트**(패키지명·SHA-1) | Cloud Console **iOS OAuth 클라이언트**(번들 ID) | Calendar API·동의 화면·테스트 사용자([§2-7](#google-calendar-oauth)) |
| 릴리스 배포 | `key.properties` + keystore, 릴리스 서명 설정 | Signing·Provisioning·(선택) TestFlight / App Store Connect | — |
| 기타 | MQTT 등은 `--dart-define`으로 주입(IoT) | 동일 | 아래 §2-3 |

체크박스·명령 순서는 [release-checklist.md](./release-checklist.md) §0~§6과 같은 축이다.

<a id="manual-item-details"></a>

## 2. 항목별 상세

<a id="firebase-config-files"></a>

### 2-1. Firebase 설정 파일 3종

이 저장소에는 아래 파일이 보통 없다.

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

<a id="naver-map-client-id"></a>

### 2-2. 네이버맵 Client ID

현재 저장소에는 아래 3곳이 placeholder 상태다.

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
grep -q 'YOUR_NAVER_MAP_CLIENT_ID' android/gradle.properties && echo "MISSING: Android 네이버맵 Client ID" || echo "OK: Android 네이버맵 Client ID"
grep -q 'YOUR_NAVER_MAP_CLIENT_ID' ios/Flutter/Debug.xcconfig && echo "MISSING: iOS Debug 네이버맵 Client ID" || echo "OK: iOS Debug 네이버맵 Client ID"
grep -q 'YOUR_NAVER_MAP_CLIENT_ID' ios/Flutter/Release.xcconfig && echo "MISSING: iOS Release 네이버맵 Client ID" || echo "OK: iOS Release 네이버맵 Client ID"
```

참고:

- xcconfig 주석은 `Local.xcconfig`를 언급하지만, 저장소에는 해당 include가 기본 연결되어 있지 않다.
- 가장 단순한 방법은 `Debug.xcconfig`, `Release.xcconfig`의 placeholder를 실제 값으로 바꾸는 것이다.

<a id="mqtt-broker-define"></a>

### 2-3. MQTT 브로커 값

IoT는 코드만으로는 브로커에 연결되지 않는다.

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

- 앱은 MQTT 연결을 시도하지 않는다.
- IoT 화면에 “브로커 미설정” 배너가 보인다.

<a id="android-release-signing"></a>

### 2-4. Android 릴리스 서명

현재 `android/app/build.gradle.kts`는 release 빌드에서도 debug 서명을 쓰도록 되어 있다.

직접 준비해야 하는 것:

- release keystore 파일
- `android/key.properties`
- `build.gradle.kts`의 릴리스 서명 설정 교체

예시 `android/key.properties`:

```properties
storePassword=실제비밀번호
keyPassword=실제비밀번호
keyAlias=release
storeFile=/절대경로/your-release-key.jks
```

주의:

- keystore와 `key.properties`는 저장소에 커밋하지 않는 것이 안전합니다.
- 현재 코드는 릴리스 서명 TODO 상태이므로, 스토어 제출 전 수동 교체가 필요합니다.

<a id="ios-signing-deploy"></a>

### 2-5. iOS 서명·배포(TestFlight 등)

iOS는 코드만으로 끝나지 않고, 아래 항목을 Apple Developer / Xcode에서 직접 맞춰야 합니다.

- Team 선택
- Bundle Identifier 일치 확인
- Signing Certificate / Provisioning Profile
- Device 등록 또는 TestFlight 배포 설정

즉, `flutter build ios`가 된다고 바로 배포 가능한 상태는 아니다.

<a id="apns-auth-key"></a>

### 2-6. APNs 인증 키·iOS 푸시

iOS 푸시를 실제로 받으려면 **APNs 인증 키**를 Apple에서 발급해 Firebase에 등록해야 한다.

1. Apple Developer 포털에서 **APNs 인증 키** 발급
2. Firebase Console > 프로젝트 설정 > **Cloud Messaging**에 업로드
3. Xcode에서 Push Notifications capability·앱 식별자 확인

코드만 갖춰져 있고, 콘솔 등록 전에는 iOS 푸시가 동작하지 않을 수 있다.

<a id="google-calendar-oauth"></a>

### 2-7. Google Calendar OAuth

Google Calendar 연동은 `google_sign_in`으로 **Calendar API**만 요청하며, Firebase 이메일 로그인과는 별개다. `GoogleCalendarService`는 `GoogleSignIn(scopes: [calendarScope])`만 쓰고, **웹 클라이언트 ID(`serverClientId`)는 코드에 넣지 않는다.** 플랫폼별 **OAuth 2.0 클라이언트**가 Cloud Console에 맞아야 한다.

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

이 설정이 빠지거나 SHA·번들 ID가 빌드와 다르면 계정 선택은 떠도 **토큰·Calendar API 호출이 실패**할 수 있다.

<a id="firebase-deploy-cli"></a>

### 2-8. Firebase rules / indexes / functions 배포

저장소 파일을 바꿔도 Firebase 서버에는 자동 반영되지 않는다.

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

<a id="location-sharing-permissions"></a>

### 2-9. 위치 공유·권한(플랫폼 동작 요약)

빌드 시 **별도 키 입력은 없다.** 다만 시연·실기기 검증([real-device-validation-matrix.md](./real-device-validation-matrix.md) §8, [demo-walkthrough.md](./demo-walkthrough.md) 9단계)에서 OS를 착각하면 실패로 보일 수 있어 요약만 둔다. 상세 표는 [README](../README.md)의 **위치 공유**(프로세스가 살아 있는 동안, 백그라운드 포함) 절과 동일 축이다.

| 플랫폼 | 권한·백그라운드 요약 |
|--------|----------------------|
| **Android** | 위치 공유 시 **포그라운드 서비스 알림**이 뜰 수 있다. 런타임에는 보통 **앱 사용 중 위치**부터 허용받고, **항상 허용(백그라운드 위치)** 은 기기 설정에서 추가로 묻는 경우가 있다. |
| **iOS** | 지도·공유를 쓰려면 위치 권한이 필요하다. **백그라운드에서 좌표 스트림을 이어가려면 「항상」**이어야 하며, **「앱을 사용하는 동안만」**이면 앱이 백그라운드로 가면 갱신이 멈추고, 화면에 **「항상」으로 변경** 안내가 뜬다. |

**데모에서의 구분**: 짧은 시연은 **포그라운드에서 마커·토글·배너**만 보여도 된다. **백그라운드 갱신**을 주장하려면 iOS는 **항상** 허용 상태에서 검증할 것.

## 3. 빌드 전에 최소 확인하면 좋은 순서

**preflight 전·후 사람이 볼 것**은 위 [Preflight 실전](#preflight-human-checklist) 절과, **증상으로 역추적**할 때는 [자주 빠지는 설정](#common-config-failure-symptoms) 표를 쓴다. 체크박스·명령 전체는 [release-checklist.md](./release-checklist.md) §0~§6에만 상세히 둔다.

요약만: Android 디버그는 Firebase 3종·네이버맵·(선택) MQTT·(시연 시) Calendar OAuth SHA-1 → `flutter run`. 릴리스는 추가로 [§2-4](#android-release-signing). iOS는 plist·xcconfig·APNs·서명 → `flutter run`(필요 시 `--dart-define=NAVER_MAP_CLIENT_ID=...`).

```bash
# 프로젝트 루트에서 (디버그 예시)
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter run --dart-define=NAVER_MAP_CLIENT_ID=실제키
```

<a id="preflight-quick-command"></a>

## 4. 한 번에 점검하는 빠른 명령

**실행 전후에 사람이 무엇을 볼지**는 [Preflight 실전](#preflight-human-checklist) 절, **실패 증상 ↔ 파일**은 [자주 빠지는 설정](#common-config-failure-symptoms) 표를 병행한다.

아래 항목을 자동 점검하는 **preflight**는 `tool/preflight.sh`에 있다.

```bash
# 프로젝트 루트(저장소 어디서든 동일)
cd "$(git rev-parse --show-toplevel)"
bash tool/preflight.sh
```

**분석·테스트 전 게이트**:

```bash
cd "$(git rev-parse --show-toplevel)"
bash tool/preflight.sh || exit 1
flutter pub get
flutter analyze
flutter test
```

스크립트는 **읽기 전용**이며 파일을 수정하지 않는다. 점검 항목:

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

grep -q 'YOUR_NAVER_MAP_CLIENT_ID' android/gradle.properties && echo "✗ Android 네이버맵 Client ID 미설정" || echo "✓ Android 네이버맵 Client ID 설정"
grep -q 'YOUR_NAVER_MAP_CLIENT_ID' ios/Flutter/Debug.xcconfig && echo "✗ iOS Debug 네이버맵 Client ID 미설정" || echo "✓ iOS Debug 네이버맵 Client ID 설정"
grep -q 'YOUR_NAVER_MAP_CLIENT_ID' ios/Flutter/Release.xcconfig && echo "✗ iOS Release 네이버맵 Client ID 미설정" || echo "✓ iOS Release 네이버맵 Client ID 설정"

test -f android/key.properties && echo "✓ android/key.properties" || echo "✗ android/key.properties"
```

</details>

## 5. 요약

빌드 직전 사람이 챙길 핵심 목록은 **[§6 — 수동 체크 최종 정리본](#manual-check-final-summary)** 한곳에 모았다. `prototype-remaining-work`의 수동 입력 순서와 같고, 증상으로 되짚을 때는 [자주 빠지는 설정](#common-config-failure-symptoms) 표를 함께 보면 된다.

<a id="manual-check-final-summary"></a>

## 6. 사람 손이 필요한 수동 체크 — 최종 정리본

아래는 **자동 스크립트·CI만으로는 대체할 수 없는 확인·입력**을 순서대로 묶은 것이다. 상세 절차·명령은 링크 열을 따른다.

| 순서 | 수동 확인·입력 | 데모(시제품 시연) | 배포·운영 | 근거 |
|------|----------------|------------------|-----------|------|
| 1 | Firebase 설정 파일 3종 존재·프로젝트 연결 | 필수 | 필수 | [§2-1](#firebase-config-files), [release-checklist §1](./release-checklist.md#rl-1-firebase) |
| 2 | Firestore/Storage 규칙·인덱스 **실제 배포**(dry-run 후) | 실서버 데모 시 필수 | 필수 | [§2-8](#firebase-deploy-cli), [firebase-deploy-audit.md](./firebase-deploy-audit.md) |
| 3 | Cloud Functions 배포·동작 확인 | 푸시 데모 시 필수 | 필수 | [release-checklist §2·§4](./release-checklist.md#rl-2-fcm) |
| 4 | APNs 인증 키(Firebase)·iOS Push capability·`remote-notification` | iOS에서 푸시 보여줄 때 필수 | iOS 푸시 필수 | [§2-6](#apns-auth-key), [release-checklist §2](./release-checklist.md#rl-2-fcm) |
| 5 | 네이버맵 Client ID(Android·iOS·선택 `--dart-define`) | 지도 데모 시 필수 | 필수 | [§2-2](#naver-map-client-id), [release-checklist §3](./release-checklist.md#rl-3-naver-map) |
| 6 | `bash tool/preflight.sh`로 파일·플레이스홀더 점검 | 강력 권장 | 강력 권장 | [§4](#preflight-quick-command) |
| 7 | Flutter `analyze`/`test`·Debug 빌드·실기기 실행 | 데모 리허설 | 품질 게이트 | [release-checklist §5·§6](./release-checklist.md#rl-5-android) |
| 8 | **앱 안** 기능·푸시·지도 등 손 점검(P/F) | 권장 | 권장 | [real-device-validation-matrix.md](./real-device-validation-matrix.md), [release-checklist §7](./release-checklist.md#rl-7-manual-qa) |
| 9 | 데모 당일 smoke·Debug 시드·워크스루 | 당일 필수 | — | [demo-smoke-push-map-calendar.md](./demo-smoke-push-map-calendar.md), [demo-walkthrough.md](./demo-walkthrough.md) |
| 10 | (선택) Google Calendar OAuth | 시연에 쓸 때만 | 기능 공개 시 | [§2-7](#google-calendar-oauth), [release-checklist §8](./release-checklist.md#8-선택-사항-데모-범위-밖) |
| 11 | (선택) MQTT 브로커 `--dart-define` | IoT 시연 시 | IoT 실사용 시 | [§2-3](#mqtt-broker-define) |
| 12 | Android 릴리스 서명·keystore·`key.properties` | 스토어/내부 release 패키지 필요 시 | 스토어·내부 배포 시 | [§2-4](#android-release-signing), [release-checklist §5](./release-checklist.md#rl-5-android) |
| 13 | iOS 서명·Provisioning·배포 채널 | TestFlight/스토어 목표 시 | 동일 | [§2-5](#ios-signing-deploy), [release-checklist §6](./release-checklist.md#rl-6-ios) |
| 14 | Firebase 보안 규칙 **운영 관점** 최종 검토·Crashlytics/Analytics | 데모 생략 가능 | 권장~필수(조직 기준) | [release-checklist §8](./release-checklist.md#8-선택-사항-데모-범위-밖) |

위 항목은 코드 저장소만으로는 자동 해결되지 않는다. **데모 vs 배포** 기대치는 [위 요약 표](#demo-vs-deploy-conditions)와 [README](../README.md#readme-demo-vs-deploy-status)를 함께 본다.
