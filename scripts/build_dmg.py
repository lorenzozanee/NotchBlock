#!/usr/bin/env python3
"""Build a NotchBlock DMG using dmgbuild.

dmgbuild writes .DS_Store directly (no Finder/AppleScript), so background
images, icon positions, and window layout are applied reliably every time.

Usage:
    python3 scripts/build_dmg.py              # full: build + sign + DMG
    python3 scripts/build_dmg.py --dmg-only   # DMG only (skip xcodebuild)
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
BUILD_DIR = PROJECT_DIR / "build"
STAGING_DIR = BUILD_DIR / "staging_dmg"
BACKGROUND_SRC = BUILD_DIR / "dmg_background.png"

WINDOW_RECT = ((400, 200), (640, 400))
ICON_SIZE = 80
TEXT_SIZE = 13


def run(cmd, **kwargs):
    """Run a command; print output. Exit on failure."""
    print(f"  → {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    result = subprocess.run(cmd, cwd=PROJECT_DIR, capture_output=True,
                            text=True, **kwargs)
    if result.returncode != 0:
        print(result.stderr)
        sys.exit(result.returncode)
    return result


def get_version():
    result = subprocess.run(
        ["git", "describe", "--tags", "--abbrev=0"],
        cwd=PROJECT_DIR, capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else "0.1.0"


def step_build():
    print("🔨 Building NotchBlock Release...")
    subprocess.run(
        ["xcodebuild", "-project", "NotchBlock.xcodeproj",
         "-scheme", "NotchBlock", "-configuration", "Release",
         "-derivedDataPath", str(BUILD_DIR), "build",
         "CODE_SIGN_IDENTITY=-",
         "CODE_SIGNING_REQUIRED=NO",
         "CODE_SIGNING_ALLOWED=NO"],
        cwd=PROJECT_DIR, check=True)
    print("   ✅ BUILD SUCCEEDED\n")


def find_app():
    products = BUILD_DIR / "Build" / "Products" / "Release"
    apps = list(products.glob("*.app"))
    if not apps:
        print(f"❌ No .app found in {products}")
        sys.exit(1)
    print(f"✅ App bundle: {apps[0]}")
    return apps[0]


def step_sign(app_path):
    print("🔐 Signing app...")
    entitlements = PROJECT_DIR / "entitlements.plist"
    subprocess.run(
        ["codesign", "--force", "--deep", "--sign", "-",
         "--options", "runtime",
         "--entitlements", str(entitlements),
         "--timestamp=none", str(app_path)],
        cwd=PROJECT_DIR, check=True)
    print("   ✅ Signed\n")


def step_background():
    print("🎨 Generating DMG background...")
    subprocess.run(
        [sys.executable, str(PROJECT_DIR / "scripts" / "generate_dmg_background.py")],
        cwd=PROJECT_DIR, check=True)
    if not BACKGROUND_SRC.exists():
        print("❌ Background generation failed")
        sys.exit(1)
    print()


def prepare_staging(app_path):
    print("📦 Preparing staging...")
    if STAGING_DIR.exists():
        shutil.rmtree(STAGING_DIR)
    STAGING_DIR.mkdir(parents=True)

    shutil.copytree(app_path, STAGING_DIR / "NotchBlock.app", symlinks=True)

    print(f"   Staged: NotchBlock.app\n")
    return STAGING_DIR


def build_dmg(staging_dir, version):
    print("📀 Creating DMG with dmgbuild...")
    dmg_path = BUILD_DIR / f"NotchBlock-{version}.dmg"
    if dmg_path.exists():
        dmg_path.unlink()

    settings = {
        "files": [str(staging_dir / "NotchBlock.app")],
        "symlinks": {"Applications": "/Applications"},
        "icon_locations": {
            "NotchBlock.app": (160, 100),
            "Applications": (480, 100),
        },
        "background": str(BACKGROUND_SRC),
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
    }

    import dmgbuild
    dmgbuild.build_dmg(
        filename=str(dmg_path),
        volume_name="NotchBlock",
        settings=settings,
    )
    return dmg_path


def main():
    parser = argparse.ArgumentParser(description="Build NotchBlock DMG")
    parser.add_argument("--dmg-only", action="store_true",
                        help="Skip xcodebuild, use existing build")
    args = parser.parse_args()

    version = get_version()
    print(f"📦 NotchBlock DMG Builder — {version}\n")

    if args.dmg_only:
        app_path = find_app()
    else:
        step_build()
        app_path = find_app()
        step_sign(app_path)

    step_background()
    staging = prepare_staging(app_path)
    dmg_path = build_dmg(staging, version)

    shutil.rmtree(staging, ignore_errors=True)

    size_kb = dmg_path.stat().st_size / 1024
    print(f"\n✅ DMG created: {dmg_path}")
    print(f"   Size: {size_kb:.0f} KB")
    print(f"\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"📦 安装流程")
    print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"   1. 将 NotchBlock 拖入 Applications")
    print(f"   2. 终端运行: xattr -cr /Applications/NotchBlock.app")
    print(f"   3. 打开 NotchBlock (或终端: open /Applications/NotchBlock.app)")
    print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")


if __name__ == "__main__":
    main()
