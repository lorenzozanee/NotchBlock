#!/usr/bin/env python3
"""Generate a minimal NotchBlock DMG background image.

Design goals:
  - Clean, minimal — no unnecessary elements
  - Dark gradient background matching macOS aesthetic
  - Subtle indigo accent (#4F46E5)
  - Visual guide: app icon zone → arrow → Applications zone
  - Small step hints for the 3-step install flow
  - 1280×800 px @144 DPI → 640×400 pt window (Retina)

This is used by build_dmg.py which writes .DS_Store directly via dmgbuild,
avoiding the unreliable AppleScript/Finder approach entirely.
"""

from PIL import Image, ImageDraw, ImageFont

# ── Dimensions ──────────────────────────────────────────────────
W, H = 1280, 800  # @2x for 640×400 pt window
DPI = (144, 144)

# ── Colors ──────────────────────────────────────────────────────
BG_TOP = (32, 32, 38)
BG_BOT = (22, 22, 28)
ACCENT = (79, 70, 229)       # #4F46E5 indigo
TEXT_PRIMARY = (210, 210, 220)
TEXT_SECONDARY = (130, 130, 145)
ZONE_OUTLINE = (79, 70, 229, 12)


def gradient(draw, w, h, top, bottom):
    """Vertical linear gradient."""
    for y in range(h):
        t = y / h
        r = int(top[0] + (bottom[0] - top[0]) * t)
        g = int(top[1] + (bottom[1] - top[1]) * t)
        b = int(top[2] + (bottom[2] - top[2]) * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b))


def main():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background
    gradient(draw, W, H, BG_TOP, BG_BOT)

    # Thin accent line at top
    top_y = 46
    for x in range(W // 2 - 80, W // 2 + 80):
        a = int(40 * (1 - abs(x - W // 2) / 80))
        draw.line([(x, top_y), (x + 1, top_y)], fill=(*ACCENT[:3], a), width=1)

    # ── Two icon drop zones ──────────────────────────────────
    zone_size = 192
    zones = [(260, 320), (1020, 320)]  # left (app), right (Applications)

    for zx, zy in zones:
        draw.rounded_rectangle(
            (zx - zone_size // 2, zy - zone_size // 2,
             zx + zone_size // 2, zy + zone_size // 2),
            radius=28,
            outline=ZONE_OUTLINE,
            width=2,
        )

    # ── Guide chevrons between zones ──────────────────────────
    left_edge = zones[0][0] + zone_size // 2 + 40
    right_edge = zones[1][0] - zone_size // 2 - 40
    chev_y = zones[0][1]
    for i in range(3):
        t = (i + 1) / 4
        cx = left_edge + (right_edge - left_edge) * t
        sz = 12
        a = int(80 + 70 * t)
        pts = [
            (cx - sz, chev_y - sz * 1.2),
            (cx + sz * 0.6, chev_y),
            (cx - sz, chev_y + sz * 1.2),
        ]
        draw.polygon(pts, fill=(*ACCENT[:3], a))

    # ── Fonts ─────────────────────────────────────────────────
    try:
        f_title = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 34)
        f_body = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 20)
        f_small = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 16)
    except OSError:
        f_title = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 34)
        f_body = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 20)
        f_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 16)

    # App name centered
    draw.text((W // 2, 105), "NotchBlock",
              fill=TEXT_PRIMARY, font=f_title, anchor="mm")

    # Subtitle
    draw.text((W // 2, 148), "刘海时间块 · macOS 专注工具",
              fill=TEXT_SECONDARY, font=f_small, anchor="mm")

    # Zone labels (below each zone)
    draw.text((260, 320 + zone_size // 2 + 22), "拖入 Applications",
              fill=TEXT_SECONDARY, font=f_small, anchor="mt")
    draw.text((1020, 320 + zone_size // 2 + 22), "快捷方式",
              fill=TEXT_SECONDARY, font=f_small, anchor="mt")

    # ── Install steps at bottom ────────────────────────────────
    step_y = 600
    steps = [
        ("1", "拖入 Applications"),
        ("2", "双击 FixQuarantine.command"),
        ("3", "从 Applications 打开"),
    ]
    for i, (num, desc) in enumerate(steps):
        sx = 250 + i * 390
        # Circle with number
        cr = 16
        draw.ellipse(
            [(sx - cr, step_y - cr), (sx + cr, step_y + cr)],
            fill=(*ACCENT[:3], 180),
        )
        draw.text((sx, step_y), num, fill=(255, 255, 255),
                  font=f_small, anchor="mm")
        draw.text((sx, step_y + cr + 12), desc,
                  fill=TEXT_PRIMARY, font=f_small, anchor="mt")

    # ── Bottom accent stripe ───────────────────────────────────
    for x in range(W):
        a = int(6 * (1 - abs(x - W // 2) / (W // 2)))
        draw.line([(x, H - 1), (x + 1, H - 1)],
                  fill=(*ACCENT[:3], a), width=1)

    img.save("build/dmg_background.png", dpi=DPI)
    print(f"✅ Background: {W}×{H} px @ {DPI[0]} DPI → build/dmg_background.png")


if __name__ == "__main__":
    main()
