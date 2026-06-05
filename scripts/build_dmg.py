#!/usr/bin/env python3
"""Build a NotchBlock DMG using dmgbuild + post-processing to hide background."""

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
    print(f"  → {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    r = subprocess.run(cmd, cwd=PROJECT_DIR, capture_output=True, text=True, **kwargs)
    if kwargs.get("check", True) and r.returncode != 0:
        print(r.stderr)
        sys.exit(r.returncode)
    return r


def get_version():
    r = run(["git", "describe", "--tags", "--abbrev=0"], check=False)
    return r.stdout.strip() if r.returncode == 0 else "0.1.0"


def step_build():
    print("🔨 Building Release...")
    subprocess.run(
        ["xcodebuild", "-project", "NotchBlock.xcodeproj",
         "-scheme", "NotchBlock", "-configuration", "Release",
         "-derivedDataPath", str(BUILD_DIR), "build",
         "CODE_SIGN_IDENTITY=-", "CODE_SIGNING_REQUIRED=NO",
         "CODE_SIGNING_ALLOWED=NO"],
        cwd=PROJECT_DIR, check=True)
    print("   ✅ BUILD SUCCEEDED\n")


def find_app():
    apps = list((BUILD_DIR / "Build/Products/Release").glob("*.app"))
    if not apps:
        print("❌ No .app found")
        sys.exit(1)
    print(f"✅ App: {apps[0]}")
    return apps[0]


def step_sign(app_path):
    print("🔐 Signing...")
    ent = PROJECT_DIR / "entitlements.plist"
    subprocess.run([
        "codesign", "--force", "--deep", "--sign", "-",
        "--options", "runtime", "--entitlements", str(ent),
        "--timestamp=none", str(app_path),
    ], cwd=PROJECT_DIR, check=True)
    print("   ✅ Signed\n")


def step_background():
    print("🎨 Background...")
    subprocess.run([
        sys.executable,
        str(PROJECT_DIR / "scripts/generate_dmg_background.py"),
    ], cwd=PROJECT_DIR, check=True)
    assert BACKGROUND_SRC.exists()
    print()


def prepare_staging(app_path):
    print("📦 Staging...")
    if STAGING_DIR.exists():
        shutil.rmtree(STAGING_DIR)
    STAGING_DIR.mkdir(parents=True)
    shutil.copytree(app_path, STAGING_DIR / "NotchBlock.app", symlinks=True)
    print("   ✅ NotchBlock.app\n")
    return STAGING_DIR


def hide_background_in_dmg(dmg_path):
    """Mount DMG, set invisible flag on .background.png, unmount."""
    print("👻 Hiding background file...")

    # Convert to writable
    tmp = BUILD_DIR / "NotchBlock-tmp.dmg"
    if tmp.exists():
        tmp.unlink()
    run(["hdiutil", "convert", str(dmg_path), "-format", "UDRW", "-o", str(tmp)])

    # Mount
    r = run(["hdiutil", "attach", str(tmp), "-readwrite",
             "-noverify", "-noautoopen"])
    mp = None
    for line in r.stdout.split("\n"):
        if "Apple_HFS" in line:
            mp = line.split("\t")[-1].strip()
            break
    assert mp, "Mount failed"

    # Hide
    bg = Path(mp) / ".background.png"
    assert bg.exists(), f"No .background.png at {bg}"
    run(["SetFile", "-a", "V", str(bg)])

    # Unmount
    run(["hdiutil", "detach", mp, "-force"])

    # Re-compress
    if dmg_path.exists():
        dmg_path.unlink()
    run(["hdiutil", "convert", str(tmp), "-format", "UDZO",
         "-imagekey", "zlib-level=9", "-o", str(dmg_path)])
    tmp.unlink()
    print("   ✅ Hidden\n")


def build_dmg(staging_dir, version):
    import dmgbuild

    print("📀 Creating DMG...")
    dmg_path = BUILD_DIR / f"NotchBlock-{version}.dmg"
    if dmg_path.exists():
        dmg_path.unlink()

    dmgbuild.build_dmg(
        filename=str(dmg_path),
        volume_name="NotchBlock",
        settings={
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
        },
    )

    # Post-process: properly hide background file
    hide_background_in_dmg(dmg_path)

    return dmg_path


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dmg-only", action="store_true")
    a = p.parse_args()

    ver = get_version()
    print(f"📦 NotchBlock DMG Builder — {ver}\n")

    if a.dmg_only:
        app = find_app()
    else:
        step_build()
        app = find_app()
        step_sign(app)

    step_background()
    staging = prepare_staging(app)
    dmg = build_dmg(staging, ver)
    shutil.rmtree(staging, ignore_errors=True)

    kb = dmg.stat().st_size / 1024
    print(f"✅ {dmg} ({kb:.0f} KB)")
    print(f"   1. 拖入 Applications")
    print(f"   2. 终端: xattr -cr /Applications/NotchBlock.app")
    print(f"   3. open /Applications/NotchBlock.app")


if __name__ == "__main__":
    main()
