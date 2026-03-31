# 시제품 데모 전 Release Checklist

이 문서는 시제품을 데모하기 직전에 빠짐없이 확인해야 할 항목을 정리한 체크리스트다.
항목별로 **확인 명령**과 **기대 결과**를 함께 적었으므로 위에서부터 순서대로 따라가면 된다.

**함께 볼 문서(실사용 순서)**  
[manual-build-inputs.md](./manual-build-inputs.md)(수동으로 넣을 값) → **이 체크리스트** → [firebase-deploy-audit.md](./firebase-deploy-audit.md)(배포 전 dry-run, 권장) → [demo-smoke-push-map-calendar.md](./demo-smoke-push-map-calendar.md)(데모 직전 smoke) → [demo-walkthrough.md](./demo-walkthrough.md)(시연 대본).  
README의 한눈에 보기 표는 [README.md § 시제품 데모 준비](../README.md#시제품-데모-준비--문서-진입-경로)에 있다.

---

## 1. Firebase 프로젝트 설정

- [ ] Firebase Console에서 프로젝트 `dongine-13214` 접근 가능 확인
- [ ] Blaze(종량제) 요금제 활성 상태 확인 (Cloud Functions 실행에 필요)
- [ ] `android/app/google-services.json` 파일 존재

```bash
ls android/app/google-services.json
# 기대: 파일이 존재해야 함
```

- [ ] `ios/Runner/GoogleService-Info.plist` 파일 존재 (iOS 빌드 시 필요)

```bash
ls ios/Runner/GoogleService-Info.plist
# 기대: 파일이 존재해야 함. 없으면 Firebase Console > 프로젝트 설정 > iOS 앱에서 다운로드
```

- [ ] `lib/firebase_options.dart` 파일 존재

```bash
ls lib/firebase_options.dart
# 기대: 파일이 존재해야 함. 없으면 flutterfire configure --project=dongine-13214 실행
```

- [ ] Firestore 규칙·인덱스 배포 상태

```bash
firebase deploy --only firestore:rules,firestore:indexes --project=dongine-13214 --dry-run
# 기대: 에러 없이 배포 가능해야 함
```

- [ ] Storage 규칙 배포 상태

```bash
firebase deploy --only storage --project=dongine-13214 --dry-run
# 기대: 에러 없이 배포 가능해야 함
```

---

## 2. FCM 푸시 알림

- [ ] **Android**: `google-services.json`에 `mobilesdk_app_id` 값이 올바른지 확인

```bash
grep '"mobilesdk_app_id"' android/app/google-services.json
# 기대: "1:998912705610:android:2946cb071a3c2511e0d2b3"
```

- [ ] **iOS APNs 키**: Firebase Console > 프로젝트 설정 > Cloud Messaging 탭에서 APNs 인증 키가 등록되어 있는지 확인
  - Apple Developer 포탈 > Keys에서 APNs 키 발급 필요 (아직 안 했다면)
  - Xcode > Runner > Signing & Capabilities에서 **Push Notifications** capability 활성화 확인
- [ ] **iOS 백그라운드 모드**: `remote-notification` 설정 확인

```bash
grep -A1 'UIBackgroundModes' ios/Runner/Info.plist
# 기대: <string>remote-notification</string> 포함
```

- [ ] **Functions 배포**: 알림 함수 5개가 `asia-northeast3`에 배포되어 있는지 확인

```bash
cd functions && npm ci && npm run lint && npm test && cd ..
firebase deploy --only functions --project=dongine-13214
# 기대: 5개 함수 배포 성공
```

  배포 후 Firebase Console > Functions에서 확인할 함수 목록:
  1. `notifyOnChatMessageCreated`
  2. `notifyOnCalendarEventCreated`
  3. `notifyOnTodoCreated`
  4. `notifyOnCartItemCreated`
  5. `notifyOnExpenseCreated`

- [ ] **실기기 테스트**: 앱에서 채팅 메시지를 보내고 다른 기기에서 푸시 알림 수신 확인

---

## 3. 네이버 지도 Client ID

- [ ] **Android**: `android/gradle.properties`에 실제 Client ID 설정

```bash
grep 'NAVER_MAP_CLIENT_ID' android/gradle.properties
# 기대: YOUR_NAVER_MAP_CLIENT_ID가 아닌 실제 값이어야 함
```

- [ ] **iOS Debug**: `ios/Flutter/Debug.xcconfig`에 실제 Client ID 설정

```bash
grep 'NAVER_MAP_CLIENT_ID' ios/Flutter/Debug.xcconfig
# 기대: YOUR_NAVER_MAP_CLIENT_ID가 아닌 실제 값이어야 함
```

- [ ] **iOS Release**: `ios/Flutter/Release.xcconfig`에 실제 Client ID 설정

```bash
grep 'NAVER_MAP_CLIENT_ID' ios/Flutter/Release.xcconfig
# 기대: YOUR_NAVER_MAP_CLIENT_ID가 아닌 실제 값이어야 함
```

- [ ] 앱에서 위치 공유 화면 진입 후 지도가 정상 렌더링되는지 확인

---

## 4. Cloud Functions

- [ ] Node.js 20 설치 확인

```bash
node --version
# 기대: v20.x.x
```

- [ ] Functions 로컬 테스트 통과

```bash
cd functions && npm ci && npm run lint && npm test
# 기대: 모두 통과
```

- [ ] Functions 배포 (위 2번에서 이미 했다면 생략 가능)
- [ ] 에뮬레이터로 동작 확인 (선택)

```bash
cd functions && npm run serve
# Firestore 에뮬레이터에서 문서를 생성하고 함수 트리거 확인
```

---

## 5. Android 빌드

- [ ] Flutter 의존성 설치

```bash
flutter pub get
# 기대: 에러 없이 완료
```

- [ ] 정적 분석 통과

```bash
flutter analyze
# 기대: No issues found!
```

- [ ] 단위 테스트 통과

```bash
flutter test
# 기대: All tests passed!
```

- [ ] Debug APK 빌드

```bash
flutter build apk --debug
# 기대: build/app/outputs/flutter-apk/app-debug.apk 생성
```

- [ ] Release APK 빌드 (서명 설정 필요)
  - `android/key.properties` 파일 존재 확인
  - keystore 파일 경로가 올바른지 확인

```bash
ls android/key.properties
# 기대: 파일이 존재해야 함. 없으면 아래 형식으로 생성:
# storePassword=<비밀번호>
# keyPassword=<비밀번호>
# keyAlias=<별칭>
# storeFile=<keystore 파일 경로>
```

```bash
flutter build apk --release
# 기대: build/app/outputs/flutter-apk/app-release.apk 생성
```

- [ ] 실기기 또는 에뮬레이터에서 앱 설치·실행 확인

```bash
flutter run
# 또는 빌드된 APK를 실기기에 설치
```

---

## 6. iOS 빌드

- [ ] Xcode 최신 stable 버전 설치 확인
- [ ] CocoaPods 설치·업데이트

```bash
cd ios && pod install && cd ..
# 기대: 에러 없이 완료
```

- [ ] Xcode에서 `ios/Runner.xcworkspace` 열기
- [ ] Signing & Capabilities 확인
  - Team: 올바른 Apple Developer 팀 선택
  - Bundle Identifier: `com.dongine.dongine`
  - Push Notifications capability 활성화
- [ ] Debug 빌드

```bash
flutter build ios --debug --no-codesign
# 기대: 에러 없이 빌드 완료
```

- [ ] Release 빌드 (배포 시)

```bash
flutter build ios --release
# 기대: 에러 없이 빌드 완료 (유효한 provisioning profile 필요)
```

- [ ] 실기기에서 앱 실행 확인

---

## 7. 데모 시나리오 사전 점검

데모 당일에 아래 기능을 한 번씩 실행해 보고 정상 동작을 확인한다.

| 순서 | 기능 | 확인 포인트 |
|------|------|------------|
| 1 | 회원가입/로그인 | 이메일+비밀번호로 가입 후 로그인 성공 |
| 2 | 가족 생성 | 가족 이름 입력 후 초대 코드 생성 확인 |
| 3 | 가족 참가 | 다른 계정에서 초대 코드로 참가 성공 |
| 4 | 채팅 | 메시지 전송·읽음 표시·슬래시 커맨드 동작 |
| 5 | 캘린더 | 일정 생성·수정·삭제, 월간 뷰 확인 |
| 6 | 할 일 | 할 일 추가·완료 토글·담당자 지정 |
| 7 | 장보기 | 품목 추가·추천·중복 병합·체크 |
| 8 | 가계부 | 지출 기록·월별 합계·카테고리 필터 |
| 9 | 파일함 | 파일 업로드·다운로드·폴더 탐색 |
| 10 | 앨범 | 앨범 생성·사진 업로드·커버 확인 |
| 11 | 위치 공유 | 위치 권한 허용 후 지도에 가족 위치 표시 |
| 12 | 푸시 알림 | 다른 기기에서 채팅 발송 → 알림 수신 확인 |

---

## 8. 선택 사항 (데모 범위 밖)

아래 항목은 시제품 데모에서 필수는 아니지만, 운영으로 넘어갈 때 확인해야 한다.  
(README의 **아직 운영 준비가 덜 된 부분** 표와 같은 범위이며, 항목별 경로·명령은 [manual-build-inputs.md](./manual-build-inputs.md)를 본다.)

- [ ] Google Calendar 연동: OAuth 클라이언트 설정 (Google Cloud Console에서 Android SHA·iOS 번들 ID 등록)
- [ ] IoT(MQTT): `--dart-define=MQTT_BROKER_URL=...` 설정 및 실제 브로커 연결
- [ ] Android Release 서명: 프로덕션 keystore 준비
- [ ] iOS 배포: App Store Connect 설정, 프로비저닝 프로파일 준비
- [ ] Firebase 보안 규칙 최종 검토
- [ ] Crashlytics / Analytics 활성화

---

## 빠른 로컬 검증 (중복 없이)

- **파일·플레이스홀더 일괄 점검**: 프로젝트 루트에서 `bash tool/preflight.sh` ([manual-build-inputs.md](./manual-build-inputs.md) §4). README의 **데모 전 빠른 준비** 요약과도 맞춘다.
- **Flutter + Functions**: §5(Android)의 `flutter pub get` / `analyze` / `test` 와 §4(Functions)의 `cd functions && npm ci && npm run lint && npm test` 를 그대로 사용한다(§2 FCM 절차에서 이미 돌렸다면 중복 실행은 생략 가능). 여기에 동일 블록을 다시 넣지 않는다.
