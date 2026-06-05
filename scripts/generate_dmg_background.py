#!/usr/bin/env python3
"""Generate a minimal white-background DMG image with black Chinese text.

Layout: icons at top (icon zone), text at bottom (text zone). No overlap.
"""

import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W, H = 1280, 800  # @2x → 640×400 pt
DPI = (144, 144)


def find_cjk_font():
    candidates = [
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/PingFang.ttc",
    ]
    for c in candidates:
        if Path(c).exists():
            return c
    result = subprocess.run(
        ["find", "/System/Library/AssetsV2", "-name", "PingFang.ttc"],
        capture_output=True, text=True, timeout=5)
    for line in result.stdout.strip().split("\n"):
        if line:
            return line
    return None


def main():
    font_path = find_cjk_font()
    if font_path:
        f_step = ImageFont.truetype(font_path, 26)
        f_cmd = ImageFont.truetype(font_path, 22)
        f_small = ImageFont.truetype(font_path, 18)
        print(f"   Font: {font_path}")
    else:
        f_step = ImageFont.load_default()
        f_cmd = ImageFont.load_default()
        f_small = ImageFont.load_default()

    img = Image.new("RGB", (W, H), (255, 255, 255))
    draw = ImageDraw.Draw(img)

    BLACK = (0, 0, 0)
    GRAY = (120, 120, 125)
    LIGHT_GRAY = (180, 180, 185)

    # ── Icon zone hint: subtle arrow ──
    # Thin dashed guide from left icon area to right icon area
    arrow_y = 220  # px, center of icon zone
    left_x = 320   # px, right edge of left icon
    right_x = 960  # px, left edge of right icon
    for x in range(left_x, right_x, 16):
        draw.line([(x, arrow_y), (x + 8, arrow_y)], fill=(230, 230, 235), width=2)
    # Arrowhead
    draw.polygon(
        [(right_x - 10, arrow_y - 8), (right_x + 6, arrow_y),
         (right_x - 10, arrow_y + 8)],
        fill=(200, 200, 210))

    # ── Divider line between icon zone and text zone ──
    div_y = 520  # px = 260pt — well below icon labels
    draw.line([(160, div_y), (W - 160, div_y)], fill=(230, 230, 235), width=1)

    # ── Text zone (below divider) ──
    y = 580  # px = 290pt

    draw.text((W // 2, y),
              "1. 将 NotchBlock 拖入 Applications 文件夹",
              fill=BLACK, font=f_step, anchor="mm")

    y += 66
    draw.text((W // 2, y),
              "2. 打开终端 (Terminal)，运行以下命令：",
              fill=BLACK, font=f_step, anchor="mm")

    y += 52
    cmd = "xattr -cr /Applications/NotchBlock.app"
    bbox = draw.textbbox((0, 0), cmd, font=f_cmd)
    cw, ch = bbox[2] - bbox[0], bbox[3] - bbox[1]
    px, py = 28, 14
    draw.rounded_rectangle(
        (W // 2 - cw // 2 - px, y - ch // 2 - py,
         W // 2 + cw // 2 + px, y + ch // 2 + py),
        radius=8, fill=(248, 248, 250), outline=(218, 218, 222), width=1)
    draw.text((W // 2, y), cmd, fill=BLACK, font=f_cmd, anchor="mm")

    y += 66
    draw.text((W // 2, y),
              "3. 在 Applications 中打开 NotchBlock",
              fill=BLACK, font=f_step, anchor="mm")
    y += 38
    draw.text((W // 2, y),
              "或在终端运行: open /Applications/NotchBlock.app",
              fill=GRAY, font=f_cmd, anchor="mm")

    # ── Footer ──
    draw.text((W // 2, H - 40),
              "未经 Apple 公证 · 首次打开需移除隔离标记",
              fill=LIGHT_GRAY, font=f_small, anchor="mm")

    img.save("build/dmg_background.png", dpi=DPI)
    print(f"✅ Background: {W}×{H} px → build/dmg_background.png")


if __name__ == "__main__":
    main()
