#!/usr/bin/env bash
# preflight.sh — 빌드 전 수동 입력 항목 점검 스크립트
# 읽기 전용: 파일·값을 자동 수정하지 않으며 존재 여부와 placeholder 상태만 확인합니다.
set -euo pipefail

# ── 프로젝트 루트 결정 ──────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
WARN=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { WARN=$((WARN + 1)); printf '  \033[33m⚠\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %s\n' "$1"; }

# ── 1. Firebase 설정 파일 ────────────────────────────────────────
echo ""
echo "=== Firebase 설정 파일 ==="

if [ -f "$PROJECT_ROOT/android/app/google-services.json" ]; then
  pass "android/app/google-services.json 존재"
else
  fail "android/app/google-services.json 없음"
fi

if [ -f "$PROJECT_ROOT/ios/Runner/GoogleService-Info.plist" ]; then
  pass "ios/Runner/GoogleService-Info.plist 존재"
else
  fail "ios/Runner/GoogleService-Info.plist 없음"
fi

if [ -f "$PROJECT_ROOT/lib/firebase_options.dart" ]; then
  pass "lib/firebase_options.dart 존재"
else
  fail "lib/firebase_options.dart 없음 (flutterfire configure 필요)"
fi

# ── 2. 네이버맵 Client ID placeholder ───────────────────────────
echo ""
echo "=== 네이버맵 Client ID ==="

check_naver_placeholder() {
  local file="$1"
  local label="$2"
  if [ ! -f "$PROJECT_ROOT/$file" ]; then
    warn "$label — 파일 자체가 없음 ($file)"
    return
  fi
  if grep -Fq 'YOUR_NAVER_MAP_CLIENT_ID' "$PROJECT_ROOT/$file"; then
    fail "$label — placeholder 상태 ($file)"
  else
    pass "$label — 실제 값 설정됨 ($file)"
  fi
}

check_naver_placeholder "android/gradle.properties"       "Android"
check_naver_placeholder "ios/Flutter/Debug.xcconfig"       "iOS Debug"
check_naver_placeholder "ios/Flutter/Release.xcconfig"     "iOS Release"

# ── 3. Android key.properties ────────────────────────────────────
echo ""
echo "=== Android Release Signing ==="

if [ -f "$PROJECT_ROOT/android/key.properties" ]; then
  pass "android/key.properties 존재"
else
  warn "android/key.properties 없음 (release 빌드에 필요)"
fi

# ── 결과 요약 ────────────────────────────────────────────────────
TOTAL=$((PASS + WARN + FAIL))
echo ""
echo "=== 결과 요약 ==="
printf '  통과: %d / %d\n' "$PASS" "$TOTAL"
printf '  경고: %d / %d\n' "$WARN" "$TOTAL"
printf '  실패: %d / %d\n' "$FAIL" "$TOTAL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "빌드 전에 실패 항목을 해결하세요."
  echo "상세 가이드: doc/manual-build-inputs.md"
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo "경고 항목이 있습니다. 필요 시 확인하세요."
  exit 0
else
  echo "모든 항목이 준비되었습니다."
  exit 0
fi
