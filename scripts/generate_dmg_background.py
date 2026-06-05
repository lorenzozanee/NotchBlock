#!/usr/bin/env python3
"""Minimal DMG background — white, black text, compact layout."""

import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W, H = 1280, 760
DPI = (144, 144)


def find_cjk_font():
    for c in ["/System/Library/Fonts/STHeiti Medium.ttc",
              "/System/Library/Fonts/PingFang.ttc"]:
        if Path(c).exists():
            return c
    r = subprocess.run(
        ["find", "/System/Library/AssetsV2", "-name", "PingFang.ttc"],
        capture_output=True, text=True, timeout=5)
    for line in r.stdout.strip().split("\n"):
        if line:
            return line
    return None


def main():
    fp = find_cjk_font()
    f_step = ImageFont.truetype(fp, 24) if fp else ImageFont.load_default()
    f_cmd = ImageFont.truetype(fp, 20) if fp else ImageFont.load_default()
    f_small = ImageFont.truetype(fp, 16) if fp else ImageFont.load_default()
    print(f"   Font: {fp}")

    img = Image.new("RGB", (W, H), (255, 255, 255))
    d = ImageDraw.Draw(img)
    B = (0, 0, 0)
    G = (120, 120, 125)
    LG = (190, 190, 195)

    # Arrow between icons at y=180px (90pt)
    ax1, ax2, ay = 520, 760, 180
    x = ax1
    while x < ax2:
        xe = min(x + 10, ax2)
        d.line([(x, ay), (xe, ay)], fill=(220, 220, 225), width=2)
        x += 18
    d.polygon(
        [(ax2 - 12, ay - 8), (ax2 + 6, ay), (ax2 - 12, ay + 8)],
        fill=(200, 200, 210))

    # Divider just below icon labels
    div_y = 330
    d.line([(140, div_y), (W - 140, div_y)], fill=(235, 235, 240), width=1)

    # Text — compact, close to icons
    y = 390
    d.text((W // 2, y),
           "1. 将 NotchBlock 拖入 Applications 文件夹",
           fill=B, font=f_step, anchor="mm")
    y += 56
    d.text((W // 2, y),
           "2. 打开终端 (Terminal)，运行以下命令：",
           fill=B, font=f_step, anchor="mm")
    y += 46
    cmd = "xattr -cr /Applications/NotchBlock.app"
    bb = d.textbbox((0, 0), cmd, font=f_cmd)
    cw, ch = bb[2] - bb[0], bb[3] - bb[1]
    px, py = 24, 12
    d.rounded_rectangle(
        (W // 2 - cw // 2 - px, y - ch // 2 - py,
         W // 2 + cw // 2 + px, y + ch // 2 + py),
        radius=8, fill=(248, 248, 250), outline=(218, 218, 222), width=1)
    d.text((W // 2, y), cmd, fill=B, font=f_cmd, anchor="mm")
    y += 56
    d.text((W // 2, y),
           "3. 在 Applications 中打开 NotchBlock",
           fill=B, font=f_step, anchor="mm")
    y += 36
    d.text((W // 2, y),
           "或在终端运行: open /Applications/NotchBlock.app",
           fill=G, font=f_cmd, anchor="mm")

    d.text((W // 2, H - 36),
           "未经 Apple 公证 · 首次打开需移除隔离标记",
           fill=LG, font=f_small, anchor="mm")

    img.save("build/dmg_background.png", dpi=DPI)
    print(f"✅ {W}×{H} px → build/dmg_background.png")


if __name__ == "__main__":
    main()
