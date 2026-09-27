#!/usr/bin/env bash
# 헤드리스 테스트 실행.
#   tools/run_tests.sh              전체 테스트
#   tools/run_tests.sh 이름일부     파일·테스트 이름에 포함된 것만 실행 (예: test_combat_sandbox)
#   tools/run_tests.sh --import-only  리소스 가져오기만 실행
# Godot 실행 파일 경로는 GODOT 환경 변수로 바꿀 수 있다(기본값: godot).
set -euo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

# 새로 받은 저장소에는 class_name 캐시와 가져온 리소스가 없으므로 먼저 가져오기를 실행한다.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

if [ "${1:-}" = "--import-only" ]; then
  exit 0
fi

if [ $# -gt 0 ]; then
  exec "$GODOT" --headless --path . --fixed-fps 60 res://tests/test_runner.tscn -- --filter="$1"
fi
exec "$GODOT" --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
