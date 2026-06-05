#!/usr/bin/env python3
"""Build NotchBlock DMG — clean, no hidden files, no background image."""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
BUILD_DIR = PROJECT_DIR / "build"
STAGING_DIR = BUILD_DIR / "staging_dmg"

WINDOW_RECT = ((400, 200), (500, 300))
ICON_SIZE = 80
TEXT_SIZE = 13


def run(cmd, **kw):
    r = subprocess.run(cmd, cwd=PROJECT_DIR, capture_output=True, text=True, **kw)
    if kw.get("check", True) and r.returncode != 0:
        print(r.stderr); sys.exit(r.returncode)
    return r


def get_version():
    r = run(["git", "describe", "--tags", "--abbrev=0"], check=False)
    return r.stdout.strip() if r.returncode == 0 else "0.1.0"


def step_build():
    print("🔨 Building...")
    subprocess.run([
        "xcodebuild", "-project", "NotchBlock.xcodeproj",
        "-scheme", "NotchBlock", "-configuration", "Release",
        "-derivedDataPath", str(BUILD_DIR), "build",
        "CODE_SIGN_IDENTITY=-", "CODE_SIGNING_REQUIRED=NO",
        "CODE_SIGNING_ALLOWED=NO",
    ], cwd=PROJECT_DIR, check=True)
    print("   ✅\n")


def find_app():
    apps = list((BUILD_DIR / "Build/Products/Release").glob("*.app"))
    if not apps: print("❌ No .app"); sys.exit(1)
    print(f"✅ {apps[0]}")
    return apps[0]


def step_sign(app):
    print("🔐 Signing...")
    e = PROJECT_DIR / "entitlements.plist"
    subprocess.run([
        "codesign", "--force", "--deep", "--sign", "-",
        "--options", "runtime", "--entitlements", str(e),
        "--timestamp=none", str(app),
    ], cwd=PROJECT_DIR, check=True)
    print("   ✅\n")


def prepare_staging(app):
    print("📦 Staging...")
    if STAGING_DIR.exists():
        shutil.rmtree(STAGING_DIR)
    STAGING_DIR.mkdir(parents=True)
    shutil.copytree(app, STAGING_DIR / "NotchBlock.app", symlinks=True)

    # Create install guide as a visible text file
    guide = """NotchBlock 安装说明

三步安装：

1. 将 NotchBlock.app 拖入 Applications 文件夹

2. 打开终端 (Terminal)，运行：
   xattr -cr /Applications/NotchBlock.app

3. 在 Applications 中打开 NotchBlock，
   或在终端运行: open /Applications/NotchBlock.app

---
未经 Apple 公证，首次打开需移除隔离标记。
"""
    (STAGING_DIR / "安装说明.txt").write_text(guide, encoding="utf-8")
    print("   ✅\n")
    return STAGING_DIR


def build_dmg(staging, version):
    import dmgbuild
    print("📀 Creating DMG...")
    p = BUILD_DIR / f"NotchBlock-{version}.dmg"
    if p.exists(): p.unlink()
    dmgbuild.build_dmg(
        filename=str(p), volume_name="NotchBlock",
        settings={
            "files": [
                str(staging / "NotchBlock.app"),
                str(staging / "安装说明.txt"),
            ],
            "symlinks": {"Applications": "/Applications"},
            "icon_locations": {
                "NotchBlock.app": (140, 90),
                "安装说明.txt": (260, 90),
                "Applications": (380, 90),
            },
            "window_rect": WINDOW_RECT,
            "default_view": "icon-view",
            "icon_size": ICON_SIZE,
            "text_size": TEXT_SIZE,
            "show_toolbar": False,
            "show_status_bar": False,
            "show_sidebar": False,
            "arrange_by": None,
            "format": "UDZO",
            "filesystem": "HFS+",
        },
    )
    return p


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dmg-only", action="store_true")
    a = p.parse_args()
    ver = get_version()
    print(f"📦 NotchBlock DMG — {ver}\n")

    if a.dmg_only:
        app = find_app()
    else:
        step_build(); app = find_app(); step_sign(app)

    staging = prepare_staging(app)
    dmg = build_dmg(staging, ver)
    shutil.rmtree(staging, ignore_errors=True)
    print(f"✅ {dmg} ({dmg.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
