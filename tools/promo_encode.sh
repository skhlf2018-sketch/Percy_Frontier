#!/usr/bin/env bash
# 찍은 홍보 영상(AVI)에 배경 음악을 섞어 MP4로 만든다.
#   tools/promo_encode.sh <찍은.avi> <찍을 때의 로그> <fps> <출력.mp4> [목표 크기 MB(주면 2패스로 맞춘다)]
# 음악은 로그의 "PROMO_SCENE 번호 프레임"에 맞춰 tools/promo_music.py가 합성한다.
# ffmpeg가 PATH에 없으면 FFMPEG 환경 변수로 실행 파일을 알려 준다.
# VCODEC=av1이면 AV1로 만든다(같은 크기에서 H.264보다 훨씬 선명하다. 파일 한 개 30MB 한도에 고화질을 담을 때).
set -euo pipefail
cd "$(dirname "$0")/.."
avi="$1"; log="$2"; fps="$3"; out="$4"; target_mb="${5:-}"
ff="${FFMPEG:-ffmpeg}"
vcodec="${VCODEC:-h264}"
if [ "$vcodec" = "av1" ]; then
	venc=(-c:v libaom-av1 -cpu-used 4 -row-mt 1 -tiles 2x2 -g 240)
else
	venc=(-c:v libx264 -preset slow)
fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
marks="$(grep -E '^PROMO_SCENE [0-9]+ ' "$log" | awk -v fps="$fps" '{printf "%s%d:%.3f", (n++ ? "," : ""), $2, $3 / fps}')"
frames="$(grep -E '^PROMO_SCENE end ' "$log" | awk '{print $3}')"
length="$(awk -v f="$frames" -v fps="$fps" 'BEGIN {printf "%.3f", f / fps}')"
echo "장면: $marks / 길이 ${length}초"
python3 -I tools/promo_music.py "$work/music.wav" "$length" "$marks"
fade_out="$(awk -v l="$length" 'BEGIN {printf "%.3f", l - 1.2}')"
filter="[0:v]scale=1280:720:flags=lanczos,fade=t=in:st=0:d=0.8,fade=t=out:st=${fade_out}:d=1.2,format=yuv420p[v];\
[0:a]volume=0.8[g];[1:a]volume=0.75[m];[g][m]amix=inputs=2:duration=first:normalize=0,alimiter=limit=0.95,\
afade=t=in:st=0:d=0.8,afade=t=out:st=${fade_out}:d=1.2[a]"
if [ -z "$target_mb" ]; then
	"$ff" -y -hide_banner -loglevel error -i "$avi" -i "$work/music.wav" -filter_complex "$filter" -map "[v]" -map "[a]" \
		-c:v libx264 -preset slow -crf 19 -c:a aac -b:a 192k -movflags +faststart "$out"
else
	kbps="$(awk -v mb="$target_mb" -v l="$length" 'BEGIN {printf "%d", mb * 8192 / l - 128}')"
	echo "목표 ${target_mb}MB → 영상 ${kbps}kbps"
	"$ff" -y -hide_banner -loglevel error -i "$avi" -i "$work/music.wav" -filter_complex "$filter" -map "[v]" -map "[a]" \
		"${venc[@]}" -b:v "${kbps}k" -pass 1 -passlogfile "$work/pass" -an -f mp4 /dev/null
	"$ff" -y -hide_banner -loglevel error -i "$avi" -i "$work/music.wav" -filter_complex "$filter" -map "[v]" -map "[a]" \
		"${venc[@]}" -b:v "${kbps}k" -pass 2 -passlogfile "$work/pass" -c:a aac -b:a 112k -movflags +faststart "$out"
fi
ls -la "$out"
