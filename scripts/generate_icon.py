#!/usr/bin/env python3
"""
NotchBlock App Icon Generator
Generates a professional macOS app icon programmatically.

Design: Dark gradient bg + stylized notch + focus block + pause symbol
"""

import math
import os
from PIL import Image, ImageDraw


def generate_master_icon(size=1024):
    """Generate the master app icon."""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # === 1. Dark gradient background ===
    for y in range(size):
        t = y / size
        r = int(28 - t * 8)
        g = int(28 - t * 5)
        b = int(35 - t * 5)
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))

    # === 2. Top-center radial glow ===
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    cx, cy = size // 2, int(size * 0.28)
    max_radius = int(size * 0.55)
    for r in range(max_radius, 0, -1):
        alpha = int(25 * (1 - r / max_radius) ** 2)
        glow_draw.ellipse(
            [(cx - r, cy - r), (cx + r, cy + r)],
            fill=(100, 140, 220, alpha)
        )
    img = Image.alpha_composite(img, glow)

    # === 3. Notch silhouette at top center ===
    notch_w = int(size * 0.22)
    notch_h = int(size * 0.06)
    notch_x = (size - notch_w) // 2
    notch_y = int(size * 0.12)
    notch_radius = int(notch_h * 0.8)

    notch_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    notch_draw = ImageDraw.Draw(notch_img)
    notch_draw.rounded_rectangle(
        [(notch_x, notch_y), (notch_x + notch_w, notch_y + notch_h)],
        radius=notch_radius,
        fill=(10, 10, 14, 255)
    )
    notch_draw.rounded_rectangle(
        [(notch_x - 4, notch_y - 2), (notch_x + notch_w + 4, notch_y + notch_h + 2)],
        radius=notch_radius + 2,
        fill=None, outline=(80, 130, 210, 60), width=3
    )
    img = Image.alpha_composite(img, notch_img)

    # === 4. Focus Block — shield-like rounded rect ===
    block_w = int(size * 0.35)
    block_h = int(size * 0.42)
    block_x = (size - block_w) // 2
    block_y = int(size * 0.26)
    block_radius = int(size * 0.12)

    block_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    block_draw = ImageDraw.Draw(block_img)

    for ly in range(block_y, block_y + block_h):
        t = (ly - block_y) / block_h
        r = int(59 + t * 60)
        g = int(130 + t * 20)
        b = int(246 - t * 50)

        dy_top = max(0, block_y + block_radius - ly)
        offset_top = 0 if dy_top == 0 else block_radius - int(math.sqrt(max(0, block_radius**2 - dy_top**2)))
        dy_bot = max(0, ly - (block_y + block_h - block_radius))
        offset_bot = 0 if dy_bot == 0 else block_radius - int(math.sqrt(max(0, block_radius**2 - dy_bot**2)))
        corner_offset = max(offset_top, offset_bot)

        slice_img = Image.new('RGBA', (size, 1), (0, 0, 0, 0))
        slice_draw = ImageDraw.Draw(slice_img)
        slice_draw.line([(block_x + corner_offset, 0), (block_x + block_w - corner_offset, 0)], fill=(r, g, b, 255))
        block_img.paste(slice_img, (0, ly))

    block_draw.rounded_rectangle(
        [(block_x, block_y), (block_x + block_w, block_y + block_h)],
        radius=block_radius, fill=None,
        outline=(140, 180, 255, 40), width=3
    )
    img = Image.alpha_composite(img, block_img)

    # === 5. Bridge: connect notch to block ===
    bridge_w = int(notch_w * 1.15)
    bridge_h = int(size * 0.04)
    bridge_x = (size - bridge_w) // 2
    bridge_y = notch_y + notch_h + int(size * 0.02)
    bridge_radius = int(bridge_h * 0.6)

    bridge_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    bridge_draw = ImageDraw.Draw(bridge_img)
    for ly in range(bridge_y, bridge_y + bridge_h):
        t = (ly - bridge_y) / bridge_h
        r_val = int(80 + t * 20)
        g_val = int(150 + t * 10)
        b_val = int(240 - t * 10)
        bridge_draw.line(
            [(bridge_x + bridge_radius, ly), (bridge_x + bridge_w - bridge_radius, ly)],
            fill=(r_val, g_val, b_val, 255)
        )
    bridge_draw.rounded_rectangle(
        [(bridge_x, bridge_y), (bridge_x + bridge_w, bridge_y + bridge_h)],
        radius=bridge_radius, fill=(90, 160, 245, 160),
        outline=(120, 175, 250, 40), width=1
    )
    img = Image.alpha_composite(img, bridge_img)

    # === 6. Pause symbol (focus indicator) ===
    bar_w = int(size * 0.04)
    bar_h = int(size * 0.13)
    bar_gap = int(size * 0.05)
    bar_y = int(block_y + (block_h - bar_h) / 2)

    symbol_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    symbol_draw = ImageDraw.Draw(symbol_img)

    left_bar_x = size // 2 - bar_gap // 2 - bar_w
    symbol_draw.rounded_rectangle(
        [(left_bar_x, bar_y), (left_bar_x + bar_w, bar_y + bar_h)],
        radius=int(bar_w * 0.5), fill=(255, 255, 255, 230)
    )
    right_bar_x = size // 2 + bar_gap // 2
    symbol_draw.rounded_rectangle(
        [(right_bar_x, bar_y), (right_bar_x + bar_w, bar_y + bar_h)],
        radius=int(bar_w * 0.5), fill=(255, 255, 255, 230)
    )

    # === 7. Clock markers (4 dots around block) ===
    marker_radius = int(size * 0.012)
    marker_alpha = 120
    marker_color = (180, 200, 240, marker_alpha)
    marker_offset = int(size * 0.04)
    marker_positions = [
        (size // 2, block_y - marker_offset),
        (block_x + block_w + marker_offset, block_y + block_h // 2),
        (size // 2, block_y + block_h + marker_offset),
        (block_x - marker_offset, block_y + block_h // 2),
    ]
    for mx, my in marker_positions:
        symbol_draw.ellipse(
            [(mx - marker_radius, my - marker_radius), (mx + marker_radius, my + marker_radius)],
            fill=marker_color
        )

    img = Image.alpha_composite(img, symbol_img)

    # === 8. Clip to macOS rounded-rect icon shape ===
    corner_radius = int(size * 0.224)
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=corner_radius, fill=255)

    final = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    final.paste(img, mask=mask)
    return final


def generate_all_sizes():
    """Generate all required icon sizes for the macOS asset catalog."""
    output_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        'NotchBlock', 'Resources', 'Assets.xcassets', 'AppIcon.appiconset'
    )
    os.makedirs(output_dir, exist_ok=True)

    master = generate_master_icon(1024)

    sizes = {
        'icon_1024x1024.png': 1024,
        'icon_512x512.png': 512,
        'icon_256x256.png': 256,
        'icon_128x128.png': 128,
        'icon_32x32.png': 32,
        'icon_16x16.png': 16,
    }

    for filename, target_size in sizes.items():
        img = master if target_size == 1024 else master.resize((target_size, target_size), Image.LANCZOS)
        filepath = os.path.join(output_dir, filename)
        img.save(filepath, 'PNG')
        print(f'  ✓ {filename} ({target_size}×{target_size})')

    print(f'\n✅ All icons generated in: {output_dir}')
    return output_dir


if __name__ == '__main__':
    generate_all_sizes()
