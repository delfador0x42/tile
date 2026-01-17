#!/usr/bin/env python3
"""
Generate Tron/Cyberpunk style app icons for Tile 3
"""

from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os

# Output directory
ICON_DIR = "tile_3/Assets.xcassets/AppIcon.appiconset"

# All required sizes for macOS
SIZES = [
    (16, "1x", "icon_16x16.png"),
    (32, "2x", "icon_16x16@2x.png"),
    (32, "1x", "icon_32x32.png"),
    (64, "2x", "icon_32x32@2x.png"),
    (128, "1x", "icon_128x128.png"),
    (256, "2x", "icon_128x128@2x.png"),
    (256, "1x", "icon_256x256.png"),
    (512, "2x", "icon_256x256@2x.png"),
    (512, "1x", "icon_512x512.png"),
    (1024, "2x", "icon_512x512@2x.png"),
]

# Cyberpunk colors
DARK_BG = (10, 10, 15)
NEON_CYAN = (0, 255, 255)
NEON_MAGENTA = (255, 0, 150)
NEON_BLUE = (30, 144, 255)
GRID_COLOR = (0, 80, 100)
GLOW_CYAN = (0, 200, 220)


def create_cyberpunk_icon(size):
    """Create a single Tron-style icon at the given size."""
    # Create base image with dark background
    img = Image.new('RGBA', (size, size), DARK_BG)
    draw = ImageDraw.Draw(img)

    # Scale factor for different sizes
    scale = size / 512

    # Add subtle grid pattern in background
    grid_spacing = int(32 * scale)
    if grid_spacing > 2:
        for x in range(0, size, grid_spacing):
            draw.line([(x, 0), (x, size)], fill=(*GRID_COLOR, 40), width=max(1, int(scale)))
        for y in range(0, size, grid_spacing):
            draw.line([(0, y), (size, y)], fill=(*GRID_COLOR, 40), width=max(1, int(scale)))

    # Main content area with padding
    padding = int(60 * scale)
    content_size = size - (padding * 2)

    # Draw outer glow border (rounded rect effect)
    border_width = max(2, int(8 * scale))
    corner_radius = int(80 * scale)

    # Outer border glow
    for i in range(3, 0, -1):
        glow_alpha = 80 - (i * 20)
        glow_width = border_width + (i * int(4 * scale))
        draw_rounded_rect(draw, padding - i*2, padding - i*2,
                         size - padding + i*2, size - padding + i*2,
                         corner_radius + i*2, (*NEON_CYAN, glow_alpha), glow_width)

    # Main border
    draw_rounded_rect(draw, padding, padding, size - padding, size - padding,
                     corner_radius, NEON_CYAN, border_width)

    # Draw the 2x2 tile grid (window tiling symbol)
    grid_padding = int(100 * scale)
    grid_size = size - (grid_padding * 2)
    cell_gap = int(16 * scale)
    cell_size = (grid_size - cell_gap) // 2

    tile_positions = [
        (grid_padding, grid_padding),  # Top-left
        (grid_padding + cell_size + cell_gap, grid_padding),  # Top-right
        (grid_padding, grid_padding + cell_size + cell_gap),  # Bottom-left
        (grid_padding + cell_size + cell_gap, grid_padding + cell_size + cell_gap),  # Bottom-right
    ]

    tile_colors = [NEON_CYAN, NEON_MAGENTA, NEON_BLUE, NEON_CYAN]

    for i, (tx, ty) in enumerate(tile_positions):
        color = tile_colors[i]
        cell_corner = int(12 * scale)

        # Cell glow
        for g in range(2, 0, -1):
            glow_alpha = 60 - (g * 20)
            draw_rounded_rect(draw, tx - g, ty - g,
                             tx + cell_size + g, ty + cell_size + g,
                             cell_corner + g, (*color, glow_alpha), max(1, int(2 * scale)))

        # Cell fill (semi-transparent)
        draw_filled_rounded_rect(draw, tx, ty, tx + cell_size, ty + cell_size,
                                cell_corner, (*color, 40))

        # Cell border
        draw_rounded_rect(draw, tx, ty, tx + cell_size, ty + cell_size,
                         cell_corner, (*color, 220), max(1, int(3 * scale)))

    # Add scan line effect for larger icons
    if size >= 128:
        for y in range(0, size, 4):
            draw.line([(0, y), (size, y)], fill=(0, 0, 0, 15), width=1)

    # Add corner accents
    accent_len = int(30 * scale)
    accent_width = max(2, int(4 * scale))

    # Top-left corner accent
    draw.line([(padding, padding + corner_radius), (padding, padding + corner_radius + accent_len)],
              fill=NEON_MAGENTA, width=accent_width)
    draw.line([(padding + corner_radius, padding), (padding + corner_radius + accent_len, padding)],
              fill=NEON_MAGENTA, width=accent_width)

    # Bottom-right corner accent
    draw.line([(size - padding, size - padding - corner_radius),
               (size - padding, size - padding - corner_radius - accent_len)],
              fill=NEON_MAGENTA, width=accent_width)
    draw.line([(size - padding - corner_radius, size - padding),
               (size - padding - corner_radius - accent_len, size - padding)],
              fill=NEON_MAGENTA, width=accent_width)

    return img


def draw_rounded_rect(draw, x1, y1, x2, y2, radius, color, width):
    """Draw a rounded rectangle outline."""
    # Ensure we have valid coordinates
    if x2 < x1:
        x1, x2 = x2, x1
    if y2 < y1:
        y1, y2 = y2, y1

    # Limit radius to half the smallest dimension
    max_radius = min((x2 - x1) // 2, (y2 - y1) // 2)
    radius = min(radius, max_radius)

    if radius <= 0:
        draw.rectangle([x1, y1, x2, y2], outline=color, width=width)
        return

    # Top line
    draw.line([(x1 + radius, y1), (x2 - radius, y1)], fill=color, width=width)
    # Bottom line
    draw.line([(x1 + radius, y2), (x2 - radius, y2)], fill=color, width=width)
    # Left line
    draw.line([(x1, y1 + radius), (x1, y2 - radius)], fill=color, width=width)
    # Right line
    draw.line([(x2, y1 + radius), (x2, y2 - radius)], fill=color, width=width)

    # Corners (arcs)
    draw.arc([x1, y1, x1 + radius * 2, y1 + radius * 2], 180, 270, fill=color, width=width)
    draw.arc([x2 - radius * 2, y1, x2, y1 + radius * 2], 270, 360, fill=color, width=width)
    draw.arc([x1, y2 - radius * 2, x1 + radius * 2, y2], 90, 180, fill=color, width=width)
    draw.arc([x2 - radius * 2, y2 - radius * 2, x2, y2], 0, 90, fill=color, width=width)


def draw_filled_rounded_rect(draw, x1, y1, x2, y2, radius, color):
    """Draw a filled rounded rectangle."""
    # Ensure valid coords
    if x2 < x1:
        x1, x2 = x2, x1
    if y2 < y1:
        y1, y2 = y2, y1

    max_radius = min((x2 - x1) // 2, (y2 - y1) // 2)
    radius = min(radius, max_radius)

    if radius <= 0:
        draw.rectangle([x1, y1, x2, y2], fill=color)
        return

    # Main rectangles
    draw.rectangle([x1 + radius, y1, x2 - radius, y2], fill=color)
    draw.rectangle([x1, y1 + radius, x2, y2 - radius], fill=color)

    # Corner circles
    draw.ellipse([x1, y1, x1 + radius * 2, y1 + radius * 2], fill=color)
    draw.ellipse([x2 - radius * 2, y1, x2, y1 + radius * 2], fill=color)
    draw.ellipse([x1, y2 - radius * 2, x1 + radius * 2, y2], fill=color)
    draw.ellipse([x2 - radius * 2, y2 - radius * 2, x2, y2], fill=color)


def generate_contents_json():
    """Generate the Contents.json file for the asset catalog."""
    images = []
    for size, scale, filename in SIZES:
        base_size = size if scale == "1x" else size // 2
        images.append({
            "filename": filename,
            "idiom": "mac",
            "scale": scale,
            "size": f"{base_size}x{base_size}"
        })

    return {
        "images": images,
        "info": {
            "author": "xcode",
            "version": 1
        }
    }


def main():
    import json

    # Create output directory if needed
    os.makedirs(ICON_DIR, exist_ok=True)

    print("Generating Tron/Cyberpunk app icons...")

    for size, scale, filename in SIZES:
        print(f"  Creating {filename} ({size}x{size}px)...")
        icon = create_cyberpunk_icon(size)
        icon.save(os.path.join(ICON_DIR, filename), "PNG")

    # Write Contents.json
    contents = generate_contents_json()
    with open(os.path.join(ICON_DIR, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)

    print(f"\nDone! Icons saved to {ICON_DIR}/")
    print("Rebuild your Xcode project to see the new icons.")


if __name__ == "__main__":
    main()
