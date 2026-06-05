#!/usr/bin/env python3
"""Generate a dead-simple white DMG background with black text, vertical layout."""

from PIL import Image, ImageDraw, ImageFont

W, H = 1280, 800  # @2x for 640×400 pt
DPI = (144, 144)


def main():
    img = Image.new("RGB", (W, H), (255, 255, 255))
    draw = ImageDraw.Draw(img)

    try:
        f_title = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 36)
        f_body = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 22)
    except OSError:
        f_title = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 36)
        f_body = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 22)

    BLACK = (0, 0, 0)

    # Title
    draw.text((W // 2, 80), "NotchBlock", fill=BLACK, font=f_title, anchor="mm")

    # Vertical instructions
    lines = [
        "1. 将 NotchBlock 拖入 Applications 文件夹",
        "2. 双击 FixQuarantine.command 移除隔离",
        "3. 从 Applications 打开 NotchBlock",
    ]
    start_y = 200
    line_spacing = 60
    for i, line in enumerate(lines):
        y = start_y + i * line_spacing
        draw.text((W // 2, y), line, fill=BLACK, font=f_body, anchor="mm")

    img.save("build/dmg_background.png", dpi=DPI)
    print(f"✅ Background: {W}×{H} px → build/dmg_background.png")


if __name__ == "__main__":
    main()
