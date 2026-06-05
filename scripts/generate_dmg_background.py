#!/usr/bin/env python3
"""Generate a minimal white-background DMG image with black Chinese text.

Pure white · black text · vertical layout · no decorations.
Shows the Terminal command directly since .command files also get quarantined.
"""

import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W, H = 1280, 800
DPI = (144, 144)


def find_cjk_font():
    """Find a Chinese-capable font on macOS. Returns file path or None."""
    candidates = [
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/PingFang.ttc",
    ]
    for c in candidates:
        if Path(c).exists():
            return c

    # Search asset fonts
    result = subprocess.run(
        ["find", "/System/Library/AssetsV2", "-name", "PingFang.ttc"],
        capture_output=True, text=True, timeout=5)
    for line in result.stdout.strip().split("\n"):
        if line:
            return line

    # Search all ttc files for PingFang
    result = subprocess.run(
        ["find", "/System/Library/Fonts", "-name", "*.ttc"],
        capture_output=True, text=True, timeout=5)
    for line in result.stdout.strip().split("\n"):
        p = Path(line) if line else None
        if p and p.exists():
            try:
                ImageFont.truetype(str(p), 16)
                return str(p)
            except Exception:
                continue

    return None


def main():
    font_path = find_cjk_font()
    if font_path:
        f_title = ImageFont.truetype(font_path, 44)
        f_step = ImageFont.truetype(font_path, 28)
        f_cmd = ImageFont.truetype(font_path, 24)
        print(f"   Font: {font_path}")
    else:
        f_title = ImageFont.load_default()
        f_step = ImageFont.load_default()
        f_cmd = ImageFont.load_default()
        print("   Font: default (CJK may not render)")

    img = Image.new("RGB", (W, H), (255, 255, 255))
    draw = ImageDraw.Draw(img)

    BLACK = (0, 0, 0)
    GRAY = (100, 100, 105)

    # Title
    draw.text((W // 2, 100), "NotchBlock", fill=BLACK,
              font=f_title, anchor="mm")

    # Subtitle
    draw.text((W // 2, 160), "安装指南",
              fill=GRAY, font=f_step, anchor="mm")

    # Step 1
    y = 260
    draw.text((W // 2, y), "1. 将 NotchBlock 拖入 Applications 文件夹",
              fill=BLACK, font=f_step, anchor="mm")

    # Step 2 — show the actual Terminal command
    y += 80
    draw.text((W // 2, y), "2. 打开终端 (Terminal)，运行以下命令：",
              fill=BLACK, font=f_step, anchor="mm")

    y += 60
    # Command box — light gray bg
    cmd = "xattr -cr /Applications/NotchBlock.app"
    cmd_bbox = draw.textbbox((0, 0), cmd, font=f_cmd)
    cmd_w = cmd_bbox[2] - cmd_bbox[0]
    cmd_h = cmd_bbox[3] - cmd_bbox[1]
    pad_x, pad_y = 30, 16
    draw.rounded_rectangle(
        (W // 2 - cmd_w // 2 - pad_x, y - cmd_h // 2 - pad_y,
         W // 2 + cmd_w // 2 + pad_x, y + cmd_h // 2 + pad_y),
        radius=10,
        fill=(245, 245, 247),
        outline=(210, 210, 215),
        width=1,
    )
    draw.text((W // 2, y), cmd, fill=BLACK, font=f_cmd, anchor="mm")

    # Step 3
    y += 80
    draw.text((W // 2, y),
              "3. 在 Applications 中打开 NotchBlock",
              fill=BLACK, font=f_step, anchor="mm")
    y += 42
    draw.text((W // 2, y),
              "或在终端运行: open /Applications/NotchBlock.app",
              fill=GRAY, font=f_cmd, anchor="mm")

    # Footer
    y += 80
    draw.text((W // 2, y),
              "未经 Apple 公证 · 首次打开需移除隔离标记",
              fill=(170, 170, 175), font=f_cmd, anchor="mm")

    img.save("build/dmg_background.png", dpi=DPI)
    print(f"✅ Background: {W}×{H} px → build/dmg_background.png")


if __name__ == "__main__":
    main()
