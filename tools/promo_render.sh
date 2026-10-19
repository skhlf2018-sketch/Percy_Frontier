#!/usr/bin/env bash
# 홍보 영상 장면을 찍는다(Godot 동영상 기록, MJPEG AVI + 소리).
#   tools/promo_render.sh <출력.avi> <가로x세로> <fps> <그래픽 품질 0~3> [장면 번호,번호]
# 영상 크기는 창 크기를 따르는데 프로젝트 설정의 창 크기가 --resolution보다 앞서므로,
# 찍는 동안만 override.cfg로 창 크기와 MJPEG 화질을 바꾸고 끝나면 지운다.
set -euo pipefail
cd "$(dirname "$0")/.."
out="$1"; size="$2"; fps="$3"; quality="$4"; only="${5:-}"
w="${size%x*}"; h="${size#*x}"
if [ -e override.cfg ]; then echo "override.cfg가 이미 있습니다. 지우고 다시 실행하세요." >&2; exit 1; fi
cat > override.cfg <<CFG
[display]

window/size/window_width_override=$w
window/size/window_height_override=$h

[editor]

movie_writer/mjpeg_quality=0.93
CFG
trap 'rm -f override.cfg' EXIT
args=(--quality="$quality")
[ -n "$only" ] && args+=(--only="$only")
xvfb-run -a -s "-screen 0 ${w}x${h}x24" godot --path . --write-movie "$out" --fixed-fps "$fps" \
	res://tools/promo_video.tscn -- "${args[@]}"
