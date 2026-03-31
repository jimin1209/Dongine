# Firebase 서버 반영 전 점검 절차

배포 대상 4가지(Rules, Indexes, Storage, Functions)를 서버에 올리기 전에 확인해야 할 사항을 정리한다. 각 항목마다 **점검 명령**, **기대 결과**, **흔한 실수 예시**를 포함한다.

> 이 문서는 `firebase.json`에 선언된 리소스 기준이다.
> 프로젝트 ID: `dongine-13214` / 리전: `asia-northeast3`

---

## 0. 공통 사전 조건

```bash
# Firebase CLI 로그인 상태 확인
firebase login:list

# 기대 결과: dongine-13214 프로젝트 접근 권한이 있는 계정이 표시됨
# ✔ Logged in as you@example.com
```

```bash
# 프로젝트 연결 확인
firebase use dongine-13214

# 기대 결과: Now using project dongine-13214
```

CLI가 없으면 먼저 설치한다:

```bash
npm install -g firebase-tools
firebase login
```

---

## 1. Firestore Rules (`firestore.rules`)

### 1-1. 무엇을 확인해야 하는가

| 점검 항목 | 왜 중요한가 |
|-----------|------------|
| 문법 오류 없음 | 문법 오류가 있으면 배포 자체가 실패하고 기존 규칙이 유지됨 |
| 새로 추가한 컬렉션에 규칙이 있는지 | 규칙이 없는 경로는 기본 차단(deny)됨 — 앱이 읽기/쓰기 불가 |
| `isFamilyMember` 등 헬퍼 함수 변경 시 영향 범위 | 모든 가족 하위 컬렉션이 이 함수에 의존함 |
| 테스트 규칙(allow read, write: if true) 제거 | 개발 중 열어둔 규칙이 서버에 올라가면 데이터 노출 |

### 1-2. 점검 명령과 기대 결과

```bash
# Dry-run: 실제 배포 없이 규칙 검증
firebase deploy --only firestore:rules --project=dongine-13214 --dry-run

# 기대 결과:
# ✔ firestore: rules file firestore.rules compiled successfully
# i  firestore: upload complete (dry run)
```

오류가 있으면 아래와 유사한 메시지가 나온다:

```
Error: firestore.rules:45:5 - Unexpected token
```

### 1-3. 로컬에만 있고 서버에 안 올라간 변경 예시

- `firestore.rules`에 `/families/{familyId}/polls/{pollId}` 경로를 추가했지만 `firebase deploy`를 아직 실행하지 않은 경우
- `isOwner` 함수의 조건을 수정했지만 커밋만 하고 배포하지 않은 경우
- 규칙 파일에서 `allow write: if true`를 테스트용으로 넣었다가 되돌리기 전 상태

---

## 2. Firestore Indexes (`firestore.indexes.json`)

### 2-1. 무엇을 확인해야 하는가

| 점검 항목 | 왜 중요한가 |
|-----------|------------|
| JSON 문법 | 문법 오류 시 배포 실패 |
| 새 쿼리에 필요한 복합 인덱스 추가 여부 | 인덱스 없이 복합 쿼리 실행 시 앱에서 에러 발생 |
| 불필요한 인덱스 제거 | 인덱스가 많으면 쓰기 성능 저하 및 비용 증가 |
| `collectionGroup` vs `COLLECTION` 범위 | 잘못 지정하면 서브컬렉션 쿼리가 동작하지 않음 |

### 2-2. 점검 명령과 기대 결과

```bash
# JSON 문법 검증 (jq 설치 필요)
cat firestore.indexes.json | jq . > /dev/null && echo "OK" || echo "JSON 문법 오류"

# 기대 결과: OK
```

```bash
# Dry-run: 인덱스 배포 검증
firebase deploy --only firestore:indexes --project=dongine-13214 --dry-run

# 기대 결과:
# ✔ firestore: configured indexes for ...
# i  firestore: indexes upload complete (dry run)
```

```bash
# 현재 서버에 배포된 인덱스와 로컬 차이 확인
firebase firestore:indexes --project=dongine-13214

# 기대 결과: 서버에 있는 인덱스 목록이 JSON으로 출력됨
# 이를 firestore.indexes.json과 비교하여 차이를 파악
```

### 2-3. 로컬에만 있고 서버에 안 올라간 변경 예시

- `expenses` 컬렉션에 `(category ASC, date DESC)` 복합 인덱스를 JSON에 추가했지만 아직 배포하지 않은 경우 — 앱에서 해당 정렬 쿼리 실행 시 `FAILED_PRECONDITION` 에러 발생
- 현재 `cart` 컬렉션에만 2개 인덱스가 있음 — 새 기능에서 다른 컬렉션의 복합 쿼리를 쓴다면 인덱스 추가 필요

---

## 3. Storage Rules (`storage.rules`)

### 3-1. 무엇을 확인해야 하는가

| 점검 항목 | 왜 중요한가 |
|-----------|------------|
| 인증 조건 (`request.auth != null`) | 미인증 사용자의 파일 접근 차단 |
| 가족 멤버 검증 (`firestore.exists(...)`) | 다른 가족의 파일에 접근 불가 확인 |
| 파일 크기 제한 (`request.resource.size`) | 현재 100MB — 변경 시 앱 UX와 비용에 영향 |
| 새 경로 추가 시 규칙 존재 여부 | 규칙이 없는 경로는 기본 차단 |

### 3-2. 점검 명령과 기대 결과

```bash
# Dry-run: 스토리지 규칙 검증
firebase deploy --only storage --project=dongine-13214 --dry-run

# 기대 결과:
# ✔ storage: rules file storage.rules compiled successfully
# i  storage: upload complete (dry run)
```

### 3-3. 로컬에만 있고 서버에 안 올라간 변경 예시

- `storage.rules`에서 파일 크기 제한을 50MB로 줄였지만 배포하지 않은 경우 — 서버에서는 여전히 100MB까지 허용
- `/families/{familyId}/profile/` 경로를 새로 추가했지만 배포 전이라 앱에서 프로필 이미지 업로드 시 `PERMISSION_DENIED`

---

## 4. Cloud Functions (`functions/`)

### 4-1. 무엇을 확인해야 하는가

| 점검 항목 | 왜 중요한가 |
|-----------|------------|
| `npm install` 성공 | 의존성 문제 시 배포 실패 |
| Lint 통과 | 문법 오류 조기 발견 |
| 단위 테스트 통과 | 알림 페이로드 등 로직 검증 |
| Node.js 버전 일치 (20) | 로컬과 서버 런타임 불일치 시 동작 차이 |
| 에뮬레이터 동작 확인 | 실제 Firestore 트리거 이벤트 시뮬레이션 |

### 4-2. 점검 명령과 기대 결과

```bash
# 1단계: 의존성 설치
cd functions && npm ci

# 기대 결과: added XX packages
```

```bash
# 2단계: 문법 검증
npm run lint

# 기대 결과: (출력 없음 = 오류 없음)
```

```bash
# 3단계: 단위 테스트
npm test

# 기대 결과:
# ✓ 채팅 메시지 알림 페이로드
# ✓ 캘린더 이벤트 알림 페이로드
# ...
# X passing (Xms)
```

```bash
# 4단계: 에뮬레이터 동작 확인 (선택)
npm run serve
# → http://localhost:4000 에서 에뮬레이터 UI 확인

# 기대 결과: functions 에뮬레이터가 5개 함수를 로드함
```

```bash
# 5단계: Dry-run 배포 (실제 배포 없이 패키징까지만)
cd .. && firebase deploy --only functions --project=dongine-13214 --dry-run

# 기대 결과:
# ✔ functions: packaged functions/ (XX KB) for uploading
# i  functions: upload complete (dry run)
```

### 4-3. 배포 대상 함수 목록

| 함수 | 트리거 | 리전 |
|------|--------|------|
| `notifyOnChatMessageCreated` | Firestore `onCreate` — messages | asia-northeast3 |
| `notifyOnCalendarEventCreated` | Firestore `onCreate` — events | asia-northeast3 |
| `notifyOnTodoCreated` | Firestore `onCreate` — todos | asia-northeast3 |
| `notifyOnCartItemCreated` | Firestore `onCreate` — cart | asia-northeast3 |
| `notifyOnExpenseCreated` | Firestore `onCreate` — expenses | asia-northeast3 |

### 4-4. 로컬에만 있고 서버에 안 올라간 변경 예시

- `notification_payloads.js`에서 알림 제목 형식을 변경했지만 `firebase deploy --only functions`를 실행하지 않은 경우
- 새 함수 `notifyOnAlbumPhotoCreated`를 `index.js`에 추가했지만 배포 전이라 사진 업로드 시 알림이 안 옴
- `package.json`에 새 의존성을 추가했지만 배포하지 않아 서버에서 `MODULE_NOT_FOUND` 에러

---

## 5. 전체 배포 점검 순서 (요약)

아래 순서대로 진행하면 안전하게 배포할 수 있다.

```
1. firebase login:list          → 계정·권한 확인
2. firebase use dongine-13214   → 프로젝트 연결
3. git status / git diff        → 로컬 변경 사항 확인
4. firebase deploy --only firestore:rules  --dry-run  → 규칙 검증
5. firebase deploy --only firestore:indexes --dry-run  → 인덱스 검증
6. firebase deploy --only storage --dry-run             → 스토리지 규칙 검증
7. cd functions && npm ci && npm run lint && npm test    → 함수 로컬 검증
8. cd .. && firebase deploy --only functions --dry-run   → 함수 패키징 검증
9. (모두 통과하면) firebase deploy --project=dongine-13214  → 실제 배포
```

### 부분 배포가 필요한 경우

```bash
# 규칙만 배포
firebase deploy --only firestore:rules --project=dongine-13214

# 인덱스만 배포
firebase deploy --only firestore:indexes --project=dongine-13214

# 스토리지 규칙만 배포
firebase deploy --only storage --project=dongine-13214

# 함수만 배포
firebase deploy --only functions --project=dongine-13214
```

---

## 6. 배포 후 확인

| 확인 항목 | 방법 |
|-----------|------|
| Rules 반영 | Firebase Console > Firestore > Rules 탭에서 최종 수정 시각 확인 |
| Indexes 상태 | Firebase Console > Firestore > Indexes에서 `READY` 상태 확인 (빌드에 수 분 소요) |
| Storage Rules 반영 | Firebase Console > Storage > Rules 탭에서 최종 수정 시각 확인 |
| Functions 상태 | Firebase Console > Functions에서 5개 함수 활성 + 리전 `asia-northeast3` 확인 |
| 앱 동작 | 채팅 메시지를 보내고 다른 기기에서 푸시 알림이 오는지 확인 |
