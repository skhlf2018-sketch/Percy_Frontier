#!/usr/bin/env bash
# 화면 확인용 스크린샷 투어(가상 디스플레이 필요: xvfb-run).
#   tools/screenshots.sh [출력 폴더]   기본값: tools/out/screenshots
# Forward+ 렌더러를 쓰려면 Vulkan 드라이버가 필요하다(GPU가 없으면 Mesa lavapipe).
set -euo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
OUT="$(realpath -m "${1:-tools/out/screenshots}")"
mkdir -p "$OUT"

"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
xvfb-run -a -s "-screen 0 1600x900x24" "$GODOT" --path . --rendering-driver vulkan \
  --rendering-method forward_plus --resolution 1600x900 --fixed-fps 60 \
  res://tools/screenshot_tour.tscn -- --out="$OUT"
echo "스크린샷: $OUT"
