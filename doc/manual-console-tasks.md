# 수동 콘솔/설정 작업 체크리스트

코드가 아닌 **사람이 직접 콘솔에서 해야 하는 작업**만 모은 문서.
체크박스를 채우면서 진행하면 된다.

---

## 1. Google Cloud Console 작업

### 1-1. 웹 OAuth 클라이언트 ID → 코드에 입력
- [ ] [사용자 인증 정보](https://console.cloud.google.com/apis/credentials?project=dongine-13214) 접속
- [ ] **Web client (auto created by Google Service)** 클릭
- [ ] 상단 **클라이언트 ID** 값 복사 (998912705610-581r...apps.googleusercontent.com)
- [ ] `lib/features/calendar/data/google_calendar_service.dart`의 `_webClientId` 값을 복사한 값으로 교체
- [ ] `flutter build web && firebase deploy --only hosting` 재배포

### 1-2. Google Calendar API 활성화
- [ ] [API 라이브러리](https://console.cloud.google.com/apis/library?project=dongine-13214) 접속
- [ ] "Google Calendar API" 검색 → **사용** 클릭
- [ ] 이미 활성화되어 있으면 패스

### 1-3. OAuth 동의 화면 설정
- [ ] [OAuth 동의 화면](https://console.cloud.google.com/apis/credentials/consent?project=dongine-13214) 접속
- [ ] **스코프 추가**: `https://www.googleapis.com/auth/calendar`
- [ ] **테스트 사용자 추가**: 가족 구성원 이메일 등록 (앱이 "테스트" 상태인 경우 필수)

---

## 2. Firebase Console 작업

### 2-1. iOS Firebase 설정 파일
- [ ] [Firebase Console 프로젝트 설정](https://console.firebase.google.com/project/dongine-13214/settings/general) 접속
- [ ] iOS 앱 항목에서 `GoogleService-Info.plist` 다운로드
- [ ] `ios/Runner/GoogleService-Info.plist`에 배치
- [ ] 또는 터미널에서: `flutterfire configure --project=dongine-13214`

### 2-2. Firestore/Storage Rules 배포
- [ ] 터미널에서 실행:
  ```bash
  firebase deploy --only firestore:rules,firestore:indexes --project=dongine-13214
  firebase deploy --only storage --project=dongine-13214
  ```

### 2-3. Firebase Authentication 확인
- [ ] [Authentication > Sign-in method](https://console.firebase.google.com/project/dongine-13214/authentication/providers)에서 Google 로그인 활성화 확인
- [ ] [승인된 도메인](https://console.firebase.google.com/project/dongine-13214/authentication/settings)에 `dongine-13214.web.app` 확인

---

## 3. Firebase Storage CORS 설정

사진 업로드 후 웹에서 이미지가 로드되지 않으면 CORS 설정이 필요하다.

### 방법 A: Google Cloud Shell (추천)
- [ ] [Cloud Shell](https://console.cloud.google.com/cloudshell?project=dongine-13214) 접속
- [ ] 아래 명령 실행:
  ```bash
  cat > cors.json << 'EOF'
  [
    {
      "origin": ["https://dongine-13214.web.app", "https://dongine-13214.firebaseapp.com"],
      "method": ["GET"],
      "maxAgeSeconds": 3600
    }
  ]
  EOF
  gsutil cors set cors.json gs://dongine-13214.firebasestorage.app
  ```

### 방법 B: 로컬 (gcloud SDK 설치 필요)
- [ ] `gcloud auth login`
- [ ] 위와 동일한 `gsutil cors set` 실행

---

## 4. 네이버맵 Client ID

git에는 placeholder로 유지하고, 로컬에서만 실제 값으로 교체.

- [ ] `android/gradle.properties`의 `NAVER_MAP_CLIENT_ID=je53dljowq`
- [ ] `ios/Flutter/Debug.xcconfig`의 `NAVER_MAP_CLIENT_ID=je53dljowq`
- [ ] `ios/Flutter/Release.xcconfig`의 `NAVER_MAP_CLIENT_ID=je53dljowq`
- [ ] 네이버 클라우드 콘솔에서 Web service URL에 `https://dongine-13214.web.app` 등록 확인

---

## 5. 앱 배포 준비 (스토어 제출 시)

### 5-1. Android 릴리스 서명
- [ ] release keystore 생성: `keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000`
- [ ] `android/key.properties` 생성:
  ```properties
  storePassword=비밀번호
  keyPassword=비밀번호
  keyAlias=release
  storeFile=/절대경로/release.jks
  ```
- [ ] keystore와 key.properties는 git에 커밋하지 않음

### 5-2. iOS 서명/배포
- [ ] Apple Developer 계정에서 Team 선택
- [ ] Xcode > Signing & Capabilities에서 Bundle ID `com.dongine.dongine` 확인
- [ ] Provisioning Profile 생성
- [ ] (선택) TestFlight / App Store Connect 설정

### 5-3. iOS 푸시 (APNs)
- [ ] Apple Developer > Certificates에서 APNs 인증 키 발급
- [ ] Firebase Console > Cloud Messaging에 APNs 키 업로드
- [ ] Xcode에서 Push Notifications capability 추가

---

## 진행 순서 (추천)

1. **§1-1** OAuth 클라이언트 ID → 캘린더 연동 해결
2. **§3** CORS 설정 → 사진 로드 해결
3. **§1-2, §1-3** Calendar API + 동의 화면
4. **§2-2** Rules 배포
5. **§2-1** iOS plist (iOS 빌드할 때)
6. **§4** 네이버맵 (이미 웹에서 등록 완료)
7. **§5** 스토어 배포 준비 (필요할 때)
