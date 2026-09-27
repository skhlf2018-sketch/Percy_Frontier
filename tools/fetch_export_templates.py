#!/usr/bin/env python3
"""Godot 내보내기 템플릿 중 필요한 것만 받는다.

공식 템플릿 묶음(.tpz)은 모든 플랫폼을 담은 1.3GB 파일이라, HTTP 범위 요청으로
Windows·Linux 배포용 템플릿만 골라 받는다(약 70MB).

    python3 tools/fetch_export_templates.py [Godot 버전, 기본값 4.7.2]

받은 파일은 Godot가 찾는 템플릿 폴더(Linux: ~/.local/share/godot/export_templates/<버전>.stable)에 둔다.
"""
import io
import os
import platform
import ssl
import sys
import urllib.request
import zipfile

WANTED = [
    "templates/version.txt",
    "templates/windows_release_x86_64.exe",
    "templates/windows_release_x86_64_console.exe",
    "templates/linux_release.x86_64",
]


def template_dir(version: str) -> str:
    system = platform.system()
    if system == "Windows":
        base = os.path.join(os.environ["APPDATA"], "Godot")
    elif system == "Darwin":
        base = os.path.expanduser("~/Library/Application Support/Godot")
    else:
        base = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "godot")
    return os.path.join(base, "export_templates", f"{version}.stable")


def make_opener() -> urllib.request.OpenerDirector:
    cafile = os.environ.get("SSL_CERT_FILE")
    ctx = ssl.create_default_context(cafile=cafile) if cafile else ssl.create_default_context()
    return urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx))


class RangeFile(io.RawIOBase):
    """HTTP 범위 요청으로 원격 파일의 필요한 부분만 읽는 파일 객체."""

    def __init__(self, opener, url: str, size: int):
        self.opener, self.url, self.size, self.pos = opener, url, size, 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, offset, whence=0):
        if whence == 0:
            self.pos = offset
        elif whence == 1:
            self.pos += offset
        else:
            self.pos = self.size + offset
        return self.pos

    def readinto(self, buffer):
        n = min(len(buffer), self.size - self.pos)
        if n <= 0:
            return 0
        request = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{self.pos + n - 1}"})
        data = self.opener.open(request).read()
        buffer[: len(data)] = data
        self.pos += len(data)
        return len(data)


def main() -> int:
    version = sys.argv[1] if len(sys.argv) > 1 else "4.7.2"
    dest = template_dir(version)
    if all(os.path.exists(os.path.join(dest, os.path.basename(n))) for n in WANTED):
        print(f"템플릿이 이미 있습니다: {dest}")
        return 0
    os.makedirs(dest, exist_ok=True)
    url = (f"https://github.com/godotengine/godot/releases/download/{version}-stable/"
           f"Godot_v{version}-stable_export_templates.tpz")
    opener = make_opener()
    head = opener.open(urllib.request.Request(url, method="HEAD"))
    final_url, size = head.geturl(), int(head.headers["Content-Length"])
    archive = zipfile.ZipFile(io.BufferedReader(RangeFile(opener, final_url, size), buffer_size=1 << 20))
    for name in WANTED:
        target = os.path.join(dest, os.path.basename(name))
        with archive.open(name) as src, open(target + ".part", "wb") as dst:
            while chunk := src.read(8 << 20):
                dst.write(chunk)
        os.replace(target + ".part", target)
        print(f"받음: {os.path.basename(name)}")
    print(f"템플릿 폴더: {dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
