#!/usr/bin/env python3
"""Generate a minimal, clean DMG background image for NotchBlock.

Design:
  - 1200×840 px @144 DPI → 600×420 pt DMG window (Retina)
  - Dark gradient background with subtle indigo accent
  - Curved guide arrow from app zone (left) to Applications zone (right)
  - Minimal text: step 1 hint, step 2 label for the .command script

The background image is placed inside the DMG (hidden) and set via AppleScript.
Icons (NotchBlock.app, Applications alias, FixQuarantine.command) are positioned
on top by Finder — the background only provides visual decoration.
"""

import math
from PIL import Image, ImageDraw, ImageFont

# ── Dimensions ──────────────────────────────────────────────
W, H = 1200, 840  # @2x for 600×420 pt window
DPI = (144, 144)

# ── Colors ──────────────────────────────────────────────────
BG_TOP = (38, 38, 44)        # dark charcoal
BG_BOT = (28, 28, 34)        # deeper charcoal
ACCENT = (79, 70, 229)       # indigo #4F46E5
TEXT_PRIMARY = (220, 220, 228)
TEXT_SECONDARY = (140, 140, 152)


def vertical_gradient(draw, w, h, top, bottom):
    """Draw a vertical linear gradient from top to bottom."""
    for y in range(h):
        t = y / h
        r = int(top[0] + (bottom[0] - top[0]) * t)
        g = int(top[1] + (bottom[1] - top[1]) * t)
        b = int(top[2] + (bottom[2] - top[2]) * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b))


def rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    """Draw a rounded rectangle."""
    draw.rounded_rectangle(xy, radius=radius, fill=fill,
                           outline=outline, width=width)


def main():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ── Background gradient ──
    vertical_gradient(draw, W, H, BG_TOP, BG_BOT)

    # ── Subtle indigo glow at top-center ──
    for r in range(180, 0, -1):
        alpha = int(4 * (r / 180))
        draw.ellipse(
            [(W // 2 - r, -r), (W // 2 + r, r)],
            fill=(*ACCENT[:3], alpha),
        )

    # ── Thin accent line near top ──
    line_y = 50
    for i in range(W // 2 - 100, W // 2 + 100):
        alpha = int(50 * (1 - abs(i - W // 2) / 100))
        draw.line([(i, line_y), (i + 1, line_y)],
                  fill=(*ACCENT[:3], alpha), width=1)

    # ── Icon drop zones — soft rounded squares ──
    zone_size = 180
    for zx, zy in [(240, 360), (960, 360)]:
        rounded_rect(
            draw,
            (zx - zone_size // 2, zy - zone_size // 2,
             zx + zone_size // 2, zy + zone_size // 2),
            radius=24,
            outline=(*ACCENT[:3], 18),
            width=2,
        )

    # ── Guide chevrons (>>>) between the two zones ──
    arrow_start_x = 240 + zone_size // 2 + 30
    arrow_end_x = 960 - zone_size // 2 - 30
    arrow_y = 340
    chevron_count = 3
    for ch in range(chevron_count):
        t = (ch + 1) / (chevron_count + 1)
        cx = arrow_start_x + (arrow_end_x - arrow_start_x) * t
        cy = arrow_y
        sz = 10
        alpha = int(100 + 60 * t)
        pts = [
            (cx - sz, cy - sz * 1.2),
            (cx + sz * 0.5, cy),
            (cx - sz, cy + sz * 1.2),
        ]
        draw.polygon(pts, fill=(*ACCENT[:3], alpha))

    # ── Text ──
    try:
        font_large = ImageFont.truetype(
            "/System/Library/Fonts/PingFang.ttc", 32)
        font_medium = ImageFont.truetype(
            "/System/Library/Fonts/PingFang.ttc", 24)
        font_small = ImageFont.truetype(
            "/System/Library/Fonts/PingFang.ttc", 18)
    except (OSError, IOError):
        try:
            font_large = ImageFont.truetype(
                "/System/Library/Fonts/Helvetica.ttc", 32)
            font_medium = ImageFont.truetype(
                "/System/Library/Fonts/Helvetica.ttc", 24)
            font_small = ImageFont.truetype(
                "/System/Library/Fonts/Helvetica.ttc", 18)
        except (OSError, IOError):
            font_large = ImageFont.load_default()
            font_medium = ImageFont.load_default()
            font_small = ImageFont.load_default()

    # App name
    draw.text((W // 2, 110), "NotchBlock",
              fill=TEXT_PRIMARY, font=font_large, anchor="mm")

    # Subtitle
    draw.text((W // 2, 155), "将 Mac 刘海转化为时间管理入口",
              fill=TEXT_SECONDARY, font=font_small, anchor="mm")

    # Zone hint below app icon zone
    draw.text((240, 360 + zone_size // 2 + 30),
              "拖入 Applications",
              fill=TEXT_SECONDARY, font=font_small, anchor="mt")

    # ── Step indicators at bottom (stacked: circle + text below) ──
    steps_y = 540
    steps = [
        ("1", "拖入 Applications"),
        ("2", "双击 FixQuarantine.command"),
        ("3", "打开 NotchBlock"),
    ]

    for i, (num, desc) in enumerate(steps):
        sx = 200 + i * 400
        # Number circle
        cr = 18
        draw.ellipse(
            [(sx - cr, steps_y - cr),
             (sx + cr, steps_y + cr)],
            fill=(*ACCENT[:3], 180),
        )
        draw.text((sx, steps_y), num,
                  fill=(255, 255, 255), font=font_small, anchor="mm")
        # Description text BELOW the circle
        text_y = steps_y + cr + 14
        draw.text((sx, text_y), desc,
                  fill=TEXT_PRIMARY,
                  font=font_small, anchor="mt")

    # ── Bottom accent ──
    for i in range(W):
        alpha = int(8 * (1 - abs(i - W // 2) / (W // 2)))
        draw.line([(i, H - 1), (i + 1, H - 1)],
                  fill=(*ACCENT[:3], alpha), width=1)

    # ── Save ──
    img.save("build/dmg_background.png", dpi=DPI)
    print(f"✅ DMG background saved to build/dmg_background.png")
    print(f"   {W}×{H} px @ {DPI[0]} DPI")


if __name__ == "__main__":
    main()
