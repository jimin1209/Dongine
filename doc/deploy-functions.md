# Functions 배포 가이드

## 사전 요구사항

- Node.js 20
- Firebase CLI (`npm install -g firebase-tools`)
- Firebase 프로젝트 접근 권한 (`dongine-13214`)
- iOS 푸시: Apple Developer 계정에서 APNs 키를 발급받아 Firebase Console > Cloud Messaging에 등록
- Android 푸시: `google-services.json`이 `android/app/`에 존재해야 함

## 로컬 검증

```bash
cd functions
npm install
npm run lint    # node --check 로 문법 검증
npm test        # notification_payloads 단위 테스트
```

에뮬레이터로 함수 동작을 확인하려면:

```bash
npm run serve   # firebase emulators:start --only functions
```

## 배포

```bash
cd functions
npm install
cd ..
firebase deploy --only functions --project=dongine-13214
```

또는 functions 디렉토리에서 직접:

```bash
npm run deploy
```

## 배포 후 확인

1. Firebase Console > Functions에서 함수 5개가 정상 배포되었는지 확인
   - `notifyOnChatMessageCreated`
   - `notifyOnCalendarEventCreated`
   - `notifyOnTodoCreated`
   - `notifyOnCartItemCreated`
   - `notifyOnExpenseCreated`
2. 리전이 `asia-northeast3`인지 확인
3. 앱에서 채팅 메시지를 보내고 다른 기기에서 푸시 알림이 오는지 확인

## APNs / FCM 푸시 자격 설정

iOS 푸시 알림을 받으려면 다음이 필요하다:

1. **APNs 인증 키** (권장) 또는 APNs 인증서를 Apple Developer 포탈에서 발급
2. Firebase Console > 프로젝트 설정 > Cloud Messaging 탭에서 APNs 키 업로드
3. Xcode에서 Push Notifications capability 활성화
4. `ios/Runner/Info.plist`에 `remote-notification` 백그라운드 모드 설정

Android는 별도 푸시 자격 설정 없이 `google-services.json`만 있으면 동작한다.

## CI

GitHub Actions가 `functions/` 변경 시 자동으로 lint와 test를 실행한다.
워크플로우 파일: `.github/workflows/functions-ci.yml`

## 롤백

문제 발생 시 이전 버전으로 롤백:

```bash
# Firebase Console > Functions > 함수 선택 > 버전 기록에서 이전 버전 확인
# 또는 해당 커밋으로 체크아웃 후 재배포
git checkout <이전-커밋-SHA>
cd functions && npm install && cd ..
firebase deploy --only functions --project=dongine-13214
```
