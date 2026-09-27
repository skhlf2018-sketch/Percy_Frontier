#!/usr/bin/env bash
# 배포용 빌드 만들기.
#   tools/export.sh    → build/PercyFrontier-<버전>-windows-x64.zip
# 1) 필요한 내보내기 템플릿만 받고  2) Linux 점검 빌드로 배포용 엔진에서 게임을 자동으로 돌려 보고
# 3) Windows 빌드를 만들어 안내 문서와 함께 압축한다. 점검에 실패하면 Windows 빌드를 만들지 않는다.
# Godot 실행 파일 경로는 GODOT 환경 변수로 바꿀 수 있다(기본값: godot).
set -euo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
GODOT_VERSION="$("$GODOT" --version | sed -E 's/^([0-9]+\.[0-9]+(\.[0-9]+)?)\..*/\1/')"

python3 tools/fetch_export_templates.py "$GODOT_VERSION"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

rm -rf build/smoke build/windows
mkdir -p build/smoke build/windows

echo "== 점검 빌드(Linux)"
"$GODOT" --headless --path . --export-release "Linux 점검" build/smoke/PercyFrontierSmoke.x86_64 >/dev/null 2>&1
test -f build/smoke/PercyFrontierSmoke.x86_64
timeout 600 build/smoke/PercyFrontierSmoke.x86_64 --headless --fixed-fps 60

echo "== Windows 빌드"
"$GODOT" --headless --path . --export-release "Windows" build/windows/PercyFrontier.exe >/dev/null 2>&1
test -f build/windows/PercyFrontier.exe

PACKAGE="PercyFrontier-$VERSION"
STAGE="build/package/$PACKAGE"
rm -rf build/package
mkdir -p "$STAGE"
cp build/windows/PercyFrontier.exe "$STAGE/"
# 메모장에서 바로 읽히도록 UTF-8(BOM)·CRLF로 저장한다.
{ printf '\xef\xbb\xbf'; sed "s/{VERSION}/$VERSION/g; s/\$/\r/" tools/package/README.txt; } > "$STAGE/README.txt"
cp assets/fonts/Pretendard-OFL.txt "$STAGE/LICENSE-Pretendard.txt"
ZIP="build/$PACKAGE-windows-x64.zip"
rm -f "$ZIP"
(cd build/package && zip -q -9 -r "../$PACKAGE-windows-x64.zip" "$PACKAGE")
ls -la "$ZIP"
